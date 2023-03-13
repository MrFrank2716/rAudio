#!/bin/bash

. /srv/http/bash/common.sh

readarray -t args <<< $1

protocol=${args[1]}
mountpoint="$dirnas/${args[2]}"
ip=${args[3]}
directory=${args[4]}
user=${args[5]}
password=${args[6]}
extraoptions=${args[7]}
shareddata=${args[8]}

! ping -c 1 -w 1 $ip &> /dev/null && echo "IP address not found: <wh>$ip</wh>" && exit

[[ $( ls "$mountpoint" ) ]] && echo "Mount name <code>$mountpoint</code> not empty." && exit

umount -ql "$mountpoint"
mkdir -p "$mountpoint"
chown mpd:audio "$mountpoint"
if [[ $protocol == cifs ]]; then
	source="//$ip/$directory"
	options=noauto
	if [[ ! $user ]]; then
		options+=,username=guest
	else
		options+=",username=$user,password=$password"
	fi
	options+=,uid=$( id -u mpd ),gid=$( id -g mpd ),iocharset=utf8
else
	source="$ip:$directory"
	options=defaults,noauto,bg,soft,timeo=5
fi
[[ $extraoptions ]] && options+=,$extraoptions
fstab="\
$( < /etc/fstab )
${source// /\\040}  ${mountpoint// /\\040}  $protocol  ${options// /\\040}  0  0"
mv /etc/fstab{,.backup}
column -t <<< $fstab > /etc/fstab
systemctl daemon-reload
std=$( mount "$mountpoint" 2>&1 )
if [[ $? != 0 ]]; then
	mv -f /etc/fstab{.backup,}
	rmdir "$mountpoint"
	systemctl daemon-reload
	echo "\
Mount failed:
<br><code>$source</code>
<br>$( sed -n '1 {s/.*: //; p}' <<< $std )"
	exit
	
else
	rm /etc/fstab.backup
fi

[[ $update == true ]] && $dirbash/cmd.sh mpcupdate$'\n'"${mountpoint:9}"  # /mnt/MPD/NAS/... > NAS/...
for i in {1..5}; do
	sleep 1
	mount | grep -q -m1 "$mountpoint" && break
done
[[ $shareddata == true ]] && $dirsettings/system.sh shareddataset || pushRefresh
