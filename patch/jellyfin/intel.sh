#!/bin/bash

which "curl" > "/dev/null" 2>&1
if [ "$?" -eq "1" ]; then
    apt update && apt install -qy curl
fi

which "wget" > "/dev/null" 2>&1
if [ "$?" -eq "1" ]; then
    apt update && apt install -qy wget
fi

for i in $(cat "/opt/intel-patch/intel.version" | awk "{print $2}"); do
    if [ -n "$GHPROXY_URL" ]; then
        i=$(echo $i | sed "s|https://github.com|https://${GHPROXY_URL}/https://github.com|g")
    fi && wget -P ${DOWNLOAD_DIR:-/tmp} $i
done

all_files=(${DOWNLOAD_DIR:-/tmp}/*.deb ${DOWNLOAD_DIR:-/tmp}/*.ddeb)
if [ ${#all_files[@]} -gt 0 ]; then
    dpkg -i "${all_files[@]}" && rm -f "${all_files[@]}"
fi
