#!/bin/bash

# Unbound-RPZ.sh - Quick DNS Firewall for unbound using RPZ sites (needs unbound 1.10.0+)
# V1.0 - Initial quick release.  Run it once, it keeps running.  No installer.

echo "Unbound-RPZ.sh - V1.0 running..."

download_reload () {
  sitesfile=$1
  count=1
  while read -r line
  do
    set -- $line
#    [ "${$line:0:1}" == "#" ] && continue
    echo "Attempting to Download $count of $(awk 'NF && !/^[:space:]*#/' $sitesfile | wc -l) from $url."
    curl --progress-bar $1 > $2
    dos2unix $2

    echo "Reload unbound for zone named $3"
    unbound-control auth_zone_reload "$3"
    count=$((count + 1))
  done < "$sitesfile"
}

# ensure the cron job is running
cru a Unbound_RPZ.sh */15 * * * * /jffs/addons/unbound/unbound_rpz.sh

# read and download from rpzsites
download_reload "/opt/share/unbound/configs/rpzsites"

