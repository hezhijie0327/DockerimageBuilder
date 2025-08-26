#!/bin/bash

# Current Version: 2.3.9

## How to get and use?
# git clone "https://github.com/hezhijie0327/DockerimageBuilder.git" && bash ./DockerimageBuilder/patch/release.sh

## Parameter
export BROWSERLESS_VERSION_FIXED=""
export CLOUDFLARED_VERSION_FIXED=""
export ICU_VERSION_FIXED=""
export JELLYFIN_VERSION_FIXED=""
export JELLYFIN_WEB_VERSION_FIXED=""
export LIBEXPAT_VERSION_FIXED=""
export LIBHIREDIS_VERSION_FIXED=""
export LIBMNL_VERSION_FIXED=""
export LIBNGHTTP2_VERSION_FIXED=""
export LIBNGHTTP3_VERSION_FIXED=""
export LIBNGTCP2_VERSION_FIXED=""
export LIBSODIUM_VERSION_FIXED=""
export LOBECHAT_VERSION_FIXED=""
export OPENSSL_VERSION_FIXED=""
export QBITTORRENT_VERSION_FIXED=""
export RUSTFS_VERSION_FIXED="1.0.0"
export RUSTFS_WEB_VERSION_FIXED=""
export SEARXNG_VERSION_FIXED="1.0.0"
export SIYUAN_VERSION_FIXED=""
export UNBOUND_VERSION_FIXED=""
export VALKEY_VERSION_FIXED=""
export VAULTWARDEN_VERSION_FIXED=""
export VAULTWARDEN_WEB_VERSION_FIXED=""
export VUETORRENT_VERSION_FIXED=""
export XRAY_VERSION_FIXED=""

