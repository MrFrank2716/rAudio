#!/bin/bash

. /srv/http/bash/common.sh

. $dirsystem/rotaryencoder.conf

if [[ -e $dirshm/btreceiver ]]; then
	control=$( < $dirshm/btreceiver )
else
	card=$( < $dirsystem/asoundcard )
	control=$( cat $dirshm/amixercontrol 2> /dev/null )
fi

volume() {
	$dirbash/cmd.sh "volumeupdown
KEY updn card control
$1
$card
$control"
}

# play/pause
/opt/vc/bin/dtoverlay gpio-key gpio=$pins label=PLAYCD keycode=200
sleep 1
devinputbutton=$( realpath /dev/input/by-path/*button* )
evtest $devinputbutton | while read line; do
	[[ $line =~ .*EV_KEY.*KEY_PLAYCD.*1 ]] && $dirbash/cmd.sh mpcplayback
done &

/opt/vc/bin/dtoverlay rotary-encoder pin_a=$pina pin_b=$pinb relative_axis=1 steps-per-period=$step
sleep 1
devinputrotary=$( realpath /dev/input/by-path/*rotary* )
evtest $devinputrotary | while read line; do
	if [[ $line =~ 'value 1'$ ]]; then
		volume +
	elif [[ $line =~ 'value -1'$ ]]; then
		volume -
	fi
done
