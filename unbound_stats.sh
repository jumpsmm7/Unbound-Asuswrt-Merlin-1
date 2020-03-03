#!/bin/sh
##
# ____ ___     ___.                            .___   _________ __          __          
#|    |   \____\_ |__   ____  __ __  ____    __| _/  /   _____//  |______ _/  |_  ______
#|    |   /    \| __ \ /  _ \|  |  \/    \  / __ |   \_____  \\   __\__  \\   __\/  ___/
#|    |  /   |  \ \_\ (  <_> )  |  /   |  \/ /_/ |   /        \|  |  / __ \|  |  \___ \ 
#|______/|___|  /___  /\____/|____/|___|  /\____ |  /_______  /|__| (____  /__| /____  >
#             \/    \/                  \/      \/          \/           \/          \/ 
## by @juched v1.0.1
## with credit to @JackYaz for his shared scripts
## V1.0.0 - initial text based only UI items
## v1.1.0 - March 3 2020 - Added graphs for histogram and answers, fixed install to not create duplicate tabs

#define www script names
readonly SCRIPT_WEBPAGE_DIR="$(readlink /www/user)"
readonly SCRIPT_NAME="Unbound_Stats.sh"
readonly SCRIPT_NAME_LOWER="unbound_stats.sh"
readonly SCRIPT_WEB_DIR="$SCRIPT_WEBPAGE_DIR/$SCRIPT_NAME_LOWER"
readonly SCRIPT_VERSION="v1.0.0"
readonly SCRIPT_DIR="/jffs/addons/unbound"

#define needed commands
readonly UNBOUNCTRLCMD="unbound-control"

#define data file names
raw_statsFile="/tmp/unbound_raw_stats.txt"
statsFile="$SCRIPT_WEB_DIR/unboundstats.txt"
statsTitleFile="$SCRIPT_WEB_DIR/unboundstatstitle.txt"
statsFileJS="$SCRIPT_WEB_DIR/unboundstats.js"
statsTitleFileJS="$SCRIPT_WEB_DIR/unboundstatstitle.js"
statsCHPFileJS="$SCRIPT_WEB_DIR/unboundchpstats.js"
statsHistogramFileJS="$SCRIPT_WEB_DIR/unboundhistogramstats.js"
statsAnswersFileJS="$SCRIPT_WEB_DIR/unboundanswersstats.js"
adblockStatsFile="/opt/var/lib/unbound/adblock/stats.txt"

#save md5 of last installed www ASP file so you can find it again later (in case of www ASP update)
installedMD5File="$SCRIPT_DIR/www-installed.md5"

#get sqlite path
[ -f /opt/bin/sqlite3 ] && SQLITE3_PATH=/opt/bin/sqlite3 || SQLITE3_PATH=/usr/sbin/sqlite3

#function to create JS file with data
WriteStats_ToJS(){
	[ -f $2 ] && rm -f "$2"
	echo "function $3(){" >> "$2"
	html='document.getElementById("'"$4"'").innerHTML="'
	while IFS='' read -r line || [ -n "$line" ]; do
		html="$html""$line""\\r\\n"
	done < "$1"
	html="$html"'"'
	printf "%s\\r\\n}\\r\\n" "$html" >> "$2"
}

WriteData_ToJS(){
	{
	echo "var $3;"
	echo "$3 = [];"; } >> "$2"
	contents="$3"'.unshift('
	while IFS='' read -r line || [ -n "$line" ]; do
		if echo "$line" | grep -q "NaN"; then continue; fi
		datapoint="{ x: moment.unix(""$(echo "$line" | awk 'BEGIN{FS=","}{ print $1 }' | awk '{$1=$1};1')""), y: ""$(echo "$line" | awk 'BEGIN{FS=","}{ print $2 }' | awk '{$1=$1};1')"" }"
		contents="$contents""$datapoint"","
	done < "$1"
	contents=$(echo "$contents" | sed 's/.$//')
	contents="$contents"");"
	printf "%s\\r\\n\\r\\n" "$contents" >> "$2"
}