## Function
# Get Latest Version
function GetLatestVersion() {
    BROWSERLESS_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/browserless/browserless/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "-" | tail -n 1 | sed "s/refs\/tags\/v//")
    CLOUDFLARED_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/cloudflare/cloudflared/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/" | tail -n 1 | sed "s/refs\/tags\///")
    ICU_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/unicode-org/icu/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/release" | grep -v "alpha\|eclipse\|rc\|preview" | tail -n 1 | sed "s/refs\/tags\/release\-//")
    JELLYFIN_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/jellyfin/jellyfin/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "-" | tail -n 1 | sed "s/refs\/tags\/v//")
    JELLYFIN_WEB_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/jellyfin/jellyfin-web/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "-" | tail -n 1 | sed "s/refs\/tags\/v//")
    LIBEXPAT_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/libexpat/libexpat/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/R\_" | tail -n 1 | sed "s/refs\/tags\/R\_//" | tr "_" ".")
    LIBHIREDIS_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/redis/hiredis/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "rc" | tail -n 1 | sed "s/refs\/tags\/v//")
    LIBMNL_VERSION=$(curl -s --connect-timeout 15 "https://git.netfilter.org/libmnl/log" | grep 'release' | cut -d '<' -f 6 | cut -d ' ' -f 4 | head -n 1)
    LIBNGHTTP2_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/nghttp2/nghttp2/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    LIBNGHTTP3_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/ngtcp2/nghttp3/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    LIBNGTCP2_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/ngtcp2/ngtcp2/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    LIBSODIUM_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/jedisct1/libsodium/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags" | grep "\-RELEASE" | tail -n 1 | sed "s/refs\/tags\///;s/-RELEASE//")
    LOBECHAT_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/lobehub/lobe-chat/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    OPENSSL_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/openssl/openssl/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "alpha\|beta\|pre" | grep "^refs/tags/OpenSSL\_1\|^refs/tags/openssl\-3" | sort | tail -n 1 | sed "s/refs\/tags\/OpenSSL\_//;s/refs\/tags\/openssl\-//" | tr "_" ".")
    QBITTORRENT_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/qbittorrent/qBittorrent/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "alpha\|beta\|rc" | grep "^refs/tags/release-" | tail -n 1 | sed "s/refs\/tags\/release\-//")
    RUSTFS_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/rustfs/rustfs/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/" | grep -v "alpha" | tail -n 1 | sed "s/refs\/tags\///")
    RUSTFS_WEB_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/rustfs/console/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    SEARXNG_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/searxng/searxng/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    SIYUAN_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/siyuan-note/siyuan/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "\-dev" | tail -n 1 | sed "s/refs\/tags\/v//")
    UNBOUND_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/NLnetLabs/unbound/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "rc" | grep "^refs/tags/release\-" | tail -n 1 | sed "s/refs\/tags\/release\-//")
    VALKEY_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/valkey-io/valkey/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/" | grep -v "\-" | tail -n 1 | sed "s/refs\/tags\///")
    VAULTWARDEN_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/dani-garcia/vaultwarden/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/" | tail -n 1 | sed "s/refs\/tags\///")
    VAULTWARDEN_WEB_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/dani-garcia/bw_web_builds/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    VUETORRENT_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/VueTorrent/VueTorrent/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    XRAY_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/XTLS/Xray-core/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "-" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
}
# Generate Replacements
function GenerateReplacements() {
    replacement_list=(
        "s/{BROWSERLESS_VERSION}/${BROWSERLESS_VERSION_FIXED:-${BROWSERLESS_VERSION}}/g"
        "s/{CLOUDFLARED_VERSION}/${CLOUDFLARED_VERSION_FIXED:-${CLOUDFLARED_VERSION}}/g"
        "s/{ICU_VERSION}/${ICU_VERSION_FIXED:-${ICU_VERSION}}/g"
        "s/{ICU_VERSION_}/$(echo ${ICU_VERSION_FIXED:-${ICU_VERSION}} | tr '-' '_')/g"
        "s/{JELLYFIN_VERSION}/${JELLYFIN_VERSION_FIXED:-${JELLYFIN_VERSION}}/g"
        "s/{JELLYFIN_WEB_VERSION}/${JELLYFIN_WEB_VERSION_FIXED:-${JELLYFIN_WEB_VERSION}}/g"
        "s/{LIBEXPAT_VERSION_}/$(echo ${LIBEXPAT_VERSION_FIXED:-${LIBEXPAT_VERSION}} | tr '.' '_')/g"
        "s/{LIBEXPAT_VERSION}/${LIBEXPAT_VERSION_FIXED:-${LIBEXPAT_VERSION}}/g"
        "s/{LIBHIREDIS_VERSION}/${LIBHIREDIS_VERSION_FIXED:-${LIBHIREDIS_VERSION}}/g"
        "s/{LIBMNL_VERSION}/${LIBMNL_VERSION_FIXED:-${LIBMNL_VERSION}}/g"
        "s/{LIBNGHTTP2_VERSION}/${LIBNGHTTP2_VERSION_FIXED:-${LIBNGHTTP2_VERSION}}/g"
        "s/{LIBNGHTTP3_VERSION}/${LIBNGHTTP3_VERSION_FIXED:-${LIBNGHTTP3_VERSION}}/g"
        "s/{LIBNGTCP2_VERSION}/${LIBNGTCP2_VERSION_FIXED:-${LIBNGTCP2_VERSION}}/g"
        "s/{LIBSODIUM_VERSION}/${LIBSODIUM_VERSION_FIXED:-${LIBSODIUM_VERSION}}/g"
        "s/{LOBECHAT_VERSION}/${LOBECHAT_VERSION_FIXED:-${LOBECHAT_VERSION}}/g"
        "s/{OPENSSL_VERSION}/${OPENSSL_VERSION_FIXED:-${OPENSSL_VERSION}}/g"
        "s/{QBITTORRENT_VERSION}/${QBITTORRENT_VERSION_FIXED:-${QBITTORRENT_VERSION}}/g"
        "s/{RUSTFS_VERSION}/${RUSTFS_VERSION_FIXED:-${RUSTFS_VERSION}}/g"
        "s/{RUSTFS_WEB_VERSION}/${RUSTFS_WEB_VERSION_FIXED:-${RUSTFS_WEB_VERSION}}/g"
        "s/{SEARXNG_VERSION}/${SEARXNG_VERSION_FIXED:-${SEARXNG_VERSION}}/g"
        "s/{SIYUAN_VERSION}/${SIYUAN_VERSION_FIXED:-${SIYUAN_VERSION}}/g"
        "s/{UNBOUND_VERSION}/${UNBOUND_VERSION_FIXED:-${UNBOUND_VERSION}}/g"
        "s/{VALKEY_VERSION}/${VALKEY_VERSION_FIXED:-${VALKEY_VERSION}}/g"
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
