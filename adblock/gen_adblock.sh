#!/bin/bash
destinationIP="0.0.0.0"
tempoutlist="/opt/var/lib/unbound/adblock/adlist.tmp"
tempwhitelistoutlist="/opt/var/lib/unbound/adblock/whitelist.tmp"
outlist='/opt/var/lib/unbound/adblock/tmp.host'
finalist='/opt/var/lib/unbound/adblock/tmp.finalhost'
permlist='/opt/var/lib/unbound/adblock/permlist'
adlist='/opt/var/lib/unbound/adblock/adservers'
sites='/opt/var/lib/unbound/adblock/sites'

echo "Removing possible temporary files.."
[ -f $tempoutlist ] && rm -f $tempoutlist
[ -f $tempwhitelistoutlist ] && rm -f $tempwhitelistoutlist
[ -f $outlist ] && rm -f $outlist
[ -f $finalist ] && rm -f $finalist

# check for sites file
if [ ! -f $sites ]; then
  echo "Missing $sites file"
  exit
fi

# process sites list
while read -r line
do
  set -- $line
  if [ "$2" != "" ]; then
    if [ "$1" == "hosts" ]; then
      echo "Processsing hosts file @ $2"
      curl --progress-bar $2 | grep -v "#" | grep -v "::1" | grep -v "0.0.0.0 0.0.0.0" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$'| sort >> $tempoutlist
    elif [ "$1" == "domains" ]; then
     echo "Processing domains file @ $2"
     curl --progress-bar $2 >> $tempoutlist
    elif [ "$1" == "whitelist-domains" ]; then
     echo "Processing whitelist domains file @ $2"
     curl --progress-bar $2 >> $tempwhitelistoutlist
    else
      echo "Unknown file type = $1"
    fi
  else
    echo "Missing site URL on line $line"
  fi
done < "$sites"

echo "Combining User Custom block host..."
cat /opt/var/lib/unbound/adblock/blockhost >> $tempoutlist

echo "Removing duplicate formatting from the domain list..."
cat $tempoutlist | sed -r -e 's/[[:space:]]+/\t/g' | sed -e 's/\t*#.*$//g' | sed -e 's/[^a-zA-Z0-9\.\_\t\-]//g' | sed -e 's/\t$//g' | sed -e '/^#/d' | sort -u | sed '/^$/d' | awk -v "IP=$destinationIP" '{sub(/\r$/,""); print IP" "$0}' > $outlist
numberOfAdsBlocked=$(cat $outlist | wc -l | sed 's/^[ \t]*//')
echo "$numberOfAdsBlocked domains compiled"

if [ -f $tempwhitelistoutlist ]; then
  echo "Removing any downloaded whitelist items..."
  fgrep -vf $tempwhitelistoutlist $outlist > $finalist
  mv $finalist $outlist
fi

echo "Edit User Custon list of allowed domains..."
fgrep -vf $permlist $outlist  > $finalist

echo "Generating Unbound adlist....."
cat $finalist | grep '^0\.0\.0\.0' | awk '{print "local-zone: \""$2"\" always_nxdomain"}' > $adlist
numberOfAdsBlocked=$(cat $adlist | wc -l | sed 's/^[ \t]*//')
echo "$numberOfAdsBlocked suspicious and blocked domains"

echo "Removing temporary files..."
[ -f $tempoutlist ] && rm -f $tempoutlist
[ -f $tempwhitelistoutlist ] && rm -f $tempwhitelistoutlist
[ -f $outlist ] && rm -f $outlist
[ -f $finalist ] && rm -f $finalist

#echo "Removing log's files..."
#[ -f /opt/var/lib/unbound/unbound.log ] && rm -f /opt/var/lib/unbound/unbound.log
echo "Restarting DNS servers..."
/opt/etc/init.d/S61unbound restart
