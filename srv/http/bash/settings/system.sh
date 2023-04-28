#!/bin/bash

. /srv/http/bash/common.sh

filemodule=/etc/modules-load.d/raspberrypi.conf
args2var "$1"

configTxt() { # each $CMD removes each own lines > reappends if enable or changed
	local chip i2clcdchar i2cmpdoled list module name spimpdoled tft
	if [[ ! -e /tmp/config.txt ]]; then # files at boot for comparison: cmdline.txt, config.txt, raspberrypi.conf
		cp /boot/cmdline.txt /tmp
		grep -Ev '^#|^\s*$' /boot/config.txt | sort -u > /tmp/config.txt
		grep -Ev '^#|^\s*$' $filemodule 2> /dev/null | sort -u > /tmp/raspberrypi.conf
	fi
	[[ ! $config ]] && config=$( < /boot/config.txt ) # if no config set from $CMD
	if [[ $i2cset ]]; then
		grep -E -q 'dtoverlay=.*:rotate=' <<< $config && tft=1
		[[ -e $dirsystem/lcdchar ]] && i2clcdchar=1
		if [[ -e $dirsystem/mpdoled ]]; then
			chip=$( grep mpd_oled /etc/systemd/system/mpd_oled.service | cut -d' ' -f3 )
			[[ $chip == 1 || $chip == 7 ]] && spimpdoled=1 || i2cmpdoled=1
		fi
		config=$( grep -Ev 'dtparam=i2c_arm=on|dtparam=spi=on|dtparam=i2c_arm_baudrate' <<< $config )
		[[ $tft || $i2clcdchar || $i2cmpdoled ]] && config+="
dtparam=i2c_arm=on"
		[[ $i2cmpdoled ]] && config+="
dtparam=i2c_arm_baudrate=$BAUD" # $baud from mpdoled )
		[[ $tft || $spimpdoled ]] && config+="
dtparam=spi=on"
		
		module=$( grep -Ev 'i2c-bcm2708|i2c-dev|^#|^\s*$' $filemodule 2> /dev/null )
		[[ $tft || $i2clcdchar ]] && module+="
i2c-bcm2708"
		if [[ $tft || $i2clcdchar || $i2cmpdoled ]]; then
			module+="
i2c-dev"
			! ls /dev/i2c* &> /dev/null && rebooti2c=1
		fi
		grep -Ev '^#|^\s*$' <<< $module | sort -u > $filemodule
		[[ ! $rebooti2c ]] && ! cmp -s /tmp/raspberrypi.conf $filemodule && rebooti2c=1
		[[ ! -s $filemodule ]] && rm -f $filemodule
	fi
	grep -Ev '^#|^\s*$' <<< $config | sort -u > /boot/config.txt
	pushRefresh
	list=$( grep -v "$CMD" $dirshm/reboot 2> /dev/null )
	if [[ $rebooti2c ]] \
		|| ! cmp -s /tmp/config.txt /boot/config.txt \
		|| ! cmp -s /tmp/cmdline.txt /boot/cmdline.txt; then
		name=$( sed -n "/^\t, '$CMD'/ {s/.*'name' => '//; s/'.*//; p}" /srv/http/settings/system.php )
		notify $CMD "$name" 'Reboot required.' 5000
		list+="
$CMD"
	fi
	[[ $list ]] && awk NF <<< $list > $dirshm/reboot || rm -f $dirshm/reboot
}
sharedDataIPlist() {
	local ip iplist list
	list=$( ipAddress )
	iplist=$( grep -v $list $filesharedip )
	for ip in $iplist; do
		if ipOnline $ip; then
			list+=$'\n'$ip
			[[ $1 ]] && sshCommand $ip $dirsettings/system.sh shareddatarestart
		fi
	done
	sort -u <<< $list | awk NF > $filesharedip
}
sharedDataSet() {
	rm -f $dirmpd/{listing,updating}
	mkdir -p $dirbackup
	for dir in audiocd bookmarks lyrics mpd playlists webradio; do
		[[ ! -e $dirshareddata/$dir ]] && cp -r $dirdata/$dir $dirshareddata  # not server rAudio - initial setup
		rm -rf $dirbackup/$dir
		mv -f $dirdata/$dir $dirbackup
		ln -s $dirshareddata/$dir $dirdata
	done
	if [[ ! -e $dirshareddata/system ]]; then                                 # not server rAudio - initial setup
		mkdir $dirshareddata/system
		cp -f $dirsystem/{display,order}.json $dirshareddata/system
	fi
	touch $filesharedip $dirshareddata/system/order.json
	mv $dirsystem/{display,order}.json $dirbackup
	ln -s $dirshareddata/system/{display,order}.json $dirsystem
	dirPermissionsShared
	sharedDataIPlist
	mpc -q clear
	systemctl restart mpd
	pushRefresh
	pushstream refresh '{ "page": "features", "shareddata": true }'
}
soundProfile() {
	local lan mtu swappiness txqueuelen
	if [[ $1 == reset ]]; then
		swappiness=60
		mtu=1500
		txqueuelen=1000
		rm -f $dirsystem/soundprofile
	else
		. $dirsystem/soundprofile.conf
		touch $dirsystem/soundprofile
	fi
	sysctl vm.swappiness=$swappiness
	lan=$( ifconfig | grep ^e | cut -d: -f1 )
	if ifconfig | grep -q -m1 $lan; then
		ip link set $lan mtu $mtu
		ip link set $lan txqueuelen $txqueuelen
	fi
}

