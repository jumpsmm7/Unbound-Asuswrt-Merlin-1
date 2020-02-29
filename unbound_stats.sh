#!/bin/sh
##
# ____ ___     ___.                            .___   _________ __          __          
#|    |   \____\_ |__   ____  __ __  ____    __| _/  /   _____//  |______ _/  |_  ______
#|    |   /    \| __ \ /  _ \|  |  \/    \  / __ |   \_____  \\   __\__  \\   __\/  ___/
#|    |  /   |  \ \_\ (  <_> )  |  /   |  \/ /_/ |   /        \|  |  / __ \|  |  \___ \ 
#|______/|___|  /___  /\____/|____/|___|  /\____ |  /_______  /|__| (____  /__| /____  >
#             \/    \/                  \/      \/          \/           \/          \/ 
## by @juched v1.0.0
## with credit to @JackYaz for his shared scripts

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
raw_statsFile="$SCRIPT_WEB_DIR/raw_stats.txt"
statsFile="$SCRIPT_WEB_DIR/unboundstats.txt"
statsTitleFile="$SCRIPT_WEB_DIR/unboundstatstitle.txt"
statsFileJS="$SCRIPT_WEB_DIR/unboundstats.js"
statsTitleFileJS="$SCRIPT_WEB_DIR/unboundstatstitle.js"

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
	
	#calc % served by cache
	printf "$(awk 'BEGIN {printf "\\n\\n Cache hit success percent: %0.2f", '$UNB_NUM_CH'*100/'$UNB_NUM_Q'}' )" >> $statsFile
	
	#create JS file to be loaded by web page
	WriteStats_ToJS "$statsFile" "$statsFileJS" "SetUnboundStats" "unboundstats"
	
	echo "Unbound Stats generated on $(date +"%c")" > $statsTitleFile
	WriteStats_ToJS "$statsTitleFile" "$statsTitleFileJS" "SetUnboundStatsTitle" "unboundstatstitle"

	#cleanup temp files
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
		if [ ! -f "$page" ] || [ "$(md5sum < "$1")" = "$(md5sum < "$page")" ]; then
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
		
		if [ ! -f "/tmp/index_style.css" ]; then
			cp -f "/www/index_style.css" "/tmp/"
		fi
		
		if ! grep -q '.menu_Addons' /tmp/index_style.css ; then
			echo ".menu_Addons { background: url(ext/shared-jy/addons.png); }" >> /tmp/index_style.css
		fi
		
		umount /www/index_style.css 2>/dev/null
		mount -o bind /tmp/index_style.css /www/index_style.css
		
		if [ ! -f "/tmp/menuTree.js" ]; then
			p -f "/www/require/modules/menuTree.js" "/tmp/"
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

#Main loop
if [ -z "$1" ]; then
	ScriptHeader
	exit 0
fi

case "$1" in
	install)
		#if [ ! -f /opt/bin/sqlite3 ]; then
			#echo "Installing required version of sqlite3 from Entware" "$PASS"
			#opkg update
			#opkg install sqlite3-cli
		#fi
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
