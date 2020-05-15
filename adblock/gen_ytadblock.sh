#!/bin/sh 
##
#
#Y88b   d88P 88888888888     d8888      888 888888b.   888                   888      
# Y88b d88P      888        d88888      888 888  "88b  888                   888      
#  Y88o88P       888       d88P888      888 888  .88P  888                   888      
#   Y888P        888      d88P 888  .d88888 8888888K.  888  .d88b.   .d8888b 888  888 
#    888         888     d88P  888 d88" 888 888  "Y88b 888 d88""88b d88P"    888 .88P 
#    888         888    d88P   888 888  888 888    888 888 888  888 888      888888K  
#    888         888   d8888888888 Y88b 888 888   d88P 888 Y88..88P Y88b.    888 "88b 
#    888         888  d88P     888  "Y88888 8888888P"  888  "Y88P"   "Y8888P 888  888 
## @juched - dynamically block YT ads
##gen_ytadblock.sh
##based on @grublets script on gitlab here: https://gitlab.com/grublets/youtube-updater-for-pi-hole/-/tree/master
## - v1.0 - May 7 2020 - Initial version
## - v1.1 - May 8 2020 - Fixed issue with force IP file being created empty
## - v1.2 - May 14 2020 - Added ability to re-pick IP to use, incase the old IP is dead
readonly SCRIPT_VERSION="v1.2"

Say(){
   echo -e $$ $@ | logger -st "($(basename $0))"
}

ScriptHeader(){
	printf "\\n"
	printf "Y88b   d88P 88888888888     d8888      888 888888b.   888                   888\\n"
	printf " Y88b d88P      888        d88888      888 888  \"88b  888                   888\\n"
	printf "  Y88o88P       888       d88P888      888 888  .88P  888                   888\\n"
	printf "   Y888P        888      d88P 888  .d88888 8888888K.  888  .d88b.   .d8888b 888  888\\n"
	printf "    888         888     d88P  888 d88\" 888 888  \"Y88b 888 d88\"\"88b d88P\"    888 .88P\\n"
	printf "    888         888    d88P   888 888  888 888    888 888 888  888 888      888888K\\n"
	printf "    888         888   d8888888888 Y88b 888 888   d88P 888 Y88..88P Y88b.    888 \"88b\\n"
	printf "    888         888  d88P     888  \"Y88888 8888888P\"  888  \"Y88P\"   \"Y8888P 888  888\\n"
	printf "## by @juched - dynamically block YT ads - %s                      \\n" "$SCRIPT_VERSION"
	printf "\\n"
	printf "gen_ytadblock.sh\\n"
}

ScriptHeader
#place this file in /opt/var/lib/unbound/adblock/gen_ytadblock.sh
#command to install cru a ytadblock "*/5 * * * * /opt/var/lib/unbound/adblock/gen_ytadblock.sh"

#variables
ipYTforce="/opt/share/unbound/configs/ipytforce"
fileYTAds="/opt/var/lib/unbound/adblock/ytadblock"

if [ -n "$(pidof unbound)" ]; then
  [ -f $ipYTforce ] && [ ! -s $ipYTforce ] && rm -f $ipYTforce # clean up empty file due to bug
  [ -f $ipYTforce ] && [ "$1" == "force_newip" ] && rm -f $ipYTforce && echo "Forgetting old IP..."
  if [ ! -f $ipYTforce ]; then
    echo "No stored IP in file $ipYTforce, checking cache for an ip..."
    unbound-control dump_cache | awk '/.*\.googlevideo.*\.[0-9].*\./{print $5;exit}' > "$ipYTforce"
    if [ ! -s $ipYTforce ]; then
      echo "No ip found in unbound cache.  Try to watch a video on YT and try again."
      [ -f $ipYTforce ] && rm -rf $ipYTforce
      exit
    fi
  fi
  ipYT=$(cat $ipYTforce)
  echo "Forcing to use YT IP" $ipYT

  # replace any existing entries with new IP
  if [ -f $fileYTAds ] && [ "$1" == "force_newip" ]; then
    echo "Updating yt adblock list to new IP..."
    awk -v varip="$ipYT" '{print $1 " IN A " varip}' $fileYTAds > "$fileYTAds.tmp"
    cp "$fileYTAds.tmp" "$fileYTAds"
    rm -f "$fileYTAds.tmp"
  fi

  echo "Generating Unbound yt adblock list..."
  unbound-control dump_cache | awk -v varip="$ipYT" '/.*\.googlevideo.*\.[0-9].*\./{print $1 " IN A " varip}' >> "$fileYTAds"
  sort -u $fileYTAds -o $fileYTAds

  numberYT=$(wc -l < $fileYTAds)
  Say "Number of yt adblocked domains: $numberYT"
  #echo " Number of yt adblocked domains: $numberYT" > $statsFile


  echo "Loading/Unload Unbound local-data to take effect..."
  [ -f $fileYTAds ] && unbound-control local_datas < $fileYTAds
else
  Say "Warning unbound NOT running!"
fi

echo "All done updating YT hosts!"
