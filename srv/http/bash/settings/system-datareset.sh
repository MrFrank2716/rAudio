#!/bin/bash

. /srv/http/bash/common.sh

if [[ ! $1 ]]; then # reset
	reset=1
	
	mpc -q crossfade 0
	systemctl stop mpd
	rm -f $dirsystem/{crossfade,custom,dop-*,listing,relays,soundprofile,updating}

	# lcd
	file=/etc/modules-load.d/raspberrypi.conf
	[[ -e $file ]] && sed -i -E '/i2c-bcm2708|i2c-dev/ d' $file
	#file=/usr/share/X11/xorg.conf.d/99-fbturbo.conf
	#[[ -e $file ]] && sed -i 's/fb1/fb0/' $file

	mv $diraddons /tmp
	rm -rf $dirdata
	partuuidROOT=$( grep ext4 /etc/fstab | cut -d' ' -f1 )
	cmdline="root=$partuuidROOT rw rootwait selinux=0 plymouth.enable=0 smsc95xx.turbo_mode=N \
dwc_otg.lpm_enable=0 elevator=noop ipv6.disable=1 fsck.repair=yes"
	cpuInfo
	[[ $core4 ]] && cmdline+=' isolcpus=3'
	if systemctl is-enabled localbrowser &> /dev/null; then
		config+=' console=tty3 quiet loglevel=0 logo.nologo vt.global_cursor_default=0'
	else
		config+=' console=tty1'
	fi
	echo $cmdline > /boot/cmdline.txt
	config="\
gpu_mem=32
initramfs initramfs-linux.img followkernel
max_usb_current=1
disable_splash=1
disable_overscan=1
dtparam=audio=on"
	[[ $BB =~ ^(08|0c|0d|0e|11|12)$ ]] && config+="
dtparam=krnbt=on"
	[[ $BB =~ ^(09|0c)$ ]] && config+="
force_turbo=1
hdmi_drive=2
over_voltage=2"
	echo "$config" > /boot/config.txt
fi

# data directories
mkdir -p $dirdata/{addons,audiocd,bookmarks,lyrics,mpd,playlists,system,webradio,webradio/img} /mnt/MPD/{NAS,SD,USB}
ln -sf /dev/shm $dirdata
ln -sf /mnt /srv/http/
if [[ -e /usr/bin/camilladsp ]]; then
	ln -sf /srv/http/assets/css/colors.css /srv/http/settings/camillagui/build
	ln -sf /srv/http/assets/img/icon.png /srv/http/settings/camillagui/build
fi
chown -h http:http $dirdata /srv/http/mnt

# addons - new/reset
if [[ $reset ]]; then
	mv /tmp/addons $dirdata
else
	dirs=$( ls $dirdata )
	for dir in $dirs; do
		printf -v dir$dir '%s' $dirdata/$dir
	done
	echo $1 > $dirsystem/version
	echo $2 > $diraddons/r$version
fi
# camillagui
dircamillagui=/srv/http/settings/camillagui/build
ln -sf /srv/http/assets/fonts $dircamillagui
ln -sf /srv/http/assets/css/colors.css $dircamillagui
ln -sf /srv/http/assets/img/icon.png $dircamillagui
# display
true='album albumartist artist bars buttons composer conductor count cover date fixedcover genre
	label latest nas playbackswitch playlists plclear plsimilar sd time usb volume webradio'
false='albumbyartist audiocdplclear backonleft barsalways camilladsp covervu hidecover
	multiraudio noswipe radioelapsed tapaddplay tapreplaceplay vumeter'
for i in $true; do
	lines+='
, "'$i'": true'
done
for i in $false; do
	lines+='
, "'$i'": false'
done
jq -S <<< {${lines:2}} > $dirsystem/display
# localbrowser
if [[ -e /usr/bin/chromium ]]; then
	rm -rf /root/.config/chromium
	echo "\
rotate=NORMAL
zoom=100
screenoff=0
onwhileplay=false
cursor=false" > $dirsystem/localbrowser.conf
fi
echo mpd > $dirshm/player
# relays
cat << EOF > $dirsystem/relays.conf
pin='[ 11,13,15,16 ]'
name='[ "DAC","PreAmp","Amp","Subwoofer" ]'
onorder='[ "DAC","PreAmp","Amp","Subwoofer" ]'
offorder='[ "Subwoofer","Amp","PreAmp", "DAC" ]'
on=( 11 13 15 16 )
ond=( 2 2 2 )
off=( 16 15 13 11 )
offd=( 2 2 2 )
timer=5
EOF
# system
echo rAudio > $dirsystem/hostname
hostnamectl set-hostname rAudio
sed -i 's/#NTP=.*/NTP=pool.ntp.org/' /etc/systemd/timesyncd.conf
sed -i 's/".*"/"00"/' /etc/conf.d/wireless-regdom
timedatectl set-timezone UTC
echo UTC > $dirsystem/timezone
touch $dirsystem/usbautoupdate

# mpd
curl -L https://github.com/rern/rAudio-addons/raw/main/webradio/radioparadise.tar.xz | bsdtar xvf - -C $dirwebradio # webradio default
if [[ ! -e $dirmpd/counts ]]; then
	echo '{
  "playlists" : '$( ls -1 $dirplaylists | wc -l )'
, "webradio"  : '$( find -L $dirwebradio -type f ! -path '*/img/*' | wc -l )'
}' > $dirmpd/counts
fi

usermod -a -G root http # add user http to group root to allow /dev/gpiomem access

# services
systemctl -q disable --now bluetooth hostapd shairport-sync smb spotifyd upmpdcli

# set ownership and permissions
$dirsettings/system.sh dirpermissions

[[ $reset ]] && $dirbash/cmd.sh power$'\n'reboot