#$1varible name $2 filename $3 rawStatsFile $4 on fields to add
WriteUnboundStats_ToJS(){
	outputvar="$1"
	inputfile="$3"
	outputfile="$2"
	outputlist=""
	shift;shift;shift
	for var in "$@"; do
		item="$(awk -v pat="$var=" 'BEGIN {FS="[= ]"}$0 ~ pat {print $2}' $inputfile)"
		if [ -z "$outputlist" ]; then
			outputlist=$item
		else
			outputlist=$outputlist", "$item
		fi
	done

	{ echo "var $outputvar;"
		echo "$outputvar = [];"
		echo "${outputvar}.unshift($outputlist);"
		echo; } >> "$outputfile"
}

#$1varible name $2 filename $3 on fields to add
WriteUnboundLabels_ToJS(){
	outputvar="$1"
	outputfile="$2"
	outputlist=""
	shift;shift
	for var in "$@"; do
		if [ -z "$outputlist" ]; then
			outputlist=\"$var\"
		else
			outputlist=$outputlist", "\"$var\"
		fi
	done

	{ echo "var $outputvar;"
		echo "$outputvar = [];"
		echo "${outputvar}.unshift($outputlist);"
		echo; } >> "$outputfile"
}


#$1 fieldname $2 tablename $3 frequency (hours) $4 length (days) $5 outputfile $6 sqlfile
WriteSql_ToFile(){
	{
		echo ".mode csv"
		echo ".output $5"
	} >> "$6"
	COUNTER=0
	timenow="$(date '+%s')"
	until [ $COUNTER -gt "$((24*$4/$3))" ]; do
		echo "select $timenow - ((60*60*$3)*($COUNTER)),IFNULL(avg([$1]),'NaN') from $2 WHERE ([Timestamp] >= $timenow - ((60*60*$3)*($COUNTER+1))) AND ([Timestamp] <= $timenow - ((60*60*$3)*$COUNTER));" >> "$6"
		COUNTER=$((COUNTER + 1))
	done
}

