#!/bin/bash

. /srv/http/bash/common.sh

BASE_YML="$dirbash/dab/rtsp-simple-server.yml"
NEW_YML="/etc/rtsp-simple-server/rtsp-simple-server.yml"
MYNAME=$( hostname -f )

#Create DAB subdir if not existing 
mkdir -p $dirwebradios/DAB

#this is needed to consider the lowercase accented chars outside of "alnum"
LC_CTYPE=C

trim() {
	local var="$*"
	var="${var%"${var##*[![:space:]]}"}"   
	printf '%s' "$var"
}

cp $BASE_YML $NEW_YML
rm -f $dirwebradios/DAB/rtsp\:\|\|$MYNAME\:8554*
rm -f ${dirwebradios}img/rtsp\:\|\|$MYNAME\:8554*

dabscan=$( dab-scanner-rtlsdr -C 5A )
services=$( echo "$dabscan" | grep ^audioservice )
if [[ ! $services ]]; then
	pushstreamNotify 'DAB Radio' 'No stations found.' dab
	rm $dirshm/updatingdab
	exit
fi

readarray -t services <<< "$services"
for service in "${services[@]}"; do
	if grep -q "^audioservice" <<< $service; then
		readarray -d ';' -t field <<< $service
		service_name=$(trim "${field[1]}")
		service_chan=$(trim "${field[2]}")
		service_id=$(trim "${field[3]}")
		legal_nameU=${service_name//[^[:alnum:]]/_}
		#rtsp simple server does not like all uppercase service names neither all numbers names
		legal_name=${legal_nameU,,}
		if [ "$legal_name" -eq "$legal_name" ] 2>/dev/null; then
		 legal_name=R${legal_name}
		fi
		#echo "$service_name" legale $legal_name su canale "$service_chan"
		#add services to rtsp daemon config file      
		#    "runOnDemand: dab-rtlsdr-3 -P \""$service_name"\" -C "$service_chan'|ffmpeg -re -ar 48000 -ac 2 -f s16le  -i - -vn -c:a mp3 -f rtsp rtsp://localhost:$RTSP_PORT/$RTSP_PATH'
		#    runOnDemand: dab-rtlsdr-3 -P "$service_name" -C $service_chan|ffmpeg -re -ar 48000 -ac 2 -f s16le  -i - -vn -c:a aac -b:a 160k -f rtsp rtsp://localhost:\$RTSP_PORT/\$RTSP_PATH

		cat <<EOT >>$NEW_YML
  $legal_name:
    runOnDemand: /srv/http/bash/dab/dabstart.sh $service_id $service_chan  \$RTSP_PORT \$RTSP_PATH
    runOnDemandRestart: yes
    runOnDemandStartTimeout: 15s
    runOnDemandCloseAfter: 3s
EOT

		echo "$service_name" > $dirwebradios/DAB/rtsp\:\|\|${MYNAME}\:8554\|$legal_name
		ln -s ${dirwebradios}img/{dablogo,rtsp\:\|\|$MYNAME\:8554\|$legal_name}.jpg
		ln -s ${dirwebradios}img/dablogo-thumb,rtsp\:\|\|$MYNAME\:8554\|$legal_name-thumb}.jpg

		#echo fatto per $legal_name
	fi
done
#updates webradios count
chown -R http:http $dirwebradios*
count=$( find -L $dirwebradios -type f | wc -l )
sed -i 's/\("webradio": \).*/\1'$count'/' $dirmpd/counts
# refresh count on web page
pushstream webradio $count

rm $dirshm/updatingdab
