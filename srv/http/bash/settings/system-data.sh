#!/bin/bash

. /srv/http/bash/common.sh
[[ -e $dirshm/cpuinfo ]] && . $dirshm/cpuinfo || cpuInfo

timezone=$( timedatectl | awk '/zone:/ {print $3}' )
timezoneoffset=$( date +%z | sed -E 's/(..)$/:\1/' )
uptime=$( uptime -p | tr -d 's,' | sed 's/up //; s/ day/d/; s/ hour/h/; s/ minute/m/' )
status="\
$( cut -d' ' -f1-3 /proc/loadavg | sed 's| | <gr>•</gr> |g' )<br>\
$( /opt/vc/bin/vcgencmd measure_temp | sed -E 's/temp=(.*).C/\1 °C/' )<br>\
$( date +'%F <gr>•</gr> %T' )<wide class='gr'>&ensp;${timezone//\// · } $timezoneoffset</wide><br>\
$uptime<wide>&ensp;<gr>since $( uptime -s | cut -d: -f1-2 | sed 's/ / • /' )</gr></wide><br>"
if [[ $rpi3bplus ]]; then
	softlimit=$( grep temp_soft_limit /boot/config.txt | cut -d= -f2 )
	[[ ! $softlimit ]] && softlimit=60
fi
throttled=$( /opt/vc/bin/vcgencmd get_throttled | cut -d= -f2 )
if [[ $throttled != 0x0 ]]; then
	binary=$( python -c "print( bin( int( '$throttled', 16 ) ) )" ) # 0b01234567890123456789
	current=${binary: -4}                                                             # 6789
	occured=${binary:2:4}                                           # 0123
	e_current=( \
		"Soft temperature limit active <gr>(>$softlimit°C)</gr>" \
		'Currently throttled' \
		'Arm frequency capped' \
		'<red>Under-voltage</red> detected <gr>(<4.7V)</gr>' \
	)
	e_occured=( \
		"Soft temperature limit has occurred <gr>(>$softlimit°C)</gr>" \
		'Throttling has occurred' \
		'Arm frequency capping has occurred' \
		'<yl>Under-voltage</yl> has occurred <gr>(<4.7V)</gr>' \
	)
	[[ $softlimit ]] && digit='0 1 2 3' || digit='1 2 3'
	for i in $digit; do
		[[ ${current:i:1} == 1 ]] && warning+=" · ${e_current[i]}<br>"
	done
	for i in $digit; do
		[[ ${occured:i:1} == 1 ]] && warning+=" · ${e_occured[i]}<br>"
	done
fi
! internetConnected && warning+=" · <i class='i-networks'></i> Internet is offline"
# for interval refresh
[[ $1 == status ]] && pushstream refresh '{ "page": "system", "status": "'$status'", "warning": "'$warning'" }' && exit

if [[ -e $dirshm/system ]]; then
	system=$( < $dirshm/system )
else 
	readarray -t cpu <<< $( lscpu | awk '/Core|Model name|CPU max/ {print $NF}' )
	cpu=${cpu[0]}
	core=${cpu[1]}
	speed=${cpu[2]/.*}
	(( $speed < 1000 )) && speed+=' MHz' || speed=$( calc 2 $speed/1000 )' GHz'
	(( $core > 1 )) && soccpu="$core x $cpu" || soccpu=$cpu
	soccpu+=" @ $speed"
	rpimodel=$( tr -d '\000' < /proc/device-tree/model | sed -E 's/ Model //; s/ Plus/+/; s|( Rev.*)|<wide><gr>\1</gr></wide>|' )
	if [[ $rpimodel == *BeagleBone* ]]; then
		soc=AM3358
	else
		soc=BCM
		case $C in
			0 ) soc+=2835;; # 0, 1
			1 ) soc+=2836;; # 2
			2 ) case $BB in
					04|08 ) soc+=2837;;   # 2 1.2, 3B
					0d|0e ) soc+=2837B0;; # 3A+, 3B+
					12 )    soc+=2710A1;; # 0 2W
				esac;;
			3 ) soc+=2711;; # 4
		esac
	fi
	soc+=$( free -h | awk '/^Mem/ {print " <gr>•</gr> "$2}' | sed -E 's|(.i)| \1B|' )
	system="\
rAudio $( getContent $diraddons/r1 )<br>\
$( uname -rm | sed -E 's|-rpi-ARCH (.*)| <gr>\1</gr>|' )<br>\
$rpimodel<br>\
$soc<br>\
$soccpu"
	echo "$system" > $dirshm/system
