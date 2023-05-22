#!/bin/bash

. /srv/http/bash/common.sh
dirimg=/srv/http/assets/img

args2var "$1"

plAddPlay() {
	pushstreamPlaylist add
	if [[ ${1: -4} == play ]]; then
		sleep $2
		mpc -q play $pos
		$dirbash/status-push.sh
	fi
}
plAddPosition() {
	if [[ ${1:0:7} == replace ]]; then
		mpc -q clear
		pos=1
	else
		pos=$(( $( mpc status %length% ) + 1 ))
	fi
}
plAddRandom() {
	local cuefile diffcount dir file mpcls plL range tail
	tail=$( plTail )
	(( $tail > 1 )) && pushstreamPlaylist add && return
	
	dir=$( shuf -n 1 $dirmpd/album | cut -d^ -f7 )
	mpcls=$( mpc ls "$dir" )
	cuefile=$( grep -m1 '\.cue$' <<< $mpcls )
	if [[ $cuefile ]]; then
		plL=$(( $( grep -c '^\s*TRACK' "/mnt/MPD/$cuefile" ) - 1 ))
		range=$( shuf -i 0-$plL -n 1 )
		file="$range $cuefile"
		grep -q -m1 "$file" $dirsystem/librandom && plAddRandom && return
		
		mpc --range=$range load "$cuefile"
	else
		file=$( shuf -n 1 <<< $mpcls )
		grep -q -m1 "$file" $dirsystem/librandom && plAddRandom && return
		
		mpc add "$file"
	fi
	diffcount=$(( $( jq .song $dirmpd/counts ) - $( wc -l < $dirsystem/librandom ) ))
	if (( $diffcount > 1 )); then
		echo $file >> $dirsystem/librandom
	else
		> $dirsystem/librandom
	fi
	(( $tail > 1 )) || plAddRandom
}
plTail() {
	local pos total
	total=$( mpc status %length% )
	pos=$( mpc status %songpos% )
	echo $(( total - pos ))
}
pushstreamPlaylist() {
	local arg
	[[ $1 ]] && arg=$1 || arg=current
	pushstream playlist $( php /srv/http/mpdplaylist.php $arg )
}
pushstreamSavedPlaylist() {
	pushstream savedplaylist $( php /srv/http/mpdplaylist.php list )
}
pushstreamRadioList() {
	pushstream radiolist '{ "type": "webradio" }'
}
pushstreamVolume() {
	pushstream volume '{ "type": "'$1'", "val": '$2' }'
}
rotateSplash() {
	local degree rotate
	rotate=$( getVar rotate $dirsystem/localbrowser.conf )
	case $rotate in
		NORMAL ) degree=0;;
		CCW )    degree=-90;;
		CW )     degree=90;;
		UD )     degree=180;;
	esac
	convert \
		-density 48 \
		-background none $dirimg/icon.svg \
		-rotate $degree \
		-gravity center \
		-background '#000' \
		-extent 1920x1080 \
		$dirimg/splash.png
}
scrobbleOnStop() {
	. $dirshm/scrobble
	if [[ ! $Artist || ! $Title || $webradio == true || $Time < 30 ]] \
		|| ! ( $elapsed > 240 || $elapsed > $(( Time / 2 )) ); then
		return
	fi
	
	$dirbash/scrobble.sh "cmd
$Artist
$Title
$Album
CMD ARTIST TITLE ALBUM" &> /dev/null &
	rm -f $dirshm/scrobble
}
stopRadio() {
	if [[ -e $dirshm/radio ]]; then
		mpc -q stop
		systemctl stop radio dab &> /dev/null
		rm -f $dirshm/radio
		[[ $1 == stop ]] && $dirbash/status-push.sh
		sleep 1
	fi
}
urldecode() { # for webradio url to filename
	: "${*//+/ }"
	echo -e "${_//%/\\x}"
}
volumeSet() {
	local card control current diff target values
	current=$1
	target=$2
	control=$3
	card=$4
	diff=$(( $target - $current ))
	if (( ${diff#-} < 5 )); then
		volumeSetAt $target "$control" $card
	else # increment
		(( $diff > 0 )) && incr=5 || incr=-5
		values=( $( seq $(( current + incr )) $incr $target ) )
		(( $diff % 5 )) && values+=( $target )
		for i in "${values[@]}"; do
			volumeSetAt $i "$control" $card
			sleep 0.2
		done
	fi
	[[ $control && ! -e $dirshm/btreceiver ]] && alsactl store
}
volumeSetAt() {
	local card control target
	target=$1
	control=$2
	card=$3
	if [[ -e $dirshm/btreceiver ]]; then
		amixer -MqD bluealsa sset "$control" $target% 2> /dev/null
		echo $target > "$dirsystem/btvolume-$control"
	elif [[ $control ]]; then
		amixer -c $card -Mq sset "$control" $target%
	else
		mpc -q volume $target
	fi
}
webradioCount() {
	local count type
	[[ $1 == dabradio ]] && type=dabradio || type=webradio
	count=$( find -L $dirdata/$type -type f ! -path '*/img/*' | wc -l )
	pushstream radiolist '{ "type": "'$type'", "count": '$count' }'
	grep -q -m1 "$type.*,"$ $dirmpd/counts && count+=,
	sed -i -E 's/("'$type'": ).*/\1'$count'/' $dirmpd/counts
}
webradioPlaylistVerify() {
	local ext url
	ext=$1
	url=$2
	if [[ $ext == m3u ]]; then
		url=$( curl -s $url 2> /dev/null | grep -m1 ^http )
	elif [[ $ext == pls ]]; then
		url=$( curl -s $url 2> /dev/null | grep -m1 ^File | cut -d= -f2 )
	fi
	[[ ! $url ]] && echo 'No valid URL found in:' && exit
}
webRadioSampling() {
	local bitrate data file kb rate sample samplerate url
	url=$1
	file=$2
	timeout 3 curl -sL $url -o /tmp/webradio
	[[ ! $( awk NF /tmp/webradio ) ]] && echo 'Cannot be streamed:' && exit
	
	data=( $( ffprobe -v quiet -select_streams a:0 \
				-show_entries stream=sample_rate \
				-show_entries format=bit_rate \
				-of default=noprint_wrappers=1:nokey=1 \
				/tmp/webradio ) )
	[[ ! $data ]] && 'No stream data found:' && exit
	
	samplerate=${data[0]}
	bitrate=${data[1]}
	sample="$( calc 1 $samplerate/1000 ) kHz"
	kb=$(( bitrate / 1000 ))
	rate="$(( ( ( kb + 4 ) / 8 ) * 8 )) kbit/s" # round to modulo 8
	sed -i "2 s|.*|$sample $rate|" "$file"
	rm /tmp/webradio
}

case $CMD in

albumignore )
	sed -i "/\^$ALBUM^^$ARTIST^/ d" $dirmpd/album
	sed -i "/\^$ARTIST^^$ALBUM^/ d" $dirmpd/albumbyartist
	echo $ALBUM^^$ARTIST >> $dirmpd/albumignore
	;;
bookmarkadd )
	bkfile="$dirbookmarks/${NAME//\//|}"
	[[ -e $bkfile ]] && echo -1 && exit
	
	echo $DIR > "$bkfile"
	if [[ -e $dirsystem/order.json ]]; then
		order=$( jq '. + ["'$DIR'"]' $dirsystem/order.json )
		echo "$order" > $dirsystem/order.json
	fi
	pushstream bookmark 1
	;;
bookmarkcoverreset )
	path=$( < "$dirbookmarks/$NAME" )
	[[ ${path:0:1} != '/' ]] && path="/mnt/MPD/$path"
	rm -f "$path/coverart".*
	pushstream bookmark 1
	;;
