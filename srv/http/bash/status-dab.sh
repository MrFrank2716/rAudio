#!/bin/bash

. /srv/http/bash/common.sh

readarray -t tmpradio < $dirshm/radio
file=${tmpradio[0]}
station=${tmpradio[1]//\"/\\\"}
pos=$( mpc | grep '\[playing' | cut -d' ' -f2 | tr -d '#' )
song=$(( ${pos/\/*} - 1 ))
filelabel=$dirshm/webradio/DABlabel.txt
filecover=$dirshm/webradio/DABslide.jpg
filetitle=$dirshm/webradio/DABtitle

while true; do
	# title
	[[ ! $( awk NF $filelabel ) ]] && sleep 10 && continue
	
	if ! cmp -s $filelabel $filetitle; then
		cp -f $filelabel $filetitle
		data='{
  "Album"    : "DAB Radio"
, "Artist"   : "'$station'"
, "coverart" : ""
, "elapsed"  : '$( getElapsed )'
, "file"     : "'$file'"
, "icon"     : "dabradio"
, "sampling" : "'$pos' • 48 kHz 160 kbit/s • DAB"
, "state"    : "play"
, "song"     : '$song'
, "station"  : ""
, "Time"     : false
, "Title"    : "'$( < $filetitle )'"
}'
		$dirbash/status-push.sh statusradio "$data" &
	fi
	# coverart
	[[ ! $( awk NF $filecover ) ]] && sleep 10 && continue
	
	name=$( tr -d ' \"`?/#&'"'" < $filetitle )
	coverfile=/srv/http/data/shm/webradio/$name.jpg
	if ! cmp -s $filecover $coverfile; then # change later than title or multiple covers
		cp -f $filecover $coverfile
		coverart="${coverfile:9}"
		sed -i -e '/^coverart=/ d
' -e "$ a\
coverart=$coverart
" $dirshm/status
		pushstream coverart '{"type":"coverart","url":"'$coverart'"}'
	fi
	sleep 10
done
