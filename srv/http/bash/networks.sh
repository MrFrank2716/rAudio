#!/bin/bash

. /srv/http/bash/common.sh

# convert each line to each args
readarray -t args <<< "$1"

pushRefresh() {
	sleep 2
	data=$( $dirbash/networks-data.sh )
	pushstream refresh "$data"
}
netctlSwitch() {
	ssid=$1
	connected=$( netctl list | grep ^* | sed 's/^\* //' )
	ifconfig wlan0 down
	netctl switch-to "$ssid"
	for i in {1..10}; do
		sleep 1
		if [[ $( netctl is-active "$ssid" ) == active ]]; then
			[[ $connected ]] && netctl disable "$connected"
			netctl enable "$ssid"
			active=1
			break
		fi
	done
	[[ ! $active ]] && netctl switch-to "$connected" && sleep 2
	pushRefresh
	if systemctl -q is-active hostapd; then
		data=$( $dirbash/features-data.sh )
		pushstream refresh "$data"
	fi
}

case ${args[0]} in

avahi )
	hostname=$( hostname )
	echo "\
<bll># avahi-browse -arp | cut -d';' -f7,8 | grep $hostname</bll>

$( timeout 1 avahi-browse -arp \
	| cut -d';' -f7,8 \
	| grep $hostname \
	| grep -v 127.0.0.1 \
	| sed 's/;/ : /' \
	| sort -u )"
	;;
btdisconnect )
	bluetoothctl disconnect ${args[1]}
	sleep 2
	pushRefresh
	;;
btpair )
	mac=${args[1]}
	bluetoothctl trust $mac
	bluetoothctl pair $mac
	bluetoothctl connect $mac
	[[ $? == 0 ]] && pushRefresh || echo -1
	;;
btremove )
	mac=${args[1]}
	bluetoothctl disconnect $mac
	bluetoothctl remove $mac
	sleep 2
	pushRefresh
	;;
connect )
	data=${args[1]}
	ESSID=$( jq -r .ESSID <<< $data )
	Key=$( jq -r .Key <<< $data )
	profile="\
Interface=wlan0
Connection=wireless
ESSID=\"$ESSID\"
IP=$( jq -r .IP <<< $data )
"
	if [[ $Key ]]; then
		profile+="\
Security=$( jq -r .Security <<< $data )
Key=\"$Key\"
"
	else
		profile+="\
Security=none
"
	fi
	[[ $( jq -r .Hidden <<< $data ) == true ]] && profile+="\
Hidden=yes
"
	[[ $( jq -r .IP <<< $data ) == static ]] && profile+="\
Address=$( jq -r .Address <<< $data )/24
Gateway=$( jq -r .Gateway <<< $data )
"
	if systemctl -q is-active hostapd && ! systemctl -q is-enabled hostapd; then
		echo "$profile" > /boot/wifi
		data='{ "ssid": "'"$ESSID"'" }'
		pushstream wifi "$data"
		exit
	fi
	
	echo "$profile" > "/etc/netctl/$ESSID"
	netctlSwitch "$ESSID"
	;;
disconnect )
	netctl stop-all
	killall wpa_supplicant
	ifconfig wlan0 up
	pushRefresh
	;;
editlan )
	ip=${args[1]}
	gw=${args[2]}
	eth0="\
[Match]
Name=eth0
[Network]
DNSSEC=no
"
	if [[ ! $ip ]];then
		eth0+="\
DHCP=yes
"
	else
		ping -c 1 -w 1 $ip &> /dev/null && exit -1
		
		eth0+="\
Address=$ip/24
Gateway=$gw
"
	fi
	echo "$eth0" > /etc/systemd/network/eth0.network
	systemctl restart systemd-networkd
	pushRefresh
	;;
editwifidhcp )
	ssid=${args[1]}
	netctl stop "$ssid"
	sed -i -e '/^Address\|^Gateway/ d
' -e 's/^IP.*/IP=dhcp/
' "$file"
	cp "$file" "/etc/netctl/$ssid"
	netctl start "$ssid"
	pushRefresh
	;;
ifconfigeth )
	echo "\
<bll># ifconfig eth0</bll>

$( ifconfig eth0 | grep -v 'RX\\|TX' | grep . )"
	;;
ifconfigwlan )
	echo "\
<bll># ifconfig wlan0
# iwconfig wlan0</bll>

$( ifconfig wlan0 | grep -v 'RX\\|TX')
$( iwconfig wlan0 | grep . )"
	;;
ipused )
	ping -c 1 -w 1 ${args[1]} &> /dev/null && echo 1 || echo 0
	;;
profileconnect )
	if systemctl -q is-active hostapd; then
		systemctl disable --now hostapd
		ifconfig wlan0 0.0.0.0
		sleep 2
	fi
	netctlSwitch ${args[1]}
	;;
profileget )
	netctl=$( cat "/etc/netctl/${args[1]}" )
	password=$( echo "$netctl" | grep ^Key | cut -d= -f2- | tr -d '"' )
	static=$( echo "$netctl" | grep -q ^IP=dhcp && echo false || echo true )
	hidden=$( echo "$netctl" | grep -q ^Hidden && echo true || echo false )
	wep=$( [[ $( echo "$netctl" | grep ^Security | cut -d= -f2 ) == wep ]] && echo true || echo false )
	echo '[ "'$password'", '$static', '$hidden', '$wep' ]'
	;;
profileremove )
	ssid=${args[1]}
	netctl disable "$ssid"
	netctl stop "$ssid"
	killall wpa_supplicant
	ifconfig wlan0 up
	rm "/etc/netctl/$ssid"
	pushRefresh
	;;
	
esac