bookmarkremove )
	bkfile="$dirbookmarks/${NAME//\//|}"
	path=$( < "$bkfile" )
	if grep -q "$path" $dirsystem/order.json 2> /dev/null; then
		order=$( jq '. - ["'$path'"]' $dirsystem/order.json )
		echo "$order" > $dirsystem/order.json
	fi
	rm "$bkfile"
	pushstream bookmark 1
	;;
bookmarkrename )
	mv $dirbookmarks/{"${NAME//\//|}","${NEWNAME//\//|}"} 
	pushstream bookmark 1
	;;
camillagui )
	systemctl start camillagui
	sed -i '/Connection reset without closing handshake/ d' /var/log/camilladsp.log
	;;
color )
	file=$dirsystem/color
	[[ $HSL == reset ]] && rm -f $file && HSL=
	if [[ $HSL ]]; then
		echo $HSL > $file
		hsl=( $HSL )
	else
		if [[ -e $file ]]; then
			hsl=( $( < $file ) )
		else
			hsl=( $( grep '\--cd *:' /srv/http/assets/css/colors.css \
						| sed 's/.*(\(.*\)).*/\1/' \
						| tr ',' ' ' \
						| tr -d % ) )
		fi
	fi
	h=${hsl[0]}; s=${hsl[1]}; l=${hsl[2]}
	hs="$h,$s%,"
	hsg="$h,3%,"
	hsl="${hs}$l%"

	sed -i -E "
 s|(--cml *: *hsl).*;|\1(${hs}$(( l + 5 ))%);|
  s|(--cm *: *hsl).*;|\1($hsl);|
 s|(--cma *: *hsl).*;|\1(${hs}$(( l - 5 ))%);|
 s|(--cmd *: *hsl).*;|\1(${hs}$(( l - 15 ))%);|
