#!/bin/bash

args2var "$1"

file=${args[1]}
album=${args[2]}
cue=${args[3]}
path="/mnt/MPD/$file"
args=( "${args[@]:4}" )
keys=( album albumartist artist composer conductor genre date )

if [[ $cue == false ]]; then
	if [[ $album == false ]]; then
		keys+=( title track )
		for i in {0..8}; do
			val=$( stringEscape ${args[i]} )
			[[ ! $val ]] && continue
			
			[[ $val == -1 ]] && val=
			kid3-cli -c "set ${keys[$i]} \"$val\"" "$path"
		done
		dir=$( dirname "$file" )
	else
		for i in {0..6}; do
			val=$( stringEscape ${args[i]} )
			[[ ! $val ]] && continue
			
			[[ $val == -1 ]] && val=
			kid3-cli -c "set ${keys[$i]} \"$val\"" "$path/"*.*
		done
		dir=$file
	fi
else
	if [[ $album == false ]]; then
		sed -i -E '/^\s+TRACK '${args[2]}'/ {
n; s/^(\s+TITLE).*/\1 "'${args[1]}'"/
n; s/^(\s+PERFORMER).*/\1 "'${args[0]}'"/
}
' "$path"
	else
		lines=( 'TITLE' 'PERFORMER' '' 'REM COMPOSER' 'REM CONDUCTOR' 'REM DATE' 'REM GENRE' )
		for i in {0..6}; do
			val=${args[$i]}
			[[ ! $val ]] && continue
			
			[[ ${lines[$i]} ]] && sed -i "/^${lines[$i]}/ d" "$path"
			[[ $val == -1 ]] && continue
			
			case $i in
				0 ) sed -i "1 i\TITLE \"$val\"" "$path";;
				1 ) sed -i "1 i\PERFORMER \"$val\"" "$path";;
				2 ) sed -i -E 's/^(\s+PERFORMER).*/\1 "'$val'"/' "$path";;
				3 ) sed -i "1 a\REM COMPOSER \"$val\"" "$path";;
				4 ) sed -i "1 a\REM CONDUCTOR \"$val\"" "$path";;
				5 ) sed -i "1 a\REM DATE \"$val\"" "$path";;
				6 ) sed -i "1 a\REM GENRE \"$val\"" "$path";;
			esac
		done
	fi
fi

curl -s -X POST http://127.0.0.1/pub?id=mpdupdate -d '{"type":"mpd"}'
touch /srv/http/data/mpd/updating
mpc update "$dir"