fi

ifconfiglan=$( ifconfig | grep -A2 ^e )
if [[ $ifconfiglan ]]; then
	if [[ -e $dirsystem/soundprofile.conf ]]; then
		soundprofileconf=$( conf2json $dirsystem/soundprofile.conf )
	else
		swappiness=$( sysctl vm.swappiness | cut -d' ' -f3 )
		mtu=$( awk '/mtu/ {print $4}' <<< $ifconfiglan )
		txqueuelen=$( awk '/txqueuelen/ {print $4}' <<< $ifconfiglan )
		soundprofileconf='{ "SWAPPINESS": '$swappiness', "MTU": '$mtu', "TXQUEUELEN": '$txqueuelen' }'
	fi
fi

packageActive bluetooth hostapd nfs-server rotaryencoder smb

# sd, usb and nas
smb=$smb
if mount | grep -q -m1 'mmcblk0p2 on /'; then
	used_size=( $( df -lh --output=used,size,target | grep '/$' ) )
	list+=',{
  "icon"       : "microsd"
, "mountpoint" : "/<g>mnt/MPD/SD</g>"
, "mounted"    : true
, "source"     : "/dev/mmcblk0p2"
, "size"       : "'${used_size[0]}'B/'${used_size[1]}'B"
, "nfs"        : '$( grep -q -m1 $dirsd /etc/exports && echo true )'
, "smb"        : '$smb'
}'
fi
usb=$( mount | grep ^/dev/sd | cut -d' ' -f1 )
if [[ $usb ]]; then
	readarray -t usb <<< $usb
	for source in "${usb[@]}"; do
		mountpoint=$( df -l --output=target,source | sed -n "\|$source| {s| *$source||; p}" )
		if [[ $mountpoint ]]; then
			used_size=( $( df -lh --output=used,size,source | grep "$source" ) )
			list+=',{
  "icon"       : "usbdrive"
, "mountpoint" : "'$( stringEscape $mountpoint )'"
, "mounted"    : true
, "source"     : "'$source'"
, "size"       : "'${used_size[0]}'B/'${used_size[1]}'B"
, "nfs"        : '$( grep -q -m1 "$mountpoint" /etc/exports && echo true )'
, "smb"        : '$( [[ $smb == true && $mountpoint == $dirusb ]] && echo true )'
}'
		else
			label=$( e2label $source )
			[[ ! $label ]] && label=?
			list+=',{"icon":"usbdrive","mountpoint":"'$dirusb/$label'","mounted":false,"source":"'$source'"}'
		fi
		[[ ! $hddapm ]] && hddapm=$( hdparm -B $source \
										| grep -m1 APM_level \
										| tr -d -c 0-9 )
	done