s|(--cg75 *: *hsl).*;|\1(${hsg}75%);|
s|(--cg60 *: *hsl).*;|\1(${hsg}60%);|
 s|(--cgl *: *hsl).*;|\1(${hsg}40%);|
  s|(--cg *: *hsl).*;|\1(${hsg}30%);|
 s|(--cga *: *hsl).*;|\1(${hsg}20%);|
 s|(--cgd *: *hsl).*;|\1(${hsg}10%);|
" /srv/http/assets/css/colors.css
	sed -i -E "
s|(rect.*hsl).*;|\1($hsl);|
s|(path.*hsl).*;|\1(${hsg}75%);|
" $dirimg/icon.svg
	sed -E "s|(path.*hsl).*;|\1(0,0%,90%);}|" $dirimg/icon.svg \
		| convert -density 96 -background none - $dirimg/icon.png
	rotateSplash
	sed -i -E 's/\?v=.{10}/?v='$( date +%s )'/g' /srv/http/settings/camillagui/build/index.html
	pushstream reload 1
	;;
coverartreset )
	dir=$( dirname "$COVERFILE" )
	filename=$( basename "$COVERFILE" )
	if [[ $( basename "$dir" ) == audiocd ]]; then
		discid=${filename/.*}
		rm -f "$COVERFILE"
		$dirbash/status-coverartonline.sh "cmd
$ARTIST
$ALBUM
audiocd
$discid
CMD ARTIST ALBUM TYPE DISCID" &> /dev/null &
		exit
	fi
	
	rm -f "$COVERFILE" "$dir/{coverart,thumb}".* $dirshm/{embedded,local}/*
	backupfile=$( ls -p "$dir"/*.backup | head -1 )
	if [[ -e $backupfile ]]; then
		restorefile=${backupfile:0:-7}
		mv "$backupfile" "$restorefile"
		if [[ ${restorefile: -3} != gif ]]; then
			convert "$restorefile" -thumbnail 200x200\> -unsharp 0x.5 "$dir/coverart.jpg"
			convert "$dir/coverart.jpg" -thumbnail 80x80\> -unsharp 0x.5 "$dir/thumb.jpg"
		else
			gifsicle -O3 --resize-fit 200x200 "$restorefile" > "$dir/coverart.gif"
			convert "$restorefile" -thumbnail 80x80\> -unsharp 0x.5 "$dir/thumb.jpg"
		fi
		pushstream coverart '{ "url": "'$restorefile'", "type": "coverart" }'
		exit
	fi
		url=$( $dirbash/status-coverart.sh "cmd
$ARTIST
$ALBUM
$COVERFILE
CMD ARTIST ALBUM FILE" )
	[[ ! $url ]] && url=reset
	pushstream coverart '{ "url": "'$url'", "type": "coverart" }'
	;;
coverfileslimit )
	for type in local online webradio; do
		ls -t $dirshm/$type/* 2> /dev/null \
			| tail -n +10 \
			| xargs rm -f --
	done
	;;
dabscan )
	touch $dirshm/updatingdab
	$dirbash/dab-scan.sh &> /dev/null &
	pushstream mpdupdate '{ "type": "dabradio" }'
	;;
display )
	pushstream display $( < $dirsystem/display.json )
	[[ -e $dirsystem/vumeter ]] && prevvumeter=1
	grep -q -m1 vumeter.*true $dirsystem/display.json && touch $dirsystem/vumeter && vumeter=1
	[[ $prevvumeter == $vumeter ]] && exit
	
	killProcess cava
	if [[ $vumeter ]]; then
		if [[ -e $dirmpdconf/fifo.conf ]]; then
			if statePlay; then
				cava -p /etc/cava.conf | $dirbash/vu.sh &> /dev/null &
				echo $! > $dirshm/pidcava
			fi
			exit
			
		fi
	else
		rm -f $dirsystem/vumeter $dirshm/status
	fi
	$dirsettings/player-conf.sh
	;;
equalizer )
	if [[ $VALUES ]]; then # preset ( delete, rename, new - save json only )
		freq=( 31 63 125 250 500 1 2 4 8 16 )
		v=( $VALUES )
		for (( i=0; i < 10; i++ )); do
			(( i < 5 )) && unit=Hz || unit=kHz
			band=( "0$i. ${freq[i]} $unit" )
			sudo -u $USER amixer -MqD equal sset "$band" ${v[i]}
		done
	fi
	pushstream equalizer $( < $dirsystem/equalizer.json )
	;;
equalizerget )
	cat $dirsystem/equalizer.json 2> /dev/null || echo false
	;;
equalizerset ) # slide
	sudo -u $USER amixer -MqD equal sset "$BAND" $VAL
	;;
hashreset )
	! grep -q ^.hash.*time /srv/http/common.php && sed -E -i "s/(^.hash.*v=).*/\1'.time();/" /srv/http/common.php
	;;
