#!/bin/bash

. /srv/http/bash/common.sh

backupfile=$dirshm/backup.gz
dirconfig=$dirdata/config
[[ $1 == true ]] && libraryonly=1

statePlay && $dirbash/cmd.sh playerstop
if [[ -e $dirsystem/listing || -e $dirsystem/updating ]]; then
	rm -f $dirsystem/{listing,updating}
	[[ ! $libraryonly ]] && systemctl restart mpd
fi

if [[ $libraryonly ]]; then
	bsdtar -xpf $backupfile -C /srv/http data/{mpd,playlists,webradio}
	systemctl restart mpd
	exit
fi

find $dirmpdconf -maxdepth 1 -type l -exec rm {} \; # mpd.conf symlink

if bsdtar tf $backupfile | grep -q display.json$; then # 20230522
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
CMD NAME"
[[ -e $dirsystem/netctlprofile ]] && netctl enable "$( < $dirsystem/netctlprofile )"
timedatectl set-timezone $( < $dirsystem/timezone )
[[ -e $dirsystem/crossfade ]] && mpc crossfade $( < $dirsystem/crossfade )
rm -rf $backupfile $dirconfig $dirsystem/{crossfade,enable,disable,hostname,netctlprofile,timezone}
readarray -t dirs <<< $( find $dirnas -mindepth 1 -maxdepth 1 -type d )
for dir in "${dirs[@]}"; do
	umount -l "$dir" &> /dev/null
	rmdir "$dir" &> /dev/null
done
readarray -t mountpoints <<< $( grep $dirnas /etc/fstab | awk '{print $2}' )
if [[ $mountpoints ]]; then
	for mountpoint in $mountpoints; do
		mkdir -p "${mountpoint//\\040/ }"
	done
fi
$dirbash/power.sh reboot
