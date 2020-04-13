#!/bin/sh
##
# (        ) (      (                                   
# )\ )  ( /( )\ )   )\ )                         (  (   
#(()/(  )\()|()/(  (()/( (  (     (  (  (      ) )\ )\  
# /(_))((_)\ /(_))  /(_)))\ )(   ))\ )\))(  ( /(((_|(_) 
#(_))_  _((_|_))   (_))_((_|()\ /((_|(_)()\ )(_))_  _   
# |   \| \| / __|  | |_  (_)((_|_)) _(()((_|(_)_| || |  
# | |) | .` \__ \  | __| | | '_/ -_)\ V  V / _` | || |  
# |___/|_|\_|___/  |_|   |_|_| \___| \_/\_/\__,_|_||_|  
## by @juched - DNS Firewall in Unbound (needs unbound 1.10.0+)
## Unbound-RPZ.sh
## v1.0 - Initial quick release.  Run it once, it keeps running.  No installer.
## v1.0.1 - Only reload if unbound is running
## v1.1.0 - Updated with proper commands to install/uninstall and update.  Now survives reboot of router
readonly SCRIPT_VERSION="v1.1.0"

#define needed vars
readonly rpzSitesFile="/opt/share/unbound/configs/rpzsites"
readonly SCRIPT_NAME="Unbound_RPZ.sh"
readonly SCRIPT_NAME_LOWER="unbound_rpz.sh"
readonly SCRIPT_DIR="/jffs/addons/unbound"

#define needed commands
readonly UNBOUNCTRLCMD="unbound-control"

ScriptHeader() {
	printf "\\n"
	printf "##\\n"
	printf "# (        ) (      (                                   \\n"
	printf "# )\ )  ( /( )\ )   )\ )                         (  (   \\n"
	printf "#(()/(  )\()|()/(  (()/( (  (     (  (  (      ) )\ )\  \\n"
	printf "# /(_))((_)\ /(_))  /(_)))\ )(   ))\ )\))(  ( /(((_|(_) \\n"
	printf "#(_))_  _((_|_))   (_))_((_|()\ /((_|(_)()\ )(_))_  _   \\n"
	printf "# |   \| \| / __|  | |_  (_)((_|_)) _(()((_|(_)_| || |  \\n"
	printf "# | |) | .\` \__ \  | __| | | '_/ -_)\ V  V / _\` | || |  \\n"
	printf "# |___/|_|\_|___/  |_|   |_|_| \___| \_/\_/\__,_|_||_|  \\n"

	printf "## by @juched - DNS Firewall in Unbound (needs unbound 1.10.0+) - %s\\n" "$SCRIPT_VERSION"
	printf "\\n"
	printf "unbound_rpz.sh\\n"
	printf "		install   - Starts the automatic download of data files\\n"
	printf "		download  - Download and reload the data files used for DNS Firewall\\n"
	printf "		uninstall - Stops the automatic download of data files, and clean up\\n"
}


download_reload() {
  sitesfile=$1
  reload=$2
  count=1
  while read -r line
  do
    set -- $line
    #[ "${$line:0:1}" == "#" ] && continue
    echo "Attempting to Download $count of $(awk 'NF && !/^[:space:]*#/' $sitesfile | wc -l) from $1."
    curl --progress-bar $1 > $2
    dos2unix $2

    if [ "$reload" == "reload" ] && [ ! -z "$(pidof unbound)" ]; then
      echo "Reload unbound for zone named $3"
      $UNBOUNCTRLCMD auth_zone_reload "$3"
    fi
    count=$((count + 1))
  done < "$sitesfile"
}

Auto_Startup(){
	case $1 in
		create)
			if [ -f /jffs/scripts/services-start ]; then
				STARTUPLINECOUNTEX=$(grep -cx "$SCRIPT_DIR/$SCRIPT_NAME_LOWER startup"' # '"$SCRIPT_NAME" /jffs/scripts/services-start)
				
				if [ "$STARTUPLINECOUNTEX" -eq 0 ]; then
					echo "$SCRIPT_DIR/$SCRIPT_NAME_LOWER startup"' # '"$SCRIPT_NAME" >> /jffs/scripts/services-start
					echo "Created startup hook in services-start."
				fi
			else
				echo "#!/bin/sh" > /jffs/scripts/services-start
				echo "" >> /jffs/scripts/services-start
				echo "$SCRIPT_DIR/$SCRIPT_NAME_LOWER startup"' # '"$SCRIPT_NAME" >> /jffs/scripts/services-start
				chmod 0755 /jffs/scripts/services-start
				echo "Created startup hook in services-start."
			fi
		;;
		delete)
			if [ -f /jffs/scripts/services-start ]; then
				STARTUPLINECOUNT=$(grep -c '# '"$SCRIPT_NAME" /jffs/scripts/services-start)
				
				if [ "$STARTUPLINECOUNT" -gt 0 ]; then
					sed -i -e '/# '"$SCRIPT_NAME"'/d' /jffs/scripts/services-start
					echo "Removed startup hook in services-start."
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
				cru a "$SCRIPT_NAME" "*/15 * * * * $SCRIPT_DIR/$SCRIPT_NAME_LOWER download"
				echo "Created cron job."
			fi
		;;
		delete)
			STARTUPLINECOUNT=$(cru l | grep -c "$SCRIPT_NAME")
			
			if [ "$STARTUPLINECOUNT" -gt 0 ]; then
				cru d "$SCRIPT_NAME"
				echo "Removed cron job."
			fi
		;;
	esac
}


#Main loop
if [ -z "$1" ]; then
	ScriptHeader
	exit 0
fi

case "$1" in
	install)
		Auto_Startup create
		Auto_Cron create
		download_reload "$rpzSitesFile" "no_reload"
		echo "Installed."
		exit 0
	;;
	startup)
		Auto_Cron create
		exit 0
	;;
	download)
		download_reload "$rpzSitesFile" "reload"
		exit 0
	;;
	uninstall)
		Auto_Startup delete
		Auto_Cron delete
		echo "Uninstalled."
		# cleanup zones files previously downloaded?
		exit 0
	;;
esac