case $CMD in

audio )
	config=$( grep -v dtparam=audio=on /boot/config.txt )
	[[ $ON ]] && config+="
dtparam=audio=on"
	configTxt
	;;
bluetooth )
	config=$( grep -v dtparam=krnbt=on /boot/config.txt )
	if [[ $ON ]]; then
		config+="
dtparam=krnbt=on"
		if ls -l /sys/class/bluetooth | grep -q -m1 serial; then
			systemctl start bluetooth
			! grep -q 'device.*bluealsa' $dirmpdconf/output.conf && $dirsettings/player-conf.sh
			rfkill | grep -q -m1 bluetooth && pushstream refresh '{"page":"networks","activebt":true}'
		fi
		if [[ $DISCOVERABLE ]]; then
			yesno=yes
			touch $dirsystem/btdiscoverable
		else
			yesno=no
			rm $dirsystem/btdiscoverable
		fi
		bluetoothctl discoverable $yesno &> /dev/null
		[[ -e $dirsystem/btformat  ]] && prevbtformat=true || prevbtformat=
		[[ $FORMAT ]] && touch $dirsystem/btformat || rm $dirsystem/btformat
		[[ $FORMAT != $prevbtformat ]] && $dirsettings/player-conf.sh
	else
		if ! rfkill | grep -q -m1 bluetooth; then
			systemctl stop bluetooth
			rm -f $dirshm/{btdevice,btreceiver,btsender}
			grep -q -m1 'device.*bluealsa' $dirmpdconf/output.conf && $dirsettings/player-conf.sh
		fi
	fi
	configTxt
	;;
bluetoothstart )
	sleep 3
	[[ -e $dirsystem/btdiscoverable ]] && yesno=yes || yesno=no
	bluetoothctl discoverable $yesno &> /dev/null
	bluetoothctl discoverable-timeout 0 &> /dev/null
	bluetoothctl pairable yes &> /dev/null
	;;
hddinfo )
	echo -n "\
<bll># hdparm -I $DEV</bll>
$( hdparm -I $DEV | sed '1,3 d' )
"
	;;
hddsleep )
	if [[ $ON ]]; then
		devs=$( mount | grep .*USB/ | cut -d' ' -f1 )
		for dev in $devs; do
			! hdparm -B $dev | grep -q -m1 'APM_level' && notsupport+=$dev'<br>' && continue

			hdparm -q -B $APM $dev
			hdparm -q -S $APM $dev
			support=1
		done
		[[ $notsupport ]] && echo -e "<wh>Devices not support sleep:</wh><br>$notsupport"
		[[ $support ]] && echo $APM > $dirsystem/apm
	else
		devs=$( mount | grep .*USB/ | cut -d' ' -f1 )
		if [[ $devs ]]; then
			for dev in $devs; do
				! hdparm -B $dev | grep -q -m1 'APM_level' && continue
				
				hdparm -q -B 128 $dev &> /dev/null
				hdparm -q -S 0 $dev &> /dev/null
			done
		fi
		rm -f $dirsystem/hddsleep
	fi
	pushRefresh
	;;