Generate_UnboundStats () {
	#generate stats to raw file
	printf "$(unbound-control stats_noreset)" > $raw_statsFile
	
	#generate header
	LINE=" --------------------------------------------------------\\n"
	printf "\\n Standard Statistics\\n$LINE" >${statsFile}
	
	#output text stats for box
	UNB_NUM_Q="$(awk 'BEGIN {FS="[= ]"} /total.num.queries=/ {print $2}' $raw_statsFile )"
	UNB_NUM_CH="$(awk 'BEGIN {FS="[= ]"} /total.num.cachehits=/ {print $2}' $raw_statsFile )"
	printf "\\n Number of DNS queries: %s" "$UNB_NUM_Q" >> $statsFile
	printf "\\n Number of queries that were successfully answerd using cache lookup (ie. cache hit): %s" "$UNB_NUM_CH" >> $statsFile
	printf "$(awk 'BEGIN {FS="[= ]"} /total.num.cachemiss=/ {print "\\n Number of queries that needed recursive lookup (ie. cache miss): " $2}' $raw_statsFile )" >> $statsFile
	printf "$(awk 'BEGIN {FS="[= ]"} /total.num.zero_ttl=/ {print "\\n Number of replies that were served by an expired cache entry: " $2}' $raw_statsFile )" >> $statsFile
	printf "$(awk 'BEGIN {FS="[= ]"} /total.requestlist.exceeded=/ {print "\\n Number of queries dropped because request list was full: " $2}' $raw_statsFile )" >> $statsFile
	printf "$(awk 'BEGIN {FS="[= ]"} /total.requestlist.avg=/ {print "\\n Average number of requests in list for recursive processing: " $2}' $raw_statsFile )" >> $statsFile
	
	#extended stats
	if [ "$($UNBOUNCTRLCMD get_option extended-statistics)" == "yes" ];then 
		printf "\\n\\n Extended Statistics\\n$LINE" >> $statsFile
		printf "$(awk 'BEGIN {FS="[= ]"} /mem.cache.rrset=/ {print "\\n RRset cache usage in bytes: " $2}' $raw_statsFile )" >> $statsFile
		printf "$(awk 'BEGIN {FS="[= ]"} /mem.cache.message=/ {print "\\n Message cache usage in bytes: " $2}' $raw_statsFile )" >> $statsFile
 	fi

	#adblock stats
	if [ -f /opt/var/lib/unbound/adblock/adservers ] && [ -f $adblockStatsFile ]; then
		printf "\\n\\n Adblock Statistics\\n$LINE" >> $statsFile
		printf "$(cat $adblockStatsFile )" >> $statsFile
	fi
	
	#calc % served by cache
	UNB_CHP="$(awk 'BEGIN {printf "%0.2f", '$UNB_NUM_CH'*100/'$UNB_NUM_Q'}' )"
	echo "Calculated Cache Hit Percentage: $UNB_CHP"
	printf "$(awk 'BEGIN {printf "\\n\\n Cache hit success percent: %s", '$UNB_CHP'}' )" >> $statsFile
	
	#create JS file to be loaded by web page
	WriteStats_ToJS "$statsFile" "$statsFileJS" "SetUnboundStats" "unboundstats"
	
	echo "Unbound Stats generated on $(date +"%c")" > $statsTitleFile
	WriteStats_ToJS "$statsTitleFile" "$statsTitleFileJS" "SetUnboundStatsTitle" "unboundstatstitle"

	#use SQLite to track % for graph
	echo "Adding new value to DB..."
	{
		echo "CREATE TABLE IF NOT EXISTS [unboundstats] ([StatID] INTEGER PRIMARY KEY NOT NULL, [Timestamp] NUMERIC NOT NULL, [CacheHitPercent] REAL NOT NULL);"
		echo "INSERT INTO unboundstats ([Timestamp],[CacheHitPercent]) values($(date '+%s'),$UNB_CHP);"
	} > /tmp/unbound-stats.sql
	
	"$SQLITE3_PATH" "$SCRIPT_DIR/unboundstats.db" < /tmp/unbound-stats.sql

	echo "Calculating Daily data..."
	{
		echo ".mode csv"
		echo ".output /tmp/unbound-chp-daily.csv"
		echo "select [Timestamp],[CacheHitPercent] from unboundstats WHERE [Timestamp] >= (strftime('%s','now') - 86400);"
	} > /tmp/unbound-stats.sql
	
	"$SQLITE3_PATH" "$SCRIPT_DIR/unboundstats.db" < /tmp/unbound-stats.sql
	rm -f /tmp/unbound-stats.sql

	echo "Calculating Weekly and Monthly data..."
	WriteSql_ToFile "CacheHitPercent" "unboundstats" 1 7 "/tmp/unbound-chp-weekly.csv" "/tmp/unbound-stats.sql"
	WriteSql_ToFile "CacheHitPercent" "unboundstats" 3 30 "/tmp/unbound-chp-monthly.csv" "/tmp/unbound-stats.sql"
	
	"$SQLITE3_PATH" "$SCRIPT_DIR/unboundstats.db" < /tmp/unbound-stats.sql
	
	rm -f "$statsCHPFileJS"
	WriteData_ToJS "/tmp/unbound-chp-daily.csv" "$statsCHPFileJS" "DatadivLineChartCacheHitPercentDaily"
	WriteData_ToJS "/tmp/unbound-chp-weekly.csv" "$statsCHPFileJS" "DatadivLineChartCacheHitPercentWeekly"
	WriteData_ToJS "/tmp/unbound-chp-monthly.csv" "$statsCHPFileJS" "DatadivLineChartCacheHitPercentMonthly"

	#generate data for histogram on performance
	echo "Outputting histogram performance data..."
	[ -f $statsHistogramFileJS ] && rm -f $statsHistogramFileJS
	WriteUnboundStats_ToJS "barDataHistogram" $statsHistogramFileJS $raw_statsFile "histogram.000000.000000.to.000000.000001" "histogram.000000.000001.to.000000.000002" "histogram.000000.000002.to.000000.000004" "histogram.000000.000004.to.000000.000008" "histogram.000000.000008.to.000000.000016" "histogram.000000.000016.to.000000.000032" "histogram.000000.000032.to.000000.000064" "histogram.000000.000064.to.000000.000128" "histogram.000000.000128.to.000000.000256" "histogram.000000.000256.to.000000.000512" "histogram.000000.000512.to.000000.001024" "histogram.000000.001024.to.000000.002048" "histogram.000000.002048.to.000000.004096" "histogram.000000.004096.to.000000.008192" "histogram.000000.008192.to.000000.016384" "histogram.000000.016384.to.000000.032768" "histogram.000000.032768.to.000000.065536" "histogram.000000.065536.to.000000.131072" "histogram.000000.131072.to.000000.262144" "histogram.000000.262144.to.000000.524288" "histogram.000000.524288.to.000001.000000" "histogram.000001.000000.to.000002.000000" "histogram.000002.000000.to.000004.000000" "histogram.000004.000000.to.000008.000000" "histogram.000008.000000.to.000016.000000" "histogram.000016.000000.to.000032.000000" "histogram.000032.000000.to.000064.000000" "histogram.000064.000000.to.000128.000000" "histogram.000128.000000.to.000256.000000" "histogram.000256.000000.to.000512.000000" "histogram.000512.000000.to.001024.000000" "histogram.001024.000000.to.002048.000000" "histogram.002048.000000.to.004096.000000" "histogram.004096.000000.to.008192.000000" "histogram.008192.000000.to.016384.000000" "histogram.016384.000000.to.032768.000000" "histogram.032768.000000.to.065536.000000" "histogram.065536.000000.to.131072.000000" "histogram.131072.000000.to.262144.000000" "histogram.262144.000000.to.524288.000000"
	WriteUnboundLabels_ToJS "barLabelsHistogram" $statsHistogramFileJS "0us - 1us" "1us - 2us" "2us - 4us" "4us - 8us" "8us - 16us" "16us - 32us" "32us - 64us" "64us - 128us" "128us - 256us" "256us - 512us" "512us - 1ms" "1ms - 2ms" "2ms - 4ms" "4ms - 8ms" "8ms - 16ms" "16ms - 32ms" "32ms - 65ms" "65ms - 131ms" "131ms - 262ms" "262ms - 524ms" "524ms - 1s" "1s - 2s" "2s - 4s" "4s - 8s" "8s - 16s" "16s - 32s" "32s - 1m" "1m - 2m" "2m - 4m" "4m - 8.5m" "8.5m - 17m" "17m - 34m" "34m - 1h" "1h - 2.3h" "2.3h - 4.5h" "4.5h - 9.1h" "9.1h - 18.2h" "18.2h - 36.4h" "36.4h - 72.6h" "72.8h - 145.6h"

	#generate data for answers
	echo "Outputting answers data..."
	[ -f $statsAnswersFileJS ] && rm -f $statsAnswersFileJS
	WriteUnboundStats_ToJS "barDataAnswers" $statsAnswersFileJS $raw_statsFile "num.answer.rcode.NOERROR" "num.answer.rcode.FORMERR" "num.answer.rcode.SERVFAIL" "num.answer.rcode.NXDOMAIN" "num.answer.rcode.NOTIMPL" "num.answer.rcode.REFUSED"
	WriteUnboundLabels_ToJS "barLabelsAnswers" $statsAnswersFileJS "DNS Query completed successfully" "DNS Query Format Error" "Server failed to complete the DNS request" "Domain name does not exist  (including adblock if enabled)" "Function not implemented" "The server refused to answer for the query"

	#cleanup temp files
	rm -f "/tmp/unbound-"*".csv"
	rm -f "/tmp/unbound-stats.sql"
	[ -f $raw_statsFile ] && rm -f $raw_statsFile
	[ -f $statsFile ] && rm -f $statsFile
	[ -f $statsTitleFile ] && rm -f $statsTitleFile
}

