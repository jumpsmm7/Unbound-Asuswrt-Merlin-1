#!/bin/bash

# AdBlock Script to download from customizable lists and merge into unbound rules file.
# Use permlist file in same folder to add per line domains you want to whitelist.
# Use blocklist file in same folder to block per line domains you want to block.
# Use sites file to create list of sites/URLs you want to download from and merge.
# File is in the format of 1 site/URL per line with two parts.
#	<type> <URL>
#	type can be one of:
#		domains - for blocklists of the format of 1 domain per line
#		hosts - for blocklists of the format of 1 host file entry per line with 0.0.0.0 IP (sorry, no 127.0.0.1)
#		whitelist-domains - for whitelists of the format of 1 domain per line
#
# @juched - v1.0.3
# 	Special thanks to @Martineau @rgnldo @Jack_Yaz for setting up and hosting and thinking of this
# v1.0.1 - moved config to /opt/share/unbound/configs
#	 - save and reload unbound cache on restart
# v1.0.2 - separated required domains from user editable domains for allow list
# v1.0.3 - switched to use unbound_manager.sh restart to be more safe

destinationIP="0.0.0.0"

#adblock function paths
tempoutlist="/opt/var/lib/unbound/adblock/adlist"
tempwhitelistoutlist="/opt/var/lib/unbound/adblock/whitelist"
outlist='/opt/var/lib/unbound/adblock/outlist'
finalist='/opt/var/lib/unbound/adblock/finalist'
permlist='/opt/var/lib/unbound/adblock/permlist'
adlist='/opt/var/lib/unbound/adblock/adservers'

#user settings paths
blocklist='/opt/share/unbound/configs/blockhost'
allowlist='/opt/share/unbound/configs/allowhost'
blocksites='/opt/share/unbound/configs/blocksites'
allowsites='/opt/share/unbound/configs/allowsites'
#used to write out stats in case people want to see
statsFile="/opt/var/lib/unbound/adblock/stats.txt"

echo "Removing possible temporary files.."
[ -f $tempoutlist ] && rm -f $tempoutlist
[ -f $tempwhitelistoutlist ] && rm -f $tempwhitelistoutlist
[ -f $outlist ] && rm -f $outlist
[ -f $finalist ] && rm -f $finalist

# check for sites file
if [ ! -f $blocksites ]; then
  logger -st "($(basename $0))" "Missing $blocksites file"
  exit
fi

# process blocksites list
download_file () {
  sites=$1
  list=$2
  while read -r line
  do
  set -- $line
  for url in $(echo $line); do
  echo "Attempting to Download $url"
  curl --progress-bar $url | grep -v "#" | grep -v "::1" | grep -v "0.0.0.0 0.0.0.0" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $NF}' | grep -v '^\\' | grep -v '\\$'| sort >> $list
  dos2unix -q $list
  done
  done < "$sites"
}

filter_file () {
  filter=$1
  original=$2
  awk 'NR==FNR{a[$0];next} !($0 in a) {print $NF}' $filter $original | sort -u > ${original}.tmp
  mv ${original}.tmp $original
}

cleanup () { 
  unclean=$1
  output=$2
  cat $unclean | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | sort -u > ${output}.tmp
  mv ${output}.tmp $output
  awk 'NR==FNR{a[$0];next} !($0 in a) {print $NF}' $output $unclean | sort -u > ${output}.tmp
  mv ${output}.tmp $output
  cat $output | sed -r -e 's/[[:space:]]+/\t/g' | sed -e 's/\t*#.*$//g' | sed -e 's/[^a-zA-Z0-9\.\_\t\-]//g' | sed -e 's/\t$//g' | sed -e '/^#/d' | sed -e 's/^[ \t]*//;s/[ \t]*$//' | sort -u | sed '/^$/d' | awk -v "IP=$destinationIP" '{sub(/\r$/,""); print IP" "$0}' > $3
}

download_file $blocksites $tempoutlist
[ -f $allowsites ] && download_file $allowsites $tempwhitelistoutlist
[ -f $blocklist ] && echo "Combining User Custom block host..." && cat $blocklist >> $tempoutlist
[ -f $tempwhitelistoutlist ] && echo "Removing any downloaded whitelist items..." && filter_file $tempwhitelistoutlist $tempoutlist
[ -f $allowlist ] && echo "Filtering required domains from adblock list..." && filter_file $allowlist $tempoutlist
[ -f $permlist ] && echo "Filtering user requested domains from adblock list..." && filter_file $permlist $tempoutlist
[ -f $tempoutlist ] && echo "Removing unnecessary formatting from the domain list..." && cleanup $tempoutlist $outlist $finalist
numberOfAdsBlocked=$(wc -l < $outlist)
echo "$numberOfAdsBlocked domains compiled"
echo "Generating Unbound adlist....."
awk '/^0.0.0.0/ {print "local-zone: \""$2"\" always_nxdomain"}' $finalist > $adlist
numberOfAdsBlocked=$(wc -l < $adlist)
echo " Number of adblocked (ads/malware/tracker) and blacklisted domains: $numberOfAdsBlocked" > $statsFile
echo " Last updated: $(date +"%c")" >> $statsFile

echo "Removing temporary files..."
[ -f $tempoutlist ] && rm -f $tempoutlist
[ -f $tempwhitelistoutlist ] && rm -f $tempwhitelistoutlist
[ -f $outlist ] && rm -f $outlist
[ -f $finalist ] && rm -f $finalist

echo "Restarting Unbound DNS server..."
/jffs/addons/unbound/unbound_manager.sh restart
echo "Adblock update complete!"
