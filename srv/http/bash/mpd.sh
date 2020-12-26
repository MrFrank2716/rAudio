#!/bin/bash

dirsystem=/srv/http/data/system

# convert each line to each args
readarray -t args <<< "$1"

pushRefresh() {
	curl -s -X POST http://127.0.0.1/pub?id=refresh -d '{ "page": "mpd" }'
}
restartMPD() {
	/srv/http/bash/mpd-conf.sh
}

case ${args[0]} in

amixer )
	card=$( head -1 /etc/asound.conf | cut -d' ' -f2 )
	aplayname=$( aplay -l | grep "^card $card" | awk -F'[][]' '{print $2}' )
	if [[ $aplayname != snd_rpi_wsp ]]; then
		amixer -c $card scontents \
			| grep -A1 ^Simple \
			| sed 's/^\s*Cap.*: /^/' \
			| tr -d '\n' \
			| sed 's/--/\n/g' \
			| grep pvolume \
			| cut -d^ -f1
	else
		echo "\
Simple mixer control 'Speaker Digital',0
Simple mixer control 'HPOUT1 Digital',0
Simple mixer control 'HPOUT2 Digital',0
Simple mixer control 'SPDIF Out',0\
"
	fi
	;;
audiooutput )
	aplayname=${args[1]}
	card=${args[2]}
	output=${args[3]}
	mixer=${args[4]}
	sed -i "s/.$/$card/" /etc/asound.conf
	if [[ $aplayname == rpi-cirrus-wm5102 ]]; then
		output=$( cat $dirsystem/hwmixer-rpi-cirrus-wm5102 2> /dev/null || echo HPOUT2 Digital )
		/srv/http/bash/mpd-wm5102.sh $card $output
	fi
	sed -i -e '/output_device = / s/".*"/"hw:'$card'"/
	' -e '/mixer_control_name = / s/".*"/"'$mixer'"/
	' /etc/shairport-sync.conf
	systemctl try-restart shairport-sync shairport-meta
	pushRefresh
	;;
autoupdate )
	if [[ ${args[1]} == true ]]; then
		sed -i '1 i\auto_update            "yes"' /etc/mpd.conf
	else
		sed -i '/^auto_update/ d' /etc/mpd.conf
	fi
	restartMPD
	;;
bufferdisable )
	sed -i '/^audio_buffer_size/ d' /etc/mpd.conf
	restartMPD
	;;
bufferset )
	buffer=${args[1]}
	sed -i '/^audio_buffer_size/ d' /etc/mpd.conf
	sed -i '1 i\audio_buffer_size      "'$buffer'"' /etc/mpd.conf
	echo $buffer > $dirsystem/bufferset
	restartMPD
	;;
bufferoutputdisable )
	sed -i '/^max_output_buffer_size/ d' /etc/mpd.conf
	restartMPD
	;;
bufferoutputset )
	buffer=${args[1]}
	sed -i '/^max_output_buffer_size/ d' /etc/mpd.conf
	sed -i '1 i\max_output_buffer_size "'$buffer'"' /etc/mpd.conf
	echo $buffer > $dirsystem/bufferoutputset
	restartMPD
	;;
count )
	albumartist=$( mpc list albumartist | awk NF | wc -l )
	composer=$( mpc list composer | awk NF | wc -l )
	genre=$( mpc list genre | awk NF | wc -l )
	count="$count $( mpc stats | head -n3 | awk '{print $2,$4,$6}' )"

	data='
		  "album"       : '$( echo $count | cut -d' ' -f2 )'
		, "albumartist" : '$albumartist'
		, "artist"      : '$( echo $count | cut -d' ' -f1 )'
		, "composer"    : '$composer'
		, "coverart"    : '$( ls -1q /srv/http/data/coverarts | wc -l )'
		, "date"        : '$( mpc list date | awk NF | wc -l )'
		, "genre"       : '$genre'
		, "nas"         : '$( mpc ls NAS 2> /dev/null | wc -l )'
		, "sd"          : '$( mpc ls SD 2> /dev/null | wc -l )'
		, "song"        : '$( echo $count | cut -d' ' -f3 )'
		, "usb"         : '$( mpc ls USB 2> /dev/null | wc -l )'
		, "webradio"    : '$( ls -U /srv/http/data/webradios/* 2> /dev/null | wc -l )
	mpc | grep -q Updating && data+=', "updating_db":1'
	echo {$data}
	echo $albumartist $composer $genre > /srv/http/data/system/mpddb
	;;
crossfadedisable )
	mpc crossfade 0
	pushRefresh
	;;
crossfadeset )
	crossfade=${args[1]}
	mpc crossfade $crossfade
	echo $crossfade > $dirsystem/crossfadeset
	touch $dirsystem/crossfade
	pushRefresh
	;;
customdisable )
	sed -i '/ #custom$/ d' /etc/mpd.conf
	rm -f $dirsystem/custom
	restartMPD
	;;
customgetglobal )
	cat $dirsystem/custom-global
	;;
customgetoutput )
	cat "$dirsystem/custom-output-${args[1]}"
	;;
