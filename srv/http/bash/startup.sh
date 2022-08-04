#!/bin/bash

. /srv/http/bash/common.sh

connectedCheck() {
	for (( i=0; i < $1; i++ )); do
		ifconfig | grep -q 'inet.*broadcast' && connected=1 && break
		sleep $2
	done
}

# pre-configure --------------------------------------------------------------
if [[ -e /boot/expand ]]; then # run once
	rm /boot/expand
	touch $dirmpd/updating # for initial auto 'mpc rescan'
	partition=$( mount | grep ' on / ' | cut -d' ' -f1 )
	dev=${partition:0:-2}
	[[ $dev == /dev/sd ]] && dev=${partition:0:-1}
	if (( $( sfdisk -F $dev | awk 'NR==1{print $6}' ) != 0 )); then
		echo -e "d\n\nn\n\n\n\n\nw" | fdisk $dev &>/dev/null
		partprobe $dev
		resize2fs $partition
	fi
	# no on-board wireless - remove bluetooth
	hwrevision=$( awk '/Revision/ {print $NF}' /proc/cpuinfo )
	[[ ${hwrevision: -3:2} =~ ^(00|01|02|03|04|09)$ ]] && sed -i '/dtparam=krnbt=on/ d' /boot/config.txt
fi

if [[ -e /boot/backup.gz ]]; then
	mv /boot/backup.gz $dirtmp
	$dirbash/settings/system.sh datarestore
fi

# wifi - on-board or usb
wlandev=$( ip -br link \
				| grep ^w \
				| grep -v wlan \
				| cut -d' ' -f1 )
[[ ! $wlandev ]] && wlandev=wlan0
echo $wlandev > /dev/shm/wlan

if [[ -e /boot/wifi ]]; then
	! grep -q $wlandev /boot/wifi && sed -i -E "s/^(Interface=).*/\1$wlandev/" /boot/wifi
	ssid=$( grep '^ESSID' /boot/wifi | cut -d'"' -f2 )
	sed -i -e -E '/^#|^$/ d' -e 's/\r//' /boot/wifi
	mv -f /boot/wifi "/etc/netctl/$ssid"
	ifconfig $wlandev down
	netctl switch-to "$ssid"
	netctl enable "$ssid"
fi
# ----------------------------------------------------------------------------
rm -f $dirtmp/*
echo mpd > $dirshm/player
mkdir $dirshm/{airplay,embedded,spotify,local,online,sampling,webradio}
chmod -R 777 $dirshm
chown -R http:http $dirshm
touch $dirshm/status

# ( no profile && no hostapd ) || usb wifi > disable onboard
readarray -t profiles <<< $( ls -p /etc/netctl | grep -v / )
systemctl -q is-enabled hostapd && hostapd=1
lsmod | grep -q brcmfmac && touch $dirshm/onboardwlan
[[ ! $profiles && ! $hostapd || $wlandev != wlan0 ]] && rmmod brcmfmac &> /dev/null

# wait 5s max for lan connection
connectedCheck 5 1
# if lan not connected, wait 30s max for wi-fi connection
[[ ! $connected && $profiles && ! $hostapd ]] && connectedCheck 30 3

[[ $connected  ]] && readarray -t nas <<< $( ls -d1 /mnt/MPD/NAS/*/ 2> /dev/null | sed 's/.$//' )
if [[ $nas ]]; then
	for mountpoint in "${nas[@]}"; do # ping target before mount
		ip=$( grep "${mountpoint// /\\\\040}" /etc/fstab \
				| cut -d' ' -f1 \
				| sed 's|^//||; s|:*/.*$||' )
		for i in {1..10}; do
			if ping -4 -c 1 -w 1 $ip &> /dev/null; then
				mount "$mountpoint" && break
			else
				(( i == 10 )) && pushstreamNotifyBlink NAS "NAS @$ip cannot be reached." nas
				sleep 2
			fi
		done
	done
fi
if grep -q /srv/http/shareddata /etc/fstab; then
	shareddata=1
	mount /srv/http/shareddata
	for i in {1..5}; do
		sleep 1
		[[ -d $dirmpd ]] && break
	done
fi

[[ -e /boot/startup.sh ]] && . /boot/startup.sh

$dirbash/settings/player-conf.sh # mpd.service started by this script
[[ ! -e $dirmpd/counts ]] && $dirbash/cmd-list.sh

# after all sources connected ######################################

if [[ -e $dirsystem/lcdchar ]]; then
	$dirbash/lcdcharinit.py
	$dirbash/lcdchar.py logo
fi
[[ -e $dirsystem/mpdoled ]] && $dirbash/cmd.sh mpdoledlogo

[[ -e $dirsystem/soundprofile ]] && $dirbash/settings/system.sh soundprofile

[[ -e $dirsystem/autoplay ]] && mpc play || $dirbash/status-push.sh

if [[ $connected ]]; then
	: >/dev/tcp/8.8.8.8/53 && $dirbash/cmd.sh addonsupdates
elif [[ ! -e $dirsystem/wlannoap ]]; then
	modprobe brcmfmac &> /dev/null 
	systemctl -q is-enabled hostapd || $dirbash/settings/features.sh hostapdset
	systemctl -q disable hostapd
fi

iw $wlandev set power_save off &> /dev/null

if [[ -e $dirsystem/hddspindown ]]; then
	usb=$( mount | grep ^/dev/sd | cut -d' ' -f1 )
	if [[ $usb ]]; then
		duration=$( cat $dirsystem/hddspindown )
		readarray -t usb <<< "$usb"
		for dev in "${usb[@]}"; do
			hdparm -B $dev | grep -q 'APM.*not supported' && continue
			
			hdparm -q -B 127 $dev
			hdparm -q -S $duration $dev
		done
	fi
fi

file=/sys/class/backlight/rpi_backlight/brightness
if [[ -e $file ]]; then
	chmod 666 $file
	[[ -e $dirsystem/brightness ]] && cat $dirsystem/brightness > $file
fi

if [[ -e $dirmpd/updating ]]; then
	$dirbash/cmd.sh "mpcupdate
update
$( cat $dirmpd/updating )"
elif [[ -e $dirmpd/listing || ! -e $dirmpd/counts ]]; then
	$dirbash/cmd-list.sh &> dev/null &
fi
