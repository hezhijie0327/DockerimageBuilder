#!/bin/bash

GHPROXY_URL=""
DOWNLOAD_DIR="/tmp"

which "curl" > "/dev/null" 2>&1
if [ "$?" -eq "1" ]; then
    apt-get update && apt-get install -qy curl
fi

which "wget" > "/dev/null" 2>&1
if [ "$?" -eq "1" ]; then
    apt-get update && apt-get install -qy wget
fi

for i in $(cat "/opt/intel-patch/intel.version" | awk "{print $2}"); do
    if [ -n "$GHPROXY_URL" ]; then
        i=$(echo $i | sed "s|https://github.com|https://${GHPROXY_URL}/https://github.com|g")
    fi && wget -P $DOWNLOAD_DIR $i
done

if [ -f $DOWNLOAD_DIR/*.deb ]; then
    dpkg -i $DOWNLOAD_DIR/*.deb && rm -rf $DOWNLOAD_DIR/*.deb
fi
if [ -f $DOWNLOAD_DIR/*.ddeb ]; then
    dpkg -i $DOWNLOAD_DIR/*.ddeb && rm -rf $DOWNLOAD_DIR/*.ddeb
fi