hdmi )
	config=$( grep -v hdmi_force_hotplug /boot/config.txt )
	[[ $ON ]] && config+="
hdmi_force_hotplug=1"
	configTxt
	pushstream refresh '{"page":"features","hdmihotplug":'$TF'}'
	;;
hostname )
	hostnamectl set-hostname $HOSTNAME
	sed -i -E 's/^(ssid=).*/\1'$HOSTNAME'/' /etc/hostapd/hostapd.conf
	sed -i -E 's/(name = ").*/\1'$HOSTNAME'"/' /etc/shairport-sync.conf
	sed -i -E 's/^(friendlyname = ).*/\1'$HOSTNAME'/' /etc/upmpdcli.conf
	rm -f /root/.config/chromium/SingletonLock 	# 7" display might need to rm: SingletonCookie SingletonSocket
	systemctl try-restart avahi-daemon bluetooth hostapd localbrowser mpd smb shairport-sync shairport spotifyd upmpdcli
	pushRefresh
	;;
i2seeprom )
	config=$( grep -v force_eeprom_read /boot/config.txt )
	[[ $ON ]] && config+="
force_eeprom_read=0"
	configTxt
	;;
i2smodule )
	prevaplayname=$( getContent $dirsystem/audio-aplayname )
	config=$( grep -Ev "dtparam=i2s=on|dtoverlay=$prevaplayname|gpio=25=op,dh|dtparam=audio=on" /boot/config.txt )
	if [[ $APLAYNAME != onboard ]]; then
		config+="
dtparam=i2s=on
dtoverlay=$APLAYNAME"
		[[ $OUTPUT == 'Pimoroni Audio DAC SHIM' ]] && config+="
gpio=25=op,dh"
		[[ $APLAYNAME == rpi-cirrus-wm5102 ]] && echo softdep arizona-spi pre: arizona-ldo1 > /etc/modprobe.d/cirrus.conf
		! grep -q gpio-shutdown /boot/config.txt && systemctl disable --now powerbutton
		echo $APLAYNAME > $dirsystem/audio-aplayname
		echo $OUTPUT > $dirsystem/audio-output
	else
		config+="
dtparam=audio=on"
		rm -f $dirsystem/audio-* /etc/modprobe.d/cirrus.conf
	fi
	configTxt
	;;
lcdchar )
	enableFlagSet
	sed -E -e 's/(true)$/\u\1/
' -e 's/=$/=False/
' -e '/^inf|^charmap|^chip/ {s/=/="/; s/$/"/}
' $dirsystem/lcdchar.conf > $dirsystem/lcdcharconf.py
	rm -f $dirsystem/lcdchar.conf
	i2cset=1
	configTxt
	;;
lcdcharset )
	systemctl stop lcdchar
	$dirbash/lcdchar.py $ACTION
	;;
mirrorlist )
	file=/etc/pacman.d/mirrorlist
	mirror=$( sed -n '/^Server/ {s|\.*mirror.*||; s|.*//||; p}' $file )
	if internetConnected; then
		curl -sfLO https://github.com/archlinuxarm/PKGBUILDs/raw/master/core/pacman-mirrorlist/mirrorlist
		if [[ $? == 0 ]]; then
			mv -f mirrorlist $file
			[[ $mirror ]] && sed -i "0,/^Server/ s|//.*mirror|//$mirror.mirror|" $file
		else
			rm mirrorlist
		fi
	fi
	readarray -t lines <<< $( sed -E -n '/^### Mirror/,$ {/^\s*$|^### Mirror/ d; s|.*//(.*)\.mirror.*|\1|; p}' $file )
	codelist='"":"Auto"'
	for line in "${lines[@]}"; do
		if [[ ${line:0:4} == '### ' ]];then
			city=
			country=${line:4}
		elif [[ ${line:0:3} == '## ' ]];then
			city=${line:3}
		else
			[[ $city ]] && cc="$country - $city" || cc=$country
			[[ $cc == $ccprev ]] && cc+=" 2"
			ccprev=$cc
			codelist+=',"'$cc'":"'$line'"'
		fi
	done
	echo '{ '$codelist' }'
	;;
