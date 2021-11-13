#!/bin/bash

# from:
#    - cmd-pushstatus.sh
#    - cmd.sh scrobble(by webradio)

. /srv/http/bash/common.sh

. $dirshm/scrobble
[[ -z $Artist || -z $Title || $state == pause ]] && exit

if [[ $state == play ]]; then # skip if start playing
	statuselapsed=$( grep ^elapsed= $dirshm/status | cut -d= -f2 )
	diff=$(( statuselapsed - elapsed ))
	(( ${diff/-} < 5 )) && exit
elif [[ $state == stop ]]; then
	[[ -z $Time || -z $elapsed ]] && exit
	(( $elapsed < $Time / 2 && $elapsed < 240 )) && exit
fi

keys=( $( grep 'apikeylastfm\|sharedsecret' /srv/http/assets/js/main.js | cut -d"'" -f2 ) )
apikey=${keys[0]}
sharedsecret=${keys[1]}
sk=$( cat $dirsystem/scrobble.conf/key )
timestamp=$( date +%s )
if [[ -n $album ]]; then
	sigalbum="album${Album}"
	dataalbum="album=$Album"
fi
apisig=$( echo -n "${sigalbum}api_key${apikey}artist${Artist}methodtrack.scrobblesk${sk}timestamp${timestamp}track${Title}${sharedsecret}" \
			| iconv -t utf8 \
			| md5sum \
			| cut -c1-32 )
reponse=$( curl -sX POST \
	--data-urlencode "$dataalbum" \
	--data "api_key=$apikey" \
	--data-urlencode "artist=$Artist" \
	--data "method=track.scrobble" \
	--data "sk=$sk" \
	--data "timestamp=$timestamp" \
	--data-urlencode "track=$Title" \
	--data "api_sig=$apisig" \
	--data "format=json" \
	http://ws.audioscrobbler.com/2.0 )
if [[ $reponse =~ error ]]; then
	msg="Error: $( jq -r .message <<< $response )"
else
	[[ -e $dirsystem/scrobble.conf/notify ]] && msg="${Title//\"/\\\"}"
fi
[[ -n $msg ]] && pushstreamNotify Scrobble "$msg" lastfm
