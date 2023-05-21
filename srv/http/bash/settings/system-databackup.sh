#!/bin/bash

. /srv/http/bash/common.sh

dirconfig=$dirdata/config
backupfile=$dirshm/backup.gz
rm -f $backupfile
alsactl store
files=(
	/boot/cmdline.txt
	/boot/config.txt
	/boot/shutdown.sh
	/boot/startup.sh
	/etc/conf.d/wireless-regdom
	/etc/default/snapclient
	/etc/hostapd/hostapd.conf
	/etc/modules-load.d/loopback.conf
	/etc/pacman.d/mirrorlist
	/etc/samba/smb.conf
	/etc/systemd/network/eth.network
	/etc/systemd/timesyncd.conf
	/etc/X11/xorg.conf.d/99-calibration.conf
	/etc/X11/xorg.conf.d/99-raspi-rotate.conf
	/etc/exports
	/etc/fstab
	/etc/mpdscribble.conf
	/etc/upmpdcli.conf
	/mnt/MPD/NAS/data
	/var/lib/alsa/asound.state
)
for file in ${files[@]}; do
	if [[ -e $file ]]; then
		mkdir -p $dirconfig/$( dirname $file )
		cp {,$dirconfig}$file
	fi
done
crossfade=$( mpc crossfade | cut -d' ' -f2 )
[[ $crossfade ]] && echo $crossfade > $dirsystem/crossfade
hostname > $dirsystem/hostname
timedatectl | awk '/zone:/ {print $3}' > $dirsystem/timezone
readarray -t profiles <<< $( ls -p /etc/netctl | grep -v / )
if [[ $profiles ]]; then
	cp -r /etc/netctl $dirconfig/etc
	for profile in "${profiles[@]}"; do
		if [[ $( netctl is-enabled "$profile" ) == enabled ]]; then
			echo $profile > $dirsystem/netctlprofile
			break
		fi
	done
fi
mkdir -p $dirconfig/var/lib
cp -r /var/lib/bluetooth $dirconfig/var/lib &> /dev/null
xinitrcfiles=$( ls /etc/X11/xinit/xinitrc.d | grep -v 50-systemd-user.sh )
if [[ $xinitrcfiles ]]; then
	mkdir -p $dirconfig/etc/X11/xinit
	cp -r /etc/X11/xinit/xinitrc.d $dirconfig/etc/X11/xinit
fi

services='bluetooth camilladsp hostapd localbrowser mediamtx nfs-server powerbutton shairport-sync smb snapclient spotifyd upmpdcli'
for service in $services; do
	systemctl -q is-active $service && enable+=" $service" || disable+=" $service"
done
[[ $enable ]] && echo $enable > $dirsystem/enable
[[ $disable ]] && echo $disable > $dirsystem/disable

bsdtar \
	--exclude './addons' \
	--exclude './embedded' \
	--exclude './shm' \
	-czf $backupfile \
	-C /srv/http \
	data \
	2> /dev/null && echo 1

rm -rf $dirdata/{config,disable,enable}
rm -f $dirsystem/{crossfade,hostname,timezone}