Auto_Startup(){
	case $1 in
		create)
			if [ -f /jffs/scripts/services-start ]; then
				STARTUPLINECOUNTEX=$(grep -cx "/jffs/addons/unbound/$SCRIPT_NAME_LOWER startup"' # '"$SCRIPT_NAME" /jffs/scripts/services-start)
				
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					echo "/jffs/addons/unbound/$SCRIPT_NAME_LOWER startup"' # '"$SCRIPT_NAME" >> /jffs/scripts/services-start
				fi
			else
				echo "#!/bin/sh" > /jffs/scripts/services-start
				echo "" >> /jffs/scripts/services-start
				echo "/jffs/scripts/$SCRIPT_NAME_LOWER startup"' # '"$SCRIPT_NAME" >> /jffs/scripts/services-start
				chmod 0755 /jffs/scripts/services-start
			fi
		;;
		delete)
			if [ -f /jffs/scripts/services-start ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
				fi
			fi
		;;
	esac
}

Auto_Cron(){
	case $1 in
		create)
			STARTUPLINECOUNT=$(cru l | grep -c "$SCRIPT_NAME")
			
			if [ "$STARTUPLINECOUNT" -eq 0 ]; then
				cru a "$SCRIPT_NAME" "59 * * * * /jffs/addons/unbound/$SCRIPT_NAME_LOWER generate"
			fi
		;;
		delete)
			STARTUPLINECOUNT=$(cru l | grep -c "$SCRIPT_NAME")
			
			if [ "$STARTUPLINECOUNT" -gt 0 ]; then
				cru d "$SCRIPT_NAME"
			fi
		;;
	esac
}

