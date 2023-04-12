#!/bin/bash

. /srv/http/bash/common.sh

sleep 3 # wait for eventX added to /dev/input/

control=$( < $dirshm/btreceiver )
mac=$( bluetoothctl show \
		| head -1 \
		| cut -d' ' -f2 )
event=$( sed -n "/Phys=${mac,,}/,/Handlers=/ {/Handlers=/ {s/^.*=//; p}}" /proc/bus/input/devices | awk '{print $NF}' ) # /proc/... contains trailing space

# line='Event: time 1678155098.191722, type 1 (EV_KEY), code 200 (KEY_XXXXXX), value 1'
evtest /dev/input/$event | while read line; do
	! grep -Eq '^E.*(CD\)|SONG\)|VOLUME).*1$' <<< $line && continue # PLAYCD PAUSECD STOPCD NEXTSONG PREVIOUSSONG VOLUMEUP VOLUMEDOWN
	
	key=$( sed -E 's/.*KEY_(.*)\).*/\1/; s/CD|IOUSSONG|SONG//' <<< $line )
	key=${key,,}
	case $key in
		next|prev )  $dirbash/cmd.sh mpcprevnext$'\n'$key;;
		play|pause ) $dirbash/cmd.sh mpcplayback;;
		stop )       $dirbash/cmd.sh mpcplayback$'\n'stop;;
		volumedown ) volumeUpDnBt 1%- "$control";;
		volumeup )   volumeUpDnBt 1%+ "$control";;
	esac
done