customset )
	file=$dirsystem/custom
	if [[ ${args[1]} == customset ]]; then
		global=$( cat $file-global 2> /dev/null )
		[[ -n $global ]] && touch $file
	else
		global=${args[1]}
		output=${args[2]}
		aplayname=${args[3]}
		[[ -n $global ]] && echo "$global" > $file-global || rm -f $file-global
		[[ -n $output ]] && echo "$output" > "$file-output-$aplayname" || rm -f "$file-output-$aplayname"
		[[ -n $global || -n $output ]] && touch $file
	fi
	sed -i '/ #custom$/ d' /etc/mpd.conf
	if [[ -n $global ]]; then
		global=$( echo "$global" | tr ^ '\n' | sed 's/$/ #custom/' )
		sed -i "/^user/ a$global" /etc/mpd.conf
	fi
	restartMPD
	;;
dop )
	dop=${args[1]}
	aplayname=${args[2]}
	if [[ $dop == true ]]; then
		touch "$dirsystem/dop-$aplayname"
	else
		rm -f "$dirsystem/dop-$aplayname"
	fi
	restartMPD
	;;
ffmpeg )
	if [[ ${args[1]} == true ]]; then
		sed -i '/ffmpeg/ {n; s/".*"/"yes"/}' /etc/mpd.conf
	else
		sed -i '/ffmpeg/ {n; s/".*"/"no"/}' /etc/mpd.conf
	fi
	restartMPD
	;;
filetype )
	type=$( mpd -V | grep '\[ffmpeg' | sed 's/.*ffmpeg. //; s/ rtp.*//' | tr ' ' '\n' | sort )
	for i in {a..z}; do
		line=$( grep ^$i <<<"$type" | tr '\n' ' ' )
		[[ -n $line ]] && list+=${line:0:-1}'<br>'
	done
	echo "${list:0:-4}"
	;;
hwmixer )
	aplayname=${args[1]}
	hwmixer=${args[2]}
	if [[ $hwmixer == auto ]]; then
		hwmixer=$( amixer scontents \
						| grep -A1 ^Simple \
						| sed 's/^\s*Cap.*: /^/' \
						| tr -d '\n' \
						| sed 's/--/\n/g' \
						| grep pvolume \
						| sed 's/Simple.*control \(.*\)\^.*/\1/' \
						| sed "s/'\|,0$//g" \
						| head -1 )
		rm -f "/srv/http/data/system/hwmixer-$aplayname"
	else
		echo $hwmixer > "/srv/http/data/system/hwmixer-$aplayname"
	fi
	sed -i '/mixer_control_name = / s/".*"/"'$hwmixer'"/' /etc/shairport-sync.conf
	if [[ $aplayname == rpi-cirrus-wm5102 ]]; then
		card=$( head -1 /etc/asound.conf | cut -d' ' -f2 )
		/srv/http/bash/mpd-wm5102.sh $card $hwmixer
	fi
	systemctl try-restart shairport-sync shairport-meta
	restartMPD
	;;
mixerset )
	mixer=${args[1]}
	aplayname=${args[2]}
	card=${args[3]}
	control=${args[4]}
	if [[ $mixer == hardware ]]; then
		rm -f "$dirsystem/mixertype-$aplayname"
	else
		echo $mixer > "$dirsystem/mixertype-$aplayname"
	fi
	restartMPD
	curl -s -X POST http://127.0.0.1/pub?id=display -d '{ "volumenone": '$( [[ $mixer == none ]] && echo true || echo false )' }'
	;;
normalization )
	if [[ ${args[1]} == true ]]; then
		sed -i '/^user/ a\volume_normalization   "yes"' /etc/mpd.conf
	else
		sed -i '/^volume_normalization/ d' /etc/mpd.conf
	fi
	restartMPD
	;;
novolume )
	name=${args[1]}
	card=${args[2]}
	hwmixer=${args[3]}
	sed -i -e '/volume_normalization/ d
	' -e '/^replaygain/ s/".*"/"off"/
	' /etc/mpd.conf
	mpc crossfade 0
	echo none > "$dirsystem/mixertype-$name"
	rm -f $dirsystem/{crossfade,replaygain,normalization}
	restartMPD
	curl -s -X POST http://127.0.0.1/pub?id=display -d '{ "volumenone": true }'
	;;
replaygaindisable )
	sed -i '/^replaygain/ s/".*"/"off"/' /etc/mpd.conf
	restartMPD
	;;
replaygainset )
	replaygain=${args[1]}
	sed -i '/^replaygain/ s/".*"/"'$replaygain'"/' /etc/mpd.conf
	echo $replaygain > $dirsystem/replaygainset
	restartMPD
	;;
restart )
	restartMPD
	;;
soxrdisable )
	sed -i -e '/quality/,/}/ d
' -e '/soxr/ a\
	quality        "very high"\
}
' /etc/mpd.conf
	rm -f $dirsystem/soxr
	restartMPD
	;;
soxrset )
	val=( ${args[1]} )
	echo '	quality        "custom"
	precision      "'${val[0]}'"
	phase_response "'${val[1]}'"
	passband_end   "'${val[2]}'"
	stopband_begin "'${val[3]}'"
	attenuation    "'${val[4]}'"
	flags          "'${val[5]}'"
}' > $dirsystem/soxrset
	sed -i -e '/quality/,/}/ d
' -e "/soxr/ r $dirsystem/soxrset
" /etc/mpd.conf
	touch $dirsystem/soxr
	restartMPD
	;;

esac