ignoredir )
	touch $dirmpd/updating
	dir=$( basename "$DIR" )
	mpdpath=$( dirname "$DIR" )
	echo $dir >> "/mnt/MPD/$mpdpath/.mpdignore"
	pushstream mpdupdate '{ "type": "mpd" }'
	mpc -q update "$mpdpath" #1 get .mpdignore into database
	mpc -q update "$mpdpath" #2 after .mpdignore was in database
	;;
latestclear )
	if [[ $DIR ]]; then
		sed -i "\|\^$DIR$| d" $dirmpd/latest
		count=$( wc -l < $dirmpd/latest )
		notify latest Latest 'Album cleared.'
	else
		> $dirmpd/latest
		count=0
		notify latest Latest Cleared
	fi
	sed -i -E 's/("latest": ).*/\1'$count',/' $dirmpd/counts
	;;
librandom )
	if [[ $ON ]]; then
		mpc -q random 0
		tail=$( plTail )
		if [[ $PLAY ]]; then
			playnext=$(( total + 1 ))
			(( $tail > 0 )) && mpc -q play $total && mpc -q stop
		fi
		touch $dirsystem/librandom
		plAddRandom
		[[ $PLAY ]] && mpc -q play $playnext
	else
		rm -f $dirsystem/librandom
	fi
	pushstream option '{ "librandom": '$TF' }'
	;;