mountforget )
	umount -l "$MOUNTPOINT"
	rmdir "$MOUNTPOINT" &> /dev/null
	fstab=$( grep -v $( space2ascii $MOUNTPOINT ) /etc/fstab )
	column -t <<< $fstab > /etc/fstab
	systemctl daemon-reload
	$dirbash/cmd.sh mpcupdate$'\n'NAS
	pushRefresh
	;;
mountremount )
	if [[ ${MOUNTPOINT:9:3} == NAS ]]; then
		mount "$MOUNTPOINT"
	else
		udevil mount "$SOURCE"
	fi
	pushRefresh
	;;
mountunmount )
	if [[ ${MOUNTPOINT:9:3} == NAS ]]; then
		umount -l "$MOUNTPOINT"
	else
		udevil umount -l "$MOUNTPOINT"
	fi
	pushRefresh
	;;
mpdoledlogo )
	systemctl stop mpd_oled
	type=$( grep mpd_oled /etc/systemd/system/mpd_oled.service | cut -d' ' -f3 )
	mpd_oled -o $type -L
	;;
mpdoled )
	enableFlagSet
	if [[ $ON ]]; then
		if [[ $( grep mpd_oled /etc/systemd/system/mpd_oled.service | cut -d' ' -f3 ) != $CHIP ]]; then
			sed -i 's/-o ./-o '$CHIP'/' /etc/systemd/system/mpd_oled.service
			systemctl daemon-reload
		fi
	else
		$dirsettings/player-conf.sh
	fi
	i2cset=1
	configTxt
	[[ -e $dirsystem/mpdoled && ! -e $dirshm/reboot && ! -e $dirmpdconf/fifo.conf ]] && $dirsettings/player-conf.sh
	;;
ntpmirror )
	file=/etc/systemd/timesyncd.conf
	if [[ $NTP != $( getVar NTP $file ) ]]; then
		echo "\
[Time]
NTP=$NTP" > $file
		timedatectl set-ntp true
	fi
	[[ -e /boot/kernel.img ]] && pushRefresh && exit # armv6h
	file=/etc/pacman.d/mirrorlist
	[[ $MIRROR ]] && MIRROR+=.
	server='Server = http://'$MIRROR'mirror.archlinuxarm.org/$arch/$repo'
	[[ $server != $( grep -m1 ^Server $file ) ]] && echo $server > $file
	pushRefresh
	;;
packagelist )
	filepackages=/tmp/packages
	if [[ ! -e $filepackages ]]; then
		notify system Backend 'Package list ...'
		pacmanqi=$( pacman -Qi | grep -E '^Name|^Vers|^Desc|^URL' )
		while read line; do
			case ${line:0:3} in
			Nam ) name=$line;;
			Ver ) version=$line;;
			Des ) description=$line;;
			URL ) url=$line
				  lines+="\
$url
$name
$version
$description
"
;;
			esac
		done <<< $pacmanqi
		sed -E 's|^URL.*: (.*)|<a href="\1" target="_blank">|
				s|^Name.*: (.*)|\1</a> |
				s|^Vers.*: (.*)|<gr>\1</gr>|
				s|^Desc.*: (.*)|<p>\1</p>|' <<< $lines \
				> /tmp/packages
	fi
	grep -B1 -A2 --no-group-separator ^$PKG $filepackages
	;;
poweraudiophonics )
	config=$( grep -Ev 'gpio-poweroff|gpio-shutdown' /boot/config.txt )
	if [[ $ON ]]; then
		config+="
