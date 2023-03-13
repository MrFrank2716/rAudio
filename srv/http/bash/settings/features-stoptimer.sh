#!/bin/bash

. /srv/http/bash/common.sh

min=$1
poweroff=$2

rm -f $dirshm/relaystimer
killall relays-timer.sh &> /dev/null

sleep $(( min * 60 ))

rm -f $dirshm/stoptimer

$dirbash/cmd.sh volume # mute
[[ $( < $dirshm/player ) == mpd ]] && $dirbash/cmd.sh mpcplayback$'\n'stop || $dirbash/cmd.sh playerstop
$dirbash/cmd.sh volume # unmute

if [[ $poweroff ]]; then
	$dirbash/cmd.sh poweroff
elif [[ -e $dirshm/relayson ]]; then
	$dirsettings/relays.sh off
fi