Auto_ServiceEvent(){
	case $1 in
		create)
			if [ -f /jffs/scripts/service-event ]; then
				# shellcheck disable=SC2016
				STARTUPLINECOUNTEX=$(grep -cx "/jffs/addons/unbound/$SCRIPT_NAME_LOWER generate"' "$1" "$2" &'' # '"$SCRIPT_NAME" /jffs/scripts/service-event)
				
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					# shellcheck disable=SC2016
					echo "/jffs/addons/unbound/$SCRIPT_NAME_LOWER generate"' "$1" "$2" &'' # '"$SCRIPT_NAME" >> /jffs/scripts/service-event
			fi
			else
				echo "#!/bin/sh" > /jffs/scripts/service-event
				echo "" >> /jffs/scripts/service-event
				# shellcheck disable=SC2016
				echo "/jffs/scripts/$SCRIPT_NAME_LOWER generate"' "$1" "$2" &'' # '"$SCRIPT_NAME" >> /jffs/scripts/service-event
				chmod 0755 /jffs/scripts/service-event
			fi
		;;
		delete)
			if [ -f /jffs/scripts/service-event ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/service-event)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/service-event
				fi
			fi
		;;
	esac
}


Create_Dirs(){

	if [ ! -d "$SCRIPT_WEBPAGE_DIR" ]; then
		mkdir -p "$SCRIPT_WEBPAGE_DIR"
	fi
	
	if [ ! -d "$SCRIPT_WEB_DIR" ]; then
		mkdir -p "$SCRIPT_WEB_DIR"
	fi
}

Get_WebUI_Page () {
	for i in 1 2 3 4 5 6 7 8 9 10; do
		page="$SCRIPT_WEBPAGE_DIR/user$i.asp"
		if [ ! -f "$page" ] || [ "$(md5sum < "$1")" = "$(md5sum < "$page")" ] || [ "$(cat $installedMD5File)" = "$(md5sum < "$page")" ]; then
			MyPage="user$i.asp"
			return
		fi
	done
	MyPage="none"
}

Mount_WebUI(){
	if nvram get rc_support | grep -qF "am_addons"; then
		Get_WebUI_Page "$SCRIPT_DIR/unboundstats_www.asp"
		if [ "$MyPage" = "none" ]; then
			echo "Unable to mount $SCRIPT_NAME WebUI page, exiting"
			exit 1
		fi
		echo "Mounting $SCRIPT_NAME WebUI page as $MyPage" "$PASS"
		cp -f "$SCRIPT_DIR/unboundstats_www.asp" "$SCRIPT_WEBPAGE_DIR/$MyPage"
		echo "Saving MD5 of installed file $SCRIPT_DIR/unboundstats_www.asp to $installedMD5File"
		md5sum < "$SCRIPT_DIR/unboundstats_www.asp" > $installedMD5File
		
		if [ ! -f "/tmp/index_style.css" ]; then
			cp -f "/www/index_style.css" "/tmp/"
		fi
		
		if ! grep -q '.menu_Addons' /tmp/index_style.css ; then
			echo ".menu_Addons { background: url(ext/shared-jy/addons.png); }" >> /tmp/index_style.css
		fi
		
		umount /www/index_style.css 2>/dev/null
		mount -o bind /tmp/index_style.css /www/index_style.css
		
		if [ ! -f "/tmp/menuTree.js" ]; then
			cp -f "/www/require/modules/menuTree.js" "/tmp/"
		fi
		
		sed -i "\\~$MyPage~d" /tmp/menuTree.js
		
		if ! grep -q 'menuName: "Addons"' /tmp/menuTree.js ; then
			lineinsbefore="$(( $(grep -n "exclude:" /tmp/menuTree.js | cut -f1 -d':') - 1))"
			sed -i "$lineinsbefore"'i,\n{\nmenuName: "Addons",\nindex: "menu_Addons",\ntab: [\n{url: "ext/shared-jy/redirect.htm", tabName: "Help & Support"},\n{url: "NULL", tabName: "__INHERIT__"}\n]\n}' /tmp/menuTree.js
		fi
		
		if ! grep -q "javascript:window.open('/ext/shared-jy/redirect.htm'" /tmp/menuTree.js ; then
			sed -i "s~ext/shared-jy/redirect.htm~javascript:window.open('/ext/shared-jy/redirect.htm','_blank')~" /tmp/menuTree.js
		fi
		sed -i "/url: \"javascript:window.open('\/ext\/shared-jy\/redirect.htm'/i {url: \"$MyPage\", tabName: \"Unbound\"}," /tmp/menuTree.js
		
		umount /www/require/modules/menuTree.js 2>/dev/null
		mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
	fi
}