lyrics )
	name="$ARTIST - $TITLE"
	name=${name//\/}
	lyricsfile="$dirlyrics/${name,,}.txt"
	if [[ $ACTION == save ]]; then
		echo -e "$DATA" > "$lyricsfile"
	elif [[ $ACTION == delete ]]; then
		rm -f "$lyricsfile"
	elif [[ -e "$lyricsfile" ]]; then
		cat "$lyricsfile"
	else
		. $dirsystem/lyrics.conf
		if [[ $embedded && $( < $dirshm/player ) == mpd ]]; then
			file=$( getVar file $dirshm/status )
			if [[ ${file/\/*} =~ ^(USB|NAS|SD)$ ]]; then
				file="/mnt/MPD/$file"
				lyrics=$( kid3-cli -c "select \"$file\"" -c "get lyrics" )
				[[ $lyrics ]] && echo "$lyrics" && exit
			fi
		fi
		
		artist=$( sed -E 's/^A |^The |\///g' <<< $ARTIST )
		title=${TITLE//\/}
		query=$( tr -d " '\-\"\!*\(\);:@&=+$,?#[]." <<< "$artist/$title" )
		lyrics=$( curl -s -A firefox $url/${query,,}.html | sed -n "/$start/,\|$end| p" )
		[[ $lyrics ]] && sed -e 's/<br>//; s/&quot;/"/g' -e '/^</ d' <<< $lyrics | tee "$lyricsfile"
	fi
	;;
mpcadd )
	plAddPosition $ACTION
	mpc -q add "$FILE"
	plAddPlay $ACTION $DELAY
	pushstreamPlaylist add
	;;
mpcaddplaynext )
	mpc -q insert "$FILE"
	pushstreamPlaylist add
	;;
mpcaddfind )
	if [[ $TYPE2 ]]; then
		plAddPosition $ACTION
		mpc -q findadd $TYPE "$STRING" $TYPE2 "$STRING2"
	else
		plAddPosition $ACTION
		mpc -q findadd $TYPE "$STRING"
	fi
	plAddPlay $ACTION $DELAY
	;;
mpcaddload )
	plAddPosition $ACTION
	mpc -q load "$FILE"
	plAddPlay $ACTION $DELAY
	;;
mpcaddls )
	plAddPosition $ACTION
	readarray -t cuefiles <<< $( mpc ls "$DIR" | grep '\.cue$' | sort -u )
	if [[ ! $cuefiles ]]; then
		mpc ls "$DIR" | mpc -q add &> /dev/null
	else
		for cuefile in "${cuefiles[@]}"; do
			mpc -q load "$cuefile"
		done
	fi
	plAddPlay $ACTION $DELAY
	;;
mpccrop )
	if statePlay; then
		mpc -q crop
	else
		mpc -q play
		mpc -q crop
		mpc -q stop
	fi
	[[ -e $dirsystem/librandom ]] && plAddRandom
	$dirbash/status-push.sh
	pushstreamPlaylist
	;;
mpclibrandom )
	plAddRandom
	;;
mpcmove )
	mpc -q move $FROM $TO
	pushstreamPlaylist
	;;
mpcoption )
	[[ ! $ONOFF ]] && ONOFF=false
	mpc -q $OPTION $ONOFF
	pushstream option '{ "'$OPTION'": '$ONOFF' }'
	;;
mpcplayback )
	if [[ ! $ACTION ]]; then
		player=$( < $dirshm/player )
		if [[ $( < $dirshm/player ) != mpd ]]; then
			$dirbash/cmd.sh playerstop
			exit
		fi
		
		if statePlay; then
			grep -q -m1 webradio=true $dirshm/status && ACTION=stop || ACTION=pause
		else
			ACTION=play
		fi
	fi
	stopRadio $ACTION
	if [[ $ACTION == play ]]; then
		[[ $( mpc status %state% ) == paused ]] && pause=1
		mpc -q $ACTION $POS
		[[ $( mpc | head -c 4 ) == cdda && ! $pause ]] && notify -blink audiocd 'Audio CD' 'Start play ...'
	else
		[[ -e $dirsystem/scrobble && $ACTION == stop ]] && cp -f $dirshm/{status,scrobble}
		mpc -q $ACTION
		killProcess cava
		[[ -e $dirshm/scrobble ]] && scrobbleOnStop
	fi
	[[ ! -e $dirsystem/snapclientserver ]] && exit
	# snapclient
	if [[ $ACTION == play ]]; then
		action=start
		active=true
		sleep 2 # fix stutter
		touch $dirshm/snapclient
	else
		action=stop
		active=false
		rm $dirshm/snapclient
	fi
	systemctl $action snapclient
	pushstream option '{ "snapclient": '$active' }'
	pushstream refresh '{ "page": "features", "snapclientactive": '$active' }'
	;;
mpcprevnext )
	current=$( mpc status %songpos% )
	length=$( mpc status %length% )
	[[ $( mpc status %state% ) == playing ]] && playing=1
	mpc -q stop
	stopRadio
	[[ -e $dirsystem/scrobble ]] && cp -f $dirshm/{status,scrobble}
	[[ ! $playing ]] && touch $dirshm/prevnextseek
	if [[ $( mpc status %random% ) == on ]]; then
		pos=$( shuf -n 1 <( seq $length | grep -v $current ) )
		mpc -q play $pos
	else
		if [[ $ACTION == next ]]; then
			(( $current != $length )) && mpc -q play $(( current + 1 )) || mpc -q play 1
			[[ $( mpc status %consume% ) == on ]] && mpc -q del $current
			[[ -e $dirsystem/librandom ]] && plAddRandom
		else
			(( $current != 1 )) && mpc -q play $(( current - 1 )) || mpc -q play $length
		fi
	fi
	if [[ $playing ]]; then
		mpc -q play
		[[ $( mpc | head -c 4 ) == cdda ]] && notify -blink audiocd 'Audio CD' 'Change track ...'
	else
		rm -f $dirshm/prevnextseek
		mpc -q stop
	fi
	if [[ -e $dirshm/scrobble ]]; then
		sleep 2
		scrobbleOnStop
	fi
	;;
mpcremove )
	if [[ $POS ]]; then
		mpc -q del $POS
		[[ $CURRENT ]] && mpc -q play $CURRENT && mpc -q stop
	else
		mpc -q clear
	fi
	$dirbash/status-push.sh
	pushstreamPlaylist
	;;
mpcseek )
	touch $dirshm/scrobble
	if [[ $STATE == stop ]]; then
		touch $dirshm/prevnextseek
		mpc -q play
		mpc -q pause
		rm $dirshm/prevnextseek
	fi
	mpc -q seek $ELAPSED
	rm -f $dirshm/scrobble
	;;
mpcsetcurrent )
	mpc -q play $POS
	mpc -q stop
	$dirbash/status-push.sh
	;;
mpcshuffle )
	mpc -q shuffle
	pushstreamPlaylist
	;;
mpcsimilar )
	readarray -t lines <<< $( curl -sfG -m 5 \
								--data-urlencode "artist=$ARTIST" \
								--data-urlencode "track=$TITLE" \
								--data "method=track.getsimilar" \
								--data "api_key=$APIKEY" \
								--data "format=json" \
								--data "autocorrect=1" \
								http://ws.audioscrobbler.com/2.0 \
									| jq .similartracks.track \
									| sed -n '/"name": "/ {s/.*": "\|",$//g; p}' )
	[[ ! $lines ]] && echo 'No similar tracks found in database.' && exit
	
	for l in "${lines[@]}"; do # title \n artist
		if [[ $title ]]; then
			file=$( mpc find artist "$l" title "$title" )
			[[ $file ]] && list+="$file"$'\n'
			title=
		else
			title=$l
		fi
	done
	[[ ! $list ]] && echo 'No similar tracks found in Library.' 5000 && exit
	
	plLprev=$( mpc status %length% )
	awk NF <<< $list | mpc -q add
	pushstreamPlaylist
	added=$(( $( mpc status %length% ) - plLprev ))
	notify lastfm 'Add Similar' "$added tracks added."
	;;
mpcupdate )
	if [[ $DIR ]]; then
		echo $DIR > $dirmpd/updating
	elif [[ -e $dirmpd/updating ]]; then
		DIR=$( < $dirmpd/updating )
	fi
	[[ $DIR == rescan ]] && mpc -q rescan || mpc -q update "$DIR"
	pushstream mpdupdate '{ "type": "mpd" }'
	;;
multiraudiolist )
	echo '{
  "current" : "'$( ipAddress )'"
, "list"    : '$( < $dirsystem/multiraudio.json )'
}'
	;;
order )
	pushstream order $( < $dirsystem/order.json )
	;;
playerstart )
	player=$( < $dirshm/player )
	mpc -q stop
	stopRadio
	case $player in
		airplay )   service=shairport-sync;;
		bluetooth ) service=bluetoothhd;;
		spotify )   service=spotifyd;;
		upnp )      service=upmpdcli;;
	esac
	for pid in $( pgrep $service ); do
		ionice -c 0 -n 0 -p $pid &> /dev/null 
		renice -n -19 -p $pid &> /dev/null
	done
	pushstream player '{ "player": "'$player'", "active": true }'
	;;
playerstop )
	player=$( < $dirshm/player )
	if [[ -e $dirsystem/scrobble ]] && grep -q $player=true $dirsystem/scrobble.conf; then
		scrobble=1
		cp -f $dirshm/{status,scrobble}
	fi
	killProcess cava
	echo mpd > $dirshm/player
	[[ $player != upnp ]] && $dirbash/status-push.sh
	case $player in
		airplay )
			systemctl stop shairport
			rm -f $dirshm/airplay/start
			systemctl restart shairport-sync
			;;
		bluetooth )
			rm -f $dirshm/bluetoothdest
			systemctl restart bluetooth
			;;
		snapcast )
			$dirbash/snapcast.sh stop
			;;
		spotify )
			rm -f $dirshm/spotify/start
			systemctl restart spotifyd
			;;
		upnp )
			mpc -q stop
			tracks=$( mpc -f %file%^%position% playlist | grep 'http://192' | cut -d^ -f2 )
			for i in $tracks; do
				mpc -q del $i
			done
			$dirbash/status-push.sh
			systemctl restart upmpdcli
			;;
	esac
	pushstream player '{ "player": "'$player'", "active": false }'
	[[ $scrobble ]] && scrobbleOnStop
	;;
playlist )
	[[ $REPLACE ]] && mpc -q clear
	mpc -q load "$NAME"
	[[ $PLAY ]] && sleep 1 && mpc -q play
	[[ $PLAY || $REPLACE ]] && $dirbash/push-status.sh
	pushstreamPlaylist
	;;
radiorestart )
	[[ -e $disshm/radiorestart ]] && exit
	
	touch $disshm/radiorestart
	systemctl -q is-active radio || systemctl start radio
	sleep 1
	rm $disshm/radiorestart
	;;
relaystimerreset )
	$dirbash/relays-timer.sh &> /dev/null &
	pushstream relays '{ "done": 1 }'
	;;
rotatesplash )
	rotateSplash
	;;
savedpldelete )
	rm "$dirplaylists/$NAME.m3u"
	count=$( ls -1 $dirplaylists | wc -l )
	sed -i -E 's/(.*playlists": ).*/\1'$count',/' $dirmpd/counts
	pushstreamSavedPlaylist
	;;
savedpledit ) # $DATA: remove - file, add - position-file, move - from-to
	plfile="$dirplaylists/$NAME.m3u"
	if [[ $TYPE == remove ]]; then
		sed -i "$POS d" "$plfile"
	elif [[ $TYPE == add ]]; then
		[[ $TO == last ]] && echo $FILE >> "$plfile" || sed -i "$TO i$FILE" "$plfile"
	else # move
		file=$( sed -n "$FROM p" "$plfile" )
		[[ $FROM < $TO ]] && (( TO++ ))
		sed -i -e "$FROM d" -e "$TO i$file" "$plfile"
	fi
	pushstreamSavedPlaylist
	;;
savedplrename )
	plfile="$dirplaylists/$NEWNAME.m3u"
	if [[ $REPLACE ]]; then
		rm -f "$plfile"
	elif [[ -e "$plfile" ]]; then
		echo -1
		exit
	fi
	
	mv "$dirplaylists/$NAME.m3u" "$plfile"
	pushstreamSavedPlaylist
	;;
savedplsave )
	plfile="$dirplaylists/$NAME.m3u"
	if [[ $REPLACE ]]; then
		rm -f "$plfile"
	elif [[ -e "$plfile" ]]; then
		echo -1
		exit
	fi
	
	mpc -q save "$NAME"
	chmod 777 "$plfile"
	count=$( ls -1 $dirplaylists | wc -l )
	sed -E -i 's/(,*)(.*playlists" *: ).*(,)/\1\2'$count'\3/' $dirmpd/counts
	pushstreamSavedPlaylist
	;;
screenoff )
	DISPLAY=:0 xset dpms force off
	;;
