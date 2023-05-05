#!/bin/bash

. /srv/http/bash/common.sh

backupfile=$dirshm/backup.gz
dirconfig=$dirdata/config

statePlay && $dirbash/cmd.sh playerstop
find $dirmpdconf -maxdepth 1 -type l -exec rm {} \; # mpd.conf symlink
if [[ -e $dirsystem/listing || -e $dirsystem/updating ]]; then
	rm -f $dirsystem/{listing,updating}
	systemctl restart mpd
fi

if bsdtar tf $backupfile | grep -q display.json$; then # 20230420
	bsdtar -xpf $backupfile -C /srv/http
else
	echo 'Backup done before version <wh>20230420</wh>:
These will not be restored:
<div style="padding-left: 90px; text-align: left">
• Autoplay
• Browser on RPi
• Charater LCD
• Equalizer
• Multiple rAudios
• Relay Module
• Spectrum OLED</div>'
	bsdtar -xpf $backupfile \
		--exclude autoplay* \
		--exclude localbrowser* \
		--exclude lcdchar* \
		--exclude equalizer* \
		--exclude multiraudio* \
		--exclude relays* \
		--exclude vuled* \
			-C /srv/http
fi

dirPermissions
[[ -e $dirsystem/color ]] && $dirbash/cmd.sh color
uuid1=$( head -1 /etc/fstab | cut -d' ' -f1 )
uuid2=${uuid1:0:-1}2
sed -i "s/root=.* rw/root=$uuid2 rw/; s/elevator=noop //" $dirconfig/boot/cmdline.txt
sed -i "s/^PARTUUID=.*-01  /$uuid1  /; s/^PARTUUID=.*-02  /$uuid2  /" $dirconfig/etc/fstab

cp -rf $dirconfig/* /
[[ -e $dirsystem/enable ]] && systemctl -q enable $( < $dirsystem/enable )
[[ -e $dirsystem/disable ]] && systemctl -q disable $( < $dirsystem/disable )
grep -q nfs-server $dirsystem/enable && $dirsettings/features.sh nfsserver
$dirsettings/system.sh "hostname
$( < $dirsystem/hostname )
CMD HOSTNAME"
[[ -e $dirsystem/netctlprofile ]] && netctl enable "$( < $dirsystem/netctlprofile )"
timedatectl set-timezone $( < $dirsystem/timezone )
[[ -e $dirsystem/crossfade ]] && mpc crossfade $( < $dirsystem/crossfade )
rm -rf $backupfile $dirconfig $dirsystem/{crossfade,enable,disable,hostname,netctlprofile,timezone}
readarray -t dirs <<< $( find $dirnas -mindepth 1 -maxdepth 1 -type d )
for dir in "${dirs[@]}"; do
	umount -l "$dir" &> /dev/null
	rmdir "$dir" &> /dev/null
done
ipserver=$( grep $dirshareddata /etc/fstab | cut -d: -f1 )
if [[ $ipserver ]]; then
	fstab=$( sed "/^$ipserver/ d" /etc/fstab )
	column -t <<< $fstab > /etc/fstab
fi
readarray -t mountpoints <<< $( grep $dirnas /etc/fstab | awk '{print $2}' | sed 's/\\040/ /g' )
if [[ $mountpoints ]]; then
	for mountpoint in $mountpoints; do
		mkdir -p "$mountpoint"
	done
fi
$dirbash/cmd.sh reboot