dtoverlay=gpio-poweroff,gpiopin=22
dtoverlay=gpio-shutdown,gpio_pin=17,active_low=0,gpio_pull=down"
	fi
	configTxt
	;;
powerbutton )
	config=$( grep -Ev 'gpio-poweroff|gpio-shutdown' /boot/config.txt )
	if [[ $ON ]]; then
		serviceRestartEnable
		if [[ $SW != 5 ]]; then
			config+='
dtoverlay=gpio-shutdown,gpio_pin='$RESERVED
		fi
	else
		if [[ ! -e $dirsystem/audiophonics ]]; then
			systemctl disable --now powerbutton
			gpio -1 write $( getVar led $dirsystem/powerbutton.conf ) 0
		fi
	fi
	configTxt
	;;
rebootlist )
	[[ -e $dirshm/reboot ]] && cat $dirshm/reboot
	rm -f $dirshm/{reboot,backup.gz}
	;;
regdomlist )
	cat /srv/http/assets/data/regdomcodes.json
	;;
relays )
	enableFlagSet
	if [[ $ON ]]; then
		. $dirsystem/relays.conf
		json=$( jq < $dirsystem/relays.json )
		for p in $on; do
			name=$( jq -r '.["'$p'"]' <<< $json )
			[[ $name ]] && neworderon+=$name'\n'
		done
		for p in $off; do
			name=$( jq -r '.["'$p'"]' <<< $json )
			[[ $name ]] && neworderoff+=$name'\n'
		done
		echo '
orderon="'$( stringEscape ${neworderon:0:-2} )'"
orderoff="'$( stringEscape ${neworderoff:0:-2} )'"' >> $dirsystem/relays.conf
	fi
	pushRefresh
	pushstream display '{"submenu":"relays","value":'$TF'}'
	;;
rotaryencoder )
	if [[ $ON ]]; then
		serviceRestartEnable
	else
		systemctl disable --now rotaryencoder
	fi
	pushRefresh
	;;
shareddataconnect )
	if [[ ! $IP && -e $dirsystem/sharedipserver ]]; then # sshpass from server to reconnect
		IP=$( < $dirsystem/sharedipserver )
		! ipOnline $IP && exit
		
		reconnect=1
	fi
	
	readarray -t paths <<< $( timeout 3 showmount --no-headers -e $IP 2> /dev/null | awk 'NF{NF-=1};1' ) # get shred path by server ip
	for path in "${paths[@]}"; do
		dir="$dirnas/$( basename "$path" )"
		[[ $( ls "$dir" ) ]] && echo "Directory not empty: <code>$dir</code>" && exit                    # stop if dir not empty
		
		umount -ql "$dir"
	done
	options="nfs  defaults,noauto,bg,soft,timeo=5  0  0"
	fstab=$( < /etc/fstab )
	for path in "${paths[@]}"; do
		name=$( basename "$path" )
		[[ $path == $dirusb/SD || $path == $dirusb/data ]] && name=usb$name
		dir="$dirnas/$name"
		mkdir -p "$dir"
		mountpoints+=( "$dir" )
		fstab+="
$IP:$( space2ascii $path )  $( space2ascii $dir )  $options"                                             # set as mount to /mnt/MPD/NAS in fstab
	done
	column -t <<< $fstab > /etc/fstab
	systemctl daemon-reload
	for dir in "${mountpoints[@]}"; do
		mount "$dir"
	done
	sharedDataSet
	if [[ $reconnect ]]; then
		rm $dirsystem/sharedipserver
		notify rserver 'Server rAudio' 'Online ...'
	fi
	;;