shairport )
	[[ $( < $dirshm/player ) != airplay ]] && echo airplay > $dirshm/player && $dirbash/cmd.sh playerstart
	systemctl start shairport
	echo play > $dirshm/airplay/state
	$dirbash/status-push.sh
	;;
shairportstop )
	systemctl stop shairport
	echo pause > $dirshm/airplay/state
	[[ -e $dirshm/airplay/start ]] && start=$( < $dirshm/airplay/start ) || start=0
	timestamp=$( date +%s%3N )
	echo $(( timestamp - start - 7500 )) > $dirshm/airplay/elapsed # delayed 7s
	$dirbash/status-push.sh
	;;
shareddatampdupdate )
	systemctl restart mpd
	notify refresh-library 'Library Update' Done
	status=$( $dirbash/status.sh )
	pushstream mpdplayer "$status"
	;;
titlewithparen )
	! grep -q "$TITLE" /srv/http/assets/data/titles_with_paren && echo -1
	;;
volume ) # no TARGET = toggle mute / unmute
	[[ $CURRENT == drag ]] && volumeSetAt $TARGET "$CONTROL" $CARD && exit
	
	[[ ! $CURRENT ]] && CURRENT=$( volumeGet value )
	filevolumemute=$dirsystem/volumemute
	if [[ $TARGET > 0 ]]; then      # set
		rm -f $filevolumemute
		pushstreamVolume set $TARGET
	else
		if (( $CURRENT > 0 )); then # mute
			TARGET=0
			echo $CURRENT > $filevolumemute
			pushstreamVolume mute $CURRENT
		else                        # unmute
			TARGET=$( < $filevolumemute )
			rm -f $filevolumemute
			pushstreamVolume unmute $TARGET
		fi
	fi
	volumeSet $CURRENT $TARGET "$CONTROL" $CARD
	;;