Unmount_WebUI(){
	Get_WebUI_Page "$SCRIPT_DIR/unboundstats_www.asp"
	echo "$MyPage"
	if [ -n "$MyPage" ] && [ "$MyPage" != "none" ] && [ -f "/tmp/menuTree.js" ]; then
		sed -i "\\~$MyPage~d" /tmp/menuTree.js
		umount /www/require/modules/menuTree.js
		mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		rm -rf "$SCRIPT_WEBPAGE_DIR/$MyPage"
		rm -rf "$SCRIPT_WEB_DIR"
	fi
}

ScriptHeader(){
	printf "\\n"
	printf "##\\n"
	printf "# ____ ___     ___.                            .___   _________ __          __          \\n"
	printf "#|    |   \____\_ |__   ____  __ __  ____    __| _/  /   _____//  |______ _/  |_  ______\\n"
	printf "#|    |   /    \| __ \ /  _ \|  |  \/    \  / __ |   \_____  \\   __\__  \\   __\/  ___/\\n"
	printf "#|    |  /   |  \ \_\ (  <_> )  |  /   |  \/ /_/ |   /        \|  |  / __ \|  |  \___ \ \\n"
	printf "#|______/|___|  /___  /\____/|____/|___|  /\____ |  /_______  /|__| (____  /__| /____  >\\n"
	printf "#             \/    \/                  \/      \/          \/           \/          \/ \\n"
	printf "## by @juched %s                                                                    \\n" "$SCRIPT_VERSION"
	printf "## with credit to @JackYaz for his shared scripts                                       \\n"
	printf "\\n"
	printf "unbound_stats.sh\\n"
	printf "		install   - Installs the needed files to show UI and update stats\\n"
	printf "		generate  - enerates statistics now for UI\\n"
	printf "		uninstall - Removes files needed for UI and stops stats update\\n"
}

Install_SQLite(){
	if [ ! -f /opt/bin/sqlite3 ]; then
		echo "Installing required version of sqlite3 from Entware" "$PASS"
		opkg update
		opkg install sqlite3-cli
	fi
}

#Main loop
if [ -z "$1" ]; then
	ScriptHeader
	exit 0
fi

case "$1" in
	install)
		Install_SQLite
		Auto_Startup create
		Auto_ServiceEvent create
		Auto_Cron create
		Mount_WebUI
		Create_Dirs
		Generate_UnboundStats
		exit 0
	;;
	startup)
		Auto_Cron create
		Mount_WebUI
		Create_Dirs
		Generate_UnboundStats
		exit 0
	;;
	generate)
		if [ -z "$2" ] && [ -z "$3" ]; then
			Generate_UnboundStats
		elif [ "$2" = "start" ] && [ "$3" = "$SCRIPT_NAME_LOWER" ]; then
			Generate_UnboundStats
		fi
		exit 0
	;;
	uninstall)
		Auto_Startup delete
		Auto_ServiceEvent delete
		Auto_Cron delete
		Unmount_WebUI
		exit 0
	;;
esac
