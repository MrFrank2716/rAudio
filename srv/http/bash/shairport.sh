#!/bin/bash

# shairport.service > this:
#    - /tmp/shairport-sync-metadata emits data

. /srv/http/bash/common.sh
dirairplay=$dirshm/airplay

cat /tmp/shairport-sync-metadata | while read line; do
	[[ $line =~ 'encoding="base64"' || $line =~ '<code>'.*'<code>' ]] && continue # skip: no value / double codes
	
	##### code - hex matched
	hex=$( sed -E 's|.*code>(.*)</code.*|\1|' <<< $line )
	if [[ $hex ]]; then # found code > [next line]
		case $hex in
			61736172 ) code=Artist   && continue;;
			6d696e6d ) code=Title    && continue;;
			6173616c ) code=Album    && continue;;
			50494354 ) code=coverart && continue;;
			70726772 ) code=progress && continue;;
		esac
	fi
	
	# no line with code found yet > [next line]
	[[ ! $code ]] && continue
	
	##### value - base64 decode
	base64=$( tr -d '\000' <<< ${line/<*} ) # remove tags and null bytes
	# null or not base64 string - reset code= > [next line]
	if [[ ! $base64 || ! $base64 =~ ^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{2}==)?$ ]]; then
		code=
		continue
	fi
	
	if [[ $code == coverart ]]; then
		base64 -d <<< $base64 > $dirairplay/coverart.jpg
		pushstream airplay '{ "coverart": "/data/shm/airplay/coverart.jpg" }'
	else
		data=$( base64 -d <<< $base64 2> /dev/null )
		if [[ $code == progress ]]; then # format: start/elapsed/end @44100/s
			progress=( ${data//\// } )
			start=${progress[0]}
			current=${progress[1]}
			end=${progress[2]}
			elapsedms=$( awk 'BEGIN { printf "%.0f", '$(( current - start ))/44.1' }' )
			elapsed=$(( ( elapsedms + 500 ) / 1000 ))
			Time=$(( ( end - start + 22050 ) / 44100 ))
			if (( $Time < 30 || ( $elapsed < 240 && $elapsed < $Time / 2 ) )); then
				touch $dirshm/scrobble
				( sleep 3 && rm -f $dirshm/scrobble ) &> /dev/null &
			fi
			pushstream airplay '{ "elapsed": '$elapsed', "Time": '$Time' }'
			timestamp=$( date +%s%3N )
			starttime=$(( timestamp - elapsedms ))
			echo $starttime > $dirairplay/start
			echo $Time > $dirairplay/Time
			$dirbash/status-push.sh
		else
			echo $data > $dirairplay/$code
			pushstream airplay '{ "'$code'": "'$( stringEscape $data )'" }'
		fi
	fi
	code= # reset after $code + $data were set
done