volumeget )
	volumeGet value
	;;
volumepushstream )
	volumeGet push
	;;
volumeupdn )
	volumeUpDn 1%$UPDN "$CONTROL" $CARD
	;;
volumeupdnbt )
	volumeUpDnBt 1%$UPDN "$CONTROL"
	;;
volumeupdnmpc )
	volumeUpDnMpc ${updn}1
	;;
webradioadd )
	url=$( urldecode $URL )
	urlname=${url//\//|}
	ext=${url/*.}
	[[ $ext == m3u || $ext == pls ]] && webradioPlaylistVerify $ext $url
	
	file=$dirwebradio
	[[ $DIR ]] && file+="/$DIR"
	file+="/$urlname"
	[[ -e $file ]] && echo 'Already exists as <wh>'$( head -1 "$file" )'</wh>:' && exit
	echo "\
$NAME

$CHARSET" > "$file"
	chown http:http "$file" # for edit in php
	webradioCount
	webRadioSampling $url "$file" &> /dev/null &
	;;
webradiocoverreset )
	rm "$FILENOEXT".* "$FILENOEXT-thumb".*
	pushstream coverart '{ "url": "", "type": "'$MODE'" }'
	;;
webradiodelete )
	urlname=${URL//\//|}
	path=$dirdata/$MODE
	[[ $DIR ]] && path+="/$DIR"
	rm -f "$path/$urlname"
	[[ ! $( find "$path" -name "$urlname" ) ]] && rm -f "$path/img/{$urlname,$urlname-thumb}".*
	webradioCount $MODE
	;;
webradioedit )
	newurlname=${NEWURL//\//|}
	urlname=${URL//\//|}
	path=$dirwebradio/
	[[ $DIR ]] && path+="/$DIR"
	newfile="$path/$newurlname"
	prevfile="$path/$urlname"
	if [[ $NEWURL == $URL ]]; then
		sampling=$( sed -n 2p "$prevfile" )
	else
		[[ -e $newfile ]] && echo 'URL exists:' && exit
		
		ext=${NEWURL##*.}
		[[ $ext == m3u || $ext == pls ]] && webradioPlaylistVerify $ext $NEWURL
		
		rm "$prevfile"
		# stationcover
		imgurl="$dirwebradio/img/$urlname"
		img=$( ls -1 "$imgurl".* | head -1 )
		thumb="$imgurl-thumb.jpg"
		if [[ $img || -e $thumb ]]; then
			newimgurl="$dirwebradio/img/$newurlname"
			newimg="$newimgurl.${img##*.}"
			newthumb="$newimgurl-thumb.jpg"
			[[ ! -e $newimg && -e $img ]] && cp "$img" "$newimg"
			[[ ! -e $newthumb && -e $thumb ]] && cp "$thumb" "$newthumb"
			[[ ! $( find $dirwebradio -name "$urlname" ) ]] && rm -f "$imgurl".* "$thumb"
		fi
	fi
	echo "\
$NAME
$sampling
$CHARSET" > "$newfile"
	pushstreamRadioList
	;;
wrdirdelete )
	file="$dirdata/$MODE/$NAME"
	[[ ! $CONFIRM && $( ls -A "$file" ) ]] && echo -1 && exit
	
	rm -rf "$file"
	pushstreamRadioList
	;;
wrdirnew )
	[[ $DIR ]] && mkdir -p "$dirwebradio/$DIR/$SUB" || mkdir -p "$dirwebradio/$SUB"
	pushstreamRadioList
	;;
wrdirrename )
	mv -f "$dirdata/$MODE/{$NAME,$NEWNAME}"
	pushstreamRadioList
	;;
	
esac