shareddatadisconnect )
	list=$( grep -v $( ipAddress ) $filesharedip )
	echo "$list" > $filesharedip # fix: sed temp file permission
	for dir in audiocd bookmarks lyrics mpd playlists webradio; do
		if [[ -L $dirdata/$dir ]]; then
			rm -rf $dirdata/$dir
			[[ -e $dirbackup/$dir ]] && mv $dirbackup/$dir $dirdata || mkdir $dirdata/$dir
		fi
	done
	rm $dirsystem/{display,order}.json
	mv -f $dirbackup/{display,order}.json $dirsystem
	rmdir $dirbackup &> /dev/null
	rm -f $dirshareddata $dirnas/.mpdignore /mnt/MPD/.mpdignore
	mpc -q clear
	if grep -q -m1 ":$dirsd " /etc/fstab; then # client of server rAudio
		ipserver=$( grep $dirshareddata /etc/fstab | cut -d: -f1 )
		fstab=$( grep -v ^$ipserver /etc/fstab )
		readarray -t paths <<< $( timeout 3 showmount --no-headers -e $ipserver 2> /dev/null | awk 'NF{NF-=1};1' )
		for path in "${paths[@]}"; do
			name=$( basename "$path" )
			[[ $path == $dirusb/SD || $path == $dirusb/data ]] && name=usb$name
			dir="$dirnas/$name"
			umount -l "$dir"
			rmdir "$dir" &> /dev/null
		done
	else # other servers
		fstab=$( grep -v $dirshareddata /etc/fstab )
		umount -l $dirshareddata
		rmdir $dirshareddata
	fi
	column -t <<< $fstab > /etc/fstab
	systemctl daemon-reload
	systemctl restart mpd
	pushRefresh
	pushstream refresh '{"page":"features","shareddata":false}'
	if [[ ! ${args[1]} ]]; then
		echo $ipserver > $dirsystem/sharedipserver # for sshpass reconnect
		notify rserver 'Server rAudio' 'Offline ...'
	fi
	;;
shareddataiplist )
	sharedDataIPlist
	;;
shareddatarestart )
	systemctl restart mpd
	pushstream mpdupdate $( < $dirmpd/counts )
	;;
shareddataset )
	sharedDataSet
	;;
sharelist )
	! ipOnline $IP && echo "IP address not found: <wh>$IP</wh>" && exit
	
#	if [[ $protocol == smb ]]; then
#		script -c "timeout 10 smbclient -NL $IP" $dirshm/smblist &> /dev/null # capture /dev/tty to file
#		paths=$( sed -e '/Disk/! d' -e '/\$/d' -e 's/^\s*//; s/\s\+Disk\s*$//' $dirshm/smblist )
#	else
#		paths=$( timeout 5 showmount --no-headers -e $IP 2> /dev/null | awk 'NF{NF-=1};1' | sort )
#	fi
	paths=$( timeout 5 showmount --no-headers -e $IP 2> /dev/null | awk 'NF{NF-=1};1' | sort )
	if [[ $paths ]]; then
		echo "\
Server rAudio @<wh>$IP</wh> :

<pre><wh>$paths</wh></pre>"
	else
		echo "No NFS shares found @<wh>$IP</wh>"
	fi
	;;
softlimit )
	config=$( grep -v temp_soft_limit /boot/config.txt )
	[[ $ON ]] && config+='
temp_soft_limit='$SOFTLIMIT
	configTxt
	;;
soundprofileset )
	soundProfile
	;;
soundprofile )
	if [[ $ON ]]; then
		if [[ "$SWAPPINESS $MTU $TXQUEUELEN" == '60 1500 1000' ]]; then
			rm -f $dirsystem/soundprofile.conf
			soundProfile reset
			notify soundprofile 'Sound Profile' 'Default setting.'
		else
			soundProfile
		fi
	else
		soundProfile reset
	fi
	pushRefresh
	;;
statusbluetooth )
	if rfkill | grep -q -m1 bluetooth; then
		hci=$( ls -l /sys/class/bluetooth | sed -n '/serial/ {s|.*/||; p}' )
		mac=$( cut -d' ' -f1 /sys/kernel/debug/bluetooth/$hci/identity )
	fi
	echo "\
<bll># bluetoothctl show</bll>
$( bluetoothctl show $mac )"
	;;
statusonboard )
	onboard=$( aplay -l | grep 'bcm2835' )
	[[ ! $onboard ]] && onboard='<gr>(disabled)</gr>'
	echo "\
<bll># aplay -l | grep 'bcm2835'</bll>
$onboard