fi
nas=$( grep -E '/mnt/MPD/NAS|/srv/http/data' /etc/fstab | tr -s ' ' )
if [[ $nas ]]; then
	readarray -t nas <<< $( cut -d' ' -f1-2 <<< $nas | sort )
	for line in "${nas[@]}"; do
		source=${line/ *}
		source=${source//\\040/ }
		mountpoint=${line/* }
		mountpoint=${mountpoint//\\040/ }
		used_size=( $( timeout 0.1s df -h --output=used,size,source | grep "$source" ) )
		list+=',{
  "icon"       : "networks"
, "mountpoint" : "'$( stringEscape $mountpoint )'"'
		if [[ $used_size ]]; then
			list+='
, "mounted"    : true
, "source"     : "'$source'"
, "size"       : "'${used_size[0]}'B/'${used_size[1]}'B"
}'
		else
			list+='
, "mounted"    : false
, "source"     : "'$source'"
}'
		fi
	done
fi
list="[ ${list:1} ]"
# i2smodule
if [[ -e $dirsystem/audio-aplayname && -e $dirsystem/audio-output ]]; then
	audioaplayname=$( < $dirsystem/audio-aplayname )
	audiooutput=$( < $dirsystem/audio-output )
	i2smodulesw=$( grep -q "$audiooutput.*$audioaplayname" /srv/http/assets/data/system-i2s.json && echo true )
fi
# reboot
if [[ -e $dirshm/reboot ]]; then
	reboot=$( cat $dirshm/reboot )
	grep -q TFT <<< $reboot && tftreboot=true
	grep -q Character <<< $reboot && lcdcharreboot=true
	grep -q Spectrum <<< $reboot && mpdoledreboot=true
fi
# relays
if [[ -e $dirsystem/relays.conf ]]; then
	. $dirsystem/relays.conf
	on=( $on )
	off=( $off )
	ond=( $ond )
	offd=( $offd )
	pL=${#on[@]}
	dL=$(( pL - 1 ))
	for (( i=0; i < $pL; i++ )); do
						conf+=', "ON'$i'"  : '${on[i]}',  "OFF'$i'"  : '${off[i]}
		(( i < dL )) && conf+=', "OND'$i'" : '${ond[i]}', "OFFD'$i'" : '${offd[i]}
	done
	conf+=', "TIMER": '$timer
	relaysconf='{ '${conf:1}' }'
fi
# tft
tftmodel=$( getContent $dirsystem/lcdmodel )
[[ $tftmodel ]] && tftconf='{ "MODEL": "'$tftmodel'" }'
if grep -q -m1 dtparam=i2c_arm=on /boot/config.txt; then
	dev=$( ls /dev/i2c* 2> /dev/null | cut -d- -f2 )
	lines=$( i2cdetect -y $dev 2> /dev/null )
	if [[ $lines ]]; then
		hex=$( grep -v '^\s' <<< $lines \
					| cut -d' ' -f2- \
					| tr -d ' \-' \
					| grep -E -v '^\s*$|UU' \
					| sort -u )
		for h in $hex; do
			address+=','$(( 16#$h ))
		done
		lcdcharaddr='[ '${address:1}' ]'
	fi
fi
# vuled
chip=$( grep mpd_oled /etc/systemd/system/mpd_oled.service | cut -d' ' -f3 )
baud=$( grep baudrate /boot/config.txt | cut -d= -f3 )
[[ ! $baud ]] && baud=800000
mpdoledconf='{ "CHIP": "'$chip'", "BAUD": '$baud' }'

data+='
  "page"              : "system"
, "audioaplayname"    : "'$audioaplayname'"
, "audiooutput"       : "'$audiooutput'"
, "display"           : { "logout" : '$( exists $dirsystem/login )' }
, "hddapm"            : '$hddapm'
, "hddsleep"          : '${hddapm/128/false}'
, "hdmi"              : '$( grep -q hdmi_force_hotplug=1 /boot/config.txt && echo true )'
, "hostapd"           : '$hostapd'
, "hostname"          : "'$( hostname )'"
, "i2seeprom"         : '$( grep -q -m1 force_eeprom_read=0 /boot/config.txt && echo true )'
, "i2smodulesw"       : '$i2smodulesw'
, "ipsub"                : "'$( ipSub )'"
, "lcdchar"           : '$( exists $dirsystem/lcdchar )'
, "lcdcharaddr"       : '$lcdcharaddr'
, "lcdcharconf"       : '$( conf2json lcdchar.conf )'
, "lcdcharreboot"     : '$lcdcharreboot'
, "list"              : '$list'
, "mirror"            : "'$( sed -n '/^Server/ {s|\.*mirror.*||; s|.*//||; p}' /etc/pacman.d/mirrorlist )'"
, "mpdoled"           : '$( exists $dirsystem/mpdoled )'
, "mpdoledconf"       : '$mpdoledconf'
, "mpdoledreboot"     : '$mpdoledreboot'
, "nfsserver"         : '$nfsserver'
, "ntp"               : "'$( getVar NTP /etc/systemd/timesyncd.conf )'"
, "powerbutton"       : '$( grep -q gpio-shutdown /boot/config.txt && echo true )'
, "powerbuttonconf"   : '$( conf2json powerbutton.conf )'
, "poweraudiophonics" : '$( grep -q 'poweroff,gpiopin=22' /boot/config.txt && echo true )'
, "relays"            : '$( exists $dirsystem/relays )'
, "relaysconf"        : '$relaysconf'
, "relaysnameconf"    : '$( getContent $dirsystem/relays.json )'
, "rotaryencoder"     : '$rotaryencoder'
, "rotaryencoderconf" : '$( conf2json rotaryencoder.conf )'
, "rpi01"             : '$( exists /boot/kernel.img )'
, "shareddata"        : '$( [[ -L $dirmpd ]] && echo true )'
, "soundprofile"      : '$( exists $dirsystem/soundprofile )'
, "soundprofileconf"  : '$soundprofileconf'
, "status"            : "'$status'"
, "system"            : "'$system'"
, "tft"               : '$( grep -q -m1 'dtoverlay=.*rotate=' /boot/config.txt && echo true )'
, "tftconf"           : '$tftconf'
, "tftreboot"         : '$tftreboot'
, "timezone"          : "'$timezone'"
, "timezoneoffset"    : "'$timezoneoffset'"
, "usbautoupdate"     : '$( [[ -e $dirsystem/usbautoupdate && ! -e $filesharedip ]] && echo true )'
, "vuled"             : '$( exists $dirsystem/vuled )'
, "vuledconf"         : '$( conf2json $dirsystem/vuled.conf )'
, "warning"           : "'$warning'"'

if [[ $onboardsound ]]; then
	data+='
, "audio"             : '$( grep -q ^dtparam=audio=on /boot/config.txt && echo true )'
, "audiocards"        : '$( aplay -l 2> /dev/null | grep ^card | grep -q -v 'bcm2835\|Loopback' && echo true )
fi
if [[ -e $dirshm/onboardwlan ]]; then
	regdom=$( cut -d'"' -f2 /etc/conf.d/wireless-regdom )
	apauto=$( [[ ! -e $dirsystem/wlannoap ]] && echo true )
	wlanconf='{ "REGDOM": "'$regdom'", "APAUTO": '$apauto' }'
	data+='
, "wlan"              : '$( lsmod | grep -q -m1 brcmfmac && echo true )'
, "wlanconf"          : '$wlanconf'
, "wlanconnected"     : '$( ip r | grep -q -m1 "^default.*wlan0" && echo true )
	discoverable=true
	if grep -q -m1 ^dtparam=krnbt=on /boot/config.txt; then
		bluetoothon=true
		bluetoothactive=$bluetooth
		if [[ $bluetoothactive == true ]]; then
			bluetoothctl show | grep -q -m1 'Discoverable: yes' && discoverable=true || discoverable=false
		fi
	fi
	format=$( exists $dirsystem/btformat )
	bluetoothconf='{ "DISCOVERABLE": '$discoverable', "FORMAT": '$format' }'
	data+='
, "bluetooth"         : '$bluetoothon'
, "bluetoothactive"   : '$bluetoothactive'
, "bluetoothconf"     : '$bluetoothconf'
, "btconnected"       : '$( [[ -e $dirshm/btconnected && $( awk NF $dirshm/btconnected ) ]] && echo true )
fi
if [[ $rpi3bplus ]]; then
	data+='
, "softlimit"         : '$( grep -q -m1 temp_soft_limit /boot/config.txt && echo true )'
, "softlimitconf"     : { "SOFTLIMIT": '$softlimit' }'
fi

data2json "$data" $1
