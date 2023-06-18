#!/bin/bash

. /srv/http/bash/common.sh

killProcess statuspush
echo $$ > $dirshm/pidstatuspush

if [[ $1 == statusradio ]]; then # from status-radio.sh
	state=play
else
	status=$( $dirbash/status.sh )
	statusnew=$( sed '/^, "counts"/,/}/ d' <<< $status \
					| sed -E -n '/^, "Artist|^, "Album|^, "elapsed|^, "file| *"player|^, "station"|^, "state|^, "Time|^, "timestamp|^, "Title|^, "webradio"/ {
						s/^,* *"//; s/" *: */=/; p
						}' )
	echo "$statusnew" > $dirshm/statusnew
	if [[ -e $dirshm/status ]]; then
		statusprev=$( < $dirshm/status )
		compare='^Artist|^Title|^Album'
		[[ "$( grep -E "$compare" <<< $statusnew | sort )" != "$( grep -E "$compare" <<< $statusprev | sort )" ]] && trackchanged=1
		. <( echo "$statusnew" )
		if [[ $webradio == true ]]; then
			[[ ! $trackchanged && $state == play ]] && exit # >>>>>>>>>>
			
		else
			compare='^state|^elapsed'
			[[ "$( grep -E "$compare" <<< $statusnew | sort )" != "$( grep -E "$compare" <<< $statusprev | sort )" ]] && statuschanged=1
			[[ ! $trackchanged && ! $statuschanged ]] && exit # >>>>>>>>>>
			
		fi
	fi
	mv -f $dirshm/status{,prev}
	mv -f $dirshm/status{new,}
	pushstream mpdplayer "$status"
fi

if systemctl -q is-active localbrowser; then
	if grep -q onwhileplay=true $dirsystem/localbrowser.conf; then
		export DISPLAY=:0
		[[ $state == play ]] && sudo xset -dpms || sudo xset +dpms
	fi
fi

if [[ -e $dirshm/clientip ]]; then
	serverip=$( ipAddress )
	[[ ! $status ]] && status=$( $dirbash/status.sh ) # $statusradio
	status=$( sed -E -e '1,/^, "single" *:/ d;/^, "icon" *:/ d; /^, "login" *:/ d; /^}/ d
					' -e '/^, "stationcover"|^, "coverart"/ s|(" *: *")|\1http://'$serverip'|' <<< $status )
	status="{ ${status:1} }"
	clientip=$( < $dirshm/clientip )
	for ip in $clientip; do
		curl -s -X POST http://$ip/pub?id=mpdplayer -d "$status"
	done
fi
if [[ -e $dirsystem/lcdchar ]]; then
	sed -E 's/(true|false)$/\u\1/' $dirshm/status > $dirshm/lcdcharstatus.py
	systemctl restart lcdchar
fi

if [[ -e $dirsystem/mpdoled ]]; then
	[[ $state == play ]] && systemctl start mpd_oled || systemctl stop mpd_oled
fi

if [[ -e $dirsystem/vumeter || -e $dirsystem/vuled ]]; then
	killProcess cava
	if [[ $state == play ]]; then
		cava -p /etc/cava.conf | $dirbash/vu.sh &> /dev/null &
		echo $! > $dirshm/pidcava
	else
		pushstream vumeter '{ "val": 0 }'
		if [[ -e $dirsystem/vuled ]]; then
			p=$( < $dirsystem/vuled.conf )
			for i in $p; do
				echo 0 > /sys/class/gpio/gpio$i/value
			done
		fi
	fi
fi

[[ -e $dirsystem/librandom && $webradio == false ]] && $dirbash/cmd.sh mpclibrandom

pushstream refresh '{ "page": "player", "state": "'$state'" }'
pushstream refresh '{ "page": "features", "state": "'$state'" }'

[[ ! -e $dirsystem/scrobble ]] && exit

. $dirshm/statusprev
[[ ( $player != mpd ]] || ! grep -q $player=true $dirsystem/scrobble.conf ) && exit


[[ ! $Artist \
	|| ! $Title \
	|| $webradio == true \
	|| $Time < 30 ]] \
	|| ! ( $elapsed > 240 || $elapsed > $(( Time / 2 )) ) \
	&& exit

$dirbash/scrobble.sh &