<bll># rfkill</bll>
$( rfkill )"
	;;
statusonboard )
	ifconfig
	if systemctl -q is-active bluetooth; then
		echo '<hr>'
		bluetoothctl show | sed -E 's/^(Controller.*)/bluetooth: \1/'
	fi
	;;
statussoundprofile )
	lan=$( ifconfig | grep ^e | cut -d: -f1 )
	echo "\
<bll># sysctl vm.swappiness
# ifconfig $lan | grep -E 'mtu|txq'</bll>
$( sysctl vm.swappiness )
$( ifconfig $lan | sed -E -n '/mtu|txq/ {s/.*(mtu.*)/\1/; s/.*(txq.*) \(.*/\1/; s/ / = /; p}' )"
	;;
statusstatus )
	filebootlog=/tmp/bootlog
	[[ -e $filebootlog ]] && cat $filebootlog && exit
	
	journal="\
<bll># journalctl -b</bll>"
	journal+="
$( journalctl -b | sed -n '1,/Startup finished.*kernel/ {s|Failed to start .*|<red>&</red>|; p}' )
"
	startupfinished=$( sed -E -n '/Startup finished/ {s/^.*(Startup)/\1/; p}' <<< $journal )
	if [[ $startupfinished ]]; then
		echo "\
<bll># journalctl -b -o cat -g 'Startup finished'</bll>
$startupfinished

$journal" | tee $filebootlog
	else
		echo "$journal"
	fi
	;;
statusstorage )
	echo -n "\
<bll># cat /etc/fstab</bll>
$( < /etc/fstab )

<bll># mount | grep ^/dev</bll>
$( mount | grep ^/dev | sort | column -t )
"
	;;
statussystem )
	config="\
<bll># cat /boot/cmdline.txt</bll>
$( < /boot/cmdline.txt )

<bll># cat /boot/config.txt</bll>
$( grep -Ev '^#|^\s*$' /boot/config.txt )

<bll># pacman -Qs 'firmware|bootloader' | grep ^local | cut -d/ -f2</bll>
$( pacman -Qs 'firmware|bootloader' | grep ^local | cut -d/ -f2 )"
	raspberrypiconf=$( cat $filemodule 2> /dev/null )
	if [[ $raspberrypiconf ]]; then
		config+="

<bll># $filemodule</bll>
$raspberrypiconf"
		dev=$( ls /dev/i2c* 2> /dev/null | cut -d- -f2 )
		[[ $dev ]] && config+="
		
<bll># i2cdetect -y $dev</bll>
$(  i2cdetect -y $dev )"
	fi
	echo "$config"
	;;
statustimezone )
	echo "<bll># timedatectl</bll>"
	timedatectl
	echo "
<code>NTP server</code>:     $( getVar NTP /etc/systemd/timesyncd.conf )
<code>Package mirror</code>: $( sed -n '/^Server/ {s/.*= //; p}' /etc/pacman.d/mirrorlist | head -1 )"
	;;
statuswlan )
	echo '<bll># iw reg get</bll>'
	iw reg get
	echo '<bll># iw list</bll>'
	iw list
	;;
tft )
	config=$( grep -Ev 'hdmi_force_hotplug|:rotate=' /boot/config.txt )
	sed -i 's/ fbcon=map:10 fbcon=font:ProFont6x11//' /boot/cmdline.txt
	if [[ $ON ]]; then
		[[ $MODEL != tft35a ]] && echo $MODEL > $dirsystem/lcdmodel || rm $dirsystem/lcdmodel
		sed -i '1 s/$/ fbcon=map:10 fbcon=font:ProFont6x11/' /boot/cmdline.txt
		config+="
hdmi_force_hotplug=1
dtoverlay=$MODEL:rotate=0"
		calibrationconf=/etc/X11/xorg.conf.d/99-calibration.conf
		[[ ! -e $calibrationconf ]] && cp /etc/X11/lcd0 $calibrationconf
		sed -i 's/fb0/fb1/' /etc/X11/xorg.conf.d/99-fbturbo.conf
		systemctl enable localbrowser
	else
		sed -i 's/fb1/fb0/' /etc/X11/xorg.conf.d/99-fbturbo.conf
	fi
	i2cset=1
	configTxt
	;;
