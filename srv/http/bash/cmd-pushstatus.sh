#!/bin/bash

dirtmp=/srv/http/data/shm

# throttle multiple firing from mpdidle.sh
[[ -e $dirtmp/push ]] && exit
touch $dirtmp/push
( sleep 1 && rm $dirtmp/push ) &> /dev/null &

status=$( /srv/http/bash/status.sh )

statusdata=$( echo $status \
	| jq -r '.Artist, .Title, .Album, .state, .Time, .elapsed, .timestamp, .station, .file, .webradio' \
	| sed 's/^$\|null/false/' )
readarray -t data <<< "$statusdata"
if [[ ${data[ 9 ]} == false ]]; then # not webradio
	datanew=${data[@]:0:6}
	dataprev=$( head -6 $dirtmp/status 2> /dev/null | tr -d '\n' )
	[[ ${datanew// } == ${dataprev// } ]] && exit
else
	datanew=${data[@]:0:3}
	dataprev=$( head -3 $dirtmp/status 2> /dev/null | tr -d '\n' )
	[[ ${data[3]} == play && ${datanew// } == ${dataprev// } ]] && exit
fi

curl -s -X POST http://127.0.0.1/pub?id=mpdplayer -d "$status"

if [[ -e /srv/http/data/system/lcdchar ]]; then
	killall lcdchar.py &> /dev/null
	readarray -t data <<< $( echo "$statusdata" | sed 's/""/"/g; s/"/\\"/g' )
	/srv/http/bash/lcdchar.py "${data[@]}" &
fi

if [[ -e $dirtmp/snapclientip ]]; then
	status=$( echo $status | jq . | sed '/"player":/,/"single":/ d' )
	readarray -t clientip < $dirtmp/snapclientip
	for ip in "${clientip[@]}"; do
		[[ -n $ip ]] && curl -s -X POST http://$ip/pub?id=mpdplayer -d "$status"
	done
fi
[[ -e /srv/http/data/system/librandom ]] && /srv/http/bash/cmd-librandom.sh

echo "$statusdata" > $dirtmp/status
