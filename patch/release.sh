#!/bin/bash

## How to get and use?
# git clone "https://github.com/hezhijie0327/DockerimageBuilder.git" && bash ./DockerimageBuilder/patch/release.sh

## Parameter
export CLOUDFLARED_VERSION_FIXED=""
export JELLYFIN_VERSION_FIXED=""
export JELLYFIN_WEB_VERSION_FIXED=""
export QBITTORRENT_VERSION_FIXED=""
export SIYUAN_VERSION_FIXED=""
export VAULTWARDEN_VERSION_FIXED=""
export VAULTWARDEN_WEB_VERSION_FIXED=""
export VUETORRENT_VERSION_FIXED=""
export XRAY_VERSION_FIXED=""

## Function
# Get Latest Version
function GetLatestVersion() {
    CLOUDFLARED_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/cloudflare/cloudflared/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/" | tail -n 1 | sed "s/refs\/tags\///")
    JELLYFIN_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/jellyfin/jellyfin/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "-" | tail -n 1 | sed "s/refs\/tags\/v//")
    JELLYFIN_WEB_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/jellyfin/jellyfin-web/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "-" | tail -n 1 | sed "s/refs\/tags\/v//")
    QBITTORRENT_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/qbittorrent/qBittorrent/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "alpha\|beta\|rc" | grep "^refs/tags/release-" | tail -n 1 | sed "s/refs\/tags\/release\-//")
    SIYUAN_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/siyuan-note/siyuan/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "\-dev" | tail -n 1 | sed "s/refs\/tags\/v//")
    VAULTWARDEN_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/dani-garcia/vaultwarden/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/" | tail -n 1 | sed "s/refs\/tags\///")
    VAULTWARDEN_WEB_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/dani-garcia/bw_web_builds/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    VUETORRENT_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/VueTorrent/VueTorrent/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    XRAY_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/XTLS/Xray-core/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "-" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
}
# Generate Replacements
function GenerateReplacements() {
    replacement_list=(
        "s/{CLOUDFLARED_VERSION}/${CLOUDFLARED_VERSION_FIXED:-${CLOUDFLARED_VERSION}}/g"
        "s/{JELLYFIN_VERSION}/${JELLYFIN_VERSION_FIXED:-${JELLYFIN_VERSION}}/g"
        "s/{JELLYFIN_WEB_VERSION}/${JELLYFIN_WEB_VERSION_FIXED:-${JELLYFIN_WEB_VERSION}}/g"
        "s/{QBITTORRENT_VERSION}/${QBITTORRENT_VERSION_FIXED:-${QBITTORRENT_VERSION}}/g"
        "s/{SIYUAN_VERSION}/${SIYUAN_VERSION_FIXED:-${SIYUAN_VERSION}}/g"
        "s/{VAULTWARDEN_VERSION}/${VAULTWARDEN_VERSION_FIXED:-${VAULTWARDEN_VERSION}}/g"
        "s/{VAULTWARDEN_WEB_VERSION}/${VAULTWARDEN_WEB_VERSION_FIXED:-${VAULTWARDEN_WEB_VERSION}}/g"
        "s/{VUETORRENT_VERSION}/${VUETORRENT_VERSION_FIXED:-${VUETORRENT_VERSION}}/g"
        "s/{XRAY_VERSION}/${XRAY_VERSION_FIXED:-${XRAY_VERSION}}/g"
    )
    SED_REPLACEMENT="" && for replacement_list_task in "${!replacement_list[@]}"; do
        SED_REPLACEMENT="${SED_REPLACEMENT}${replacement_list[$replacement_list_task]};"
    done
}
# Output Package
function OutputPackage() {
    echo "Info: Current SED replacement is ${SED_REPLACEMENT}" && if [ ! -z $(echo "${SED_REPLACEMENT}" | grep -E "//g;|/000/g;") ]; then
        echo "Error: Latest version missing, exit script." && exit 1
    else
        cat "./patch/template.json" | sed "${SED_REPLACEMENT}" > "./patch/package.json" && if [ ! -z $(cat "./patch/package.json" | grep -E "\"\"|-000.") ]; then
            echo "Error: Metadata missing, exit script." && exit 1
        else
            cat "./patch/package.json"
        fi
    fi
}

## Process
# Call GetLatestVersion
GetLatestVersion
# Call GenerateReplacements
GenerateReplacements
# Call OutputPackage
OutputPackage