tftcalibrate )
	degree=$( grep rotate /boot/config.txt | cut -d= -f3 )
	cp -f /etc/X11/{lcd$degree,xorg.conf.d/99-calibration.conf}
	systemctl stop localbrowser
	value=$( DISPLAY=:0 xinput_calibrator | grep Calibration | cut -d'"' -f4 )
	if [[ $value ]]; then
		sed -i -E 's/(Calibration" +").*/\1'$value'"/' /etc/X11/xorg.conf.d/99-calibration.conf
		systemctl start localbrowser
	fi
	;;
timezone )
	if [[ $TIMEZONE == auto ]]; then
		tz=$( curl -s https://ipapi.co/timezone )
		[[ ! $tz ]] && tz=$( curl -s http://ip-api.com | grep '"timezone"' | cut -d'"' -f4 )
		[[ ! $tz ]] && tz=$( curl -s https://worldtimeapi.org/api/ip | jq -r .timezone )
		[[ ! $tz ]] && tz=UTC
		timedatectl set-timezone $tz
	else
		timedatectl set-timezone $TIMEZONE
	fi
	pushRefresh
	;;
usbconnect | usbremove ) # for /etc/conf.d/devmon - devmon@http.service
	[[ ! -e $dirshm/startup ]] && exit # suppress on startup
	[[ -e $dirshm/audiocd ]] && exit
	
	if [[ $CMD == usbconnect ]]; then
		action=Ready
		name=$( lsblk -p -S -n -o VENDOR,MODEL | tail -1 )
		[[ ! $name ]] && name='USB Drive'
	else
		action=Removed
		name='USB Drive'
	fi
	notify usbdrive "$name" $action
	pushRefresh
	[[ ! -e $dirsystem/usbautoupdateno && ! -e $filesharedip ]] && $dirbash/cmd.sh mpcupdate$'\n'USB
	;;
usbautoupdate )
	[[ $ON ]] && rm -f $dirsystem/usbautoupdateno || touch $dirsystem/usbautoupdateno
	pushRefresh
	;;
vuled )
	enableFlagSet
	killProcess cava
	if [[ $ON ]]; then
		[[ ! -e $dirmpdconf/fifo.conf ]] && $dirsettings/player-conf.sh
		cava -p /etc/cava.conf | $dirbash/vu.sh &> /dev/null &
		echo $! > $dirshm/pidcava
	else
		. $dirsystem/vuled.conf
		for (( i=0; i < 7; i++ )); do
			pin=P$i
			echo 0 > /sys/class/gpio/gpio${!pin}/value
		done
		if [[ -e $dirsystem/vumeter ]]; then
			cava -p /etc/cava.conf | $dirsettings/vu.sh &> /dev/null &
			echo $! > $dirshm/pidcava
		else
			$dirsettings/player-conf.sh
		fi
	fi
	pushRefresh
	;;
wlan )
	if [[ $ON ]]; then
		! lsmod | grep -q -m1 brcmfmac && modprobe brcmfmac
		ifconfig wlan0 up
		echo wlan0 > $dirshm/wlan
		iw wlan0 set power_save off
		[[ $APAUTO ]] && rm -f $dirsystem/wlannoap || touch $dirsystem/wlannoap
		if [[ $REGDOM ]] && ! grep -q $REGDOM /etc/conf.d/wireless-regdom; then
			sed -i 's/".*"/"'$REGDOM'"/' /etc/conf.d/wireless-regdom
			iw reg set $REGDOM
		fi
	else
		systemctl -q is-active hostapd && $dirsettings/features.sh hostapd$'\n'OFF
		ifconfig wlan0 down
		rmmod brcmfmac
	fi
	pushRefresh
	ifconfig wlan0 | grep -q -m1 wlan0.*UP && active=true || active=false
	pushstream refresh '{"page":"networks","activewlan":'$active'}'
	;;
	
esac
