#!/bin/bash

# Current Version: 1.9.5

## How to get and use?
# git clone "https://github.com/hezhijie0327/DockerimageBuilder.git" && bash ./DockerimageBuilder/patch/release.sh

## Parameter
export ADGUARDHOME_VERSION_FIXED=""
export ALIST_VERSION_FIXED=""
export ARIA2_VERSION_FIXED=""
export CLOUDFLARED_VERSION_FIXED=""
export DNSPROXY_VERSION_FIXED=""
export DOTNET_VERSION_FIXED=""
export EXPAT_VERSION_FIXED=""
export GOLANG_VERSION_FIXED=""
export HAPROXY_VERSION_FIXED=""
export JELLYFIN_VERSION_FIXED=""
export JELLYFIN_WEB_VERSION_FIXED=""
export LIBEVENT_VERSION_FIXED=""
export LIBHIREDIS_VERSION_FIXED=""
export LIBMNL_VERSION_FIXED=""
export LIBNGHTTP2_VERSION_FIXED=""
export LIBSODIUM_VERSION_FIXED=""
export LOBECHAT_VERSION_FIXED=""
export LUA_VERSION_FIXED=""
export MINIO_VERSION_FIXED=""
export NODEJS_VERSION_FIXED=""
export OPENSSL_VERSION_FIXED=""
export PCRE2_VERSION_FIXED=""
export QBITTORRENT_VERSION_FIXED=""
export RUST_VERSION_FIXED=""
export SEARXNG_VERSION_FIXED=""
export SIYUAN_VERSION_FIXED=""
export UNBOUND_VERSION_FIXED=""
export VALKEY_VERSION_FIXED=""
export VAULTWARDEN_VERSION_FIXED=""
export XRAY_VERSION_FIXED=""
export ZLIB_NG_VERSION_FIXED=""

## Function
# Get Latest Version
function GetLatestVersion() {
    ADGUARDHOME_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/AdguardTeam/AdGuardHome/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "-" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    ALIST_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/AlistGo/alist/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "-" | tail -n 1 | sed "s/refs\/tags\/v//")
    CLOUDFLARED_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/cloudflare/cloudflared/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/" | tail -n 1 | sed "s/refs\/tags\///")
    DNSPROXY_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/AdguardTeam/dnsproxy/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "-" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    DOTNET_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/dotnet/sdk/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "-" | tail -n 1 | sed "s/refs\/tags\/v//" | tr "_" ".")
    EXPAT_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/libexpat/libexpat/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/R\_" | tail -n 1 | sed "s/refs\/tags\/R\_//" | tr "_" ".")
    GOLANG_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/golang/go/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "beta\|rc\|[a-z]$" | grep "^refs/tags/go" | tail -n 1 | sed "s/refs\/tags\/go//")
    HAPROXY_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/haproxy/haproxy/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "-" | tail -n 1 | sed "s/refs\/tags\/v//")
    JELLYFIN_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/jellyfin/jellyfin/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "-" | tail -n 1 | sed "s/refs\/tags\/v//")
    JELLYFIN_WEB_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/jellyfin/jellyfin-web/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "-" | tail -n 1 | sed "s/refs\/tags\/v//")
    LIBEVENT_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/libevent/libevent/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/release\-" | grep "stable$" | tail -n 1 | sed "s/refs\/tags\/release\-//;s/\-stable//")
    LIBHIREDIS_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/redis/hiredis/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "rc" | tail -n 1 | sed "s/refs\/tags\/v//")
    LIBMNL_VERSION=$(curl -s --connect-timeout 15 "https://git.netfilter.org/libmnl/log" | grep 'release' | cut -d '<' -f 6 | cut -d ' ' -f 4 | head -n 1)
    LIBNGHTTP2_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/nghttp2/nghttp2/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    LIBSODIUM_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/jedisct1/libsodium/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags" | grep "\-RELEASE" | tail -n 1 | sed "s/refs\/tags\///;s/-RELEASE//")
    LOBECHAT_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/lobehub/lobe-chat/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    LUA_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/lua/lua/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "alpha\|beta" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    MINIO_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/minio/minio/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/RELEASE\." | tail -n 1 | sed "s/refs\/tags\/RELEASE\.//")
    NODEJS_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/nodejs/node/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "\-" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    OPENSSL_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/openssl/openssl/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "alpha\|beta\|pre" | grep "^refs/tags/OpenSSL\_1\|^refs/tags/openssl\-3" | sort | tail -n 1 | sed "s/refs\/tags\/OpenSSL\_//;s/refs\/tags\/openssl\-//" | tr "_" ".")
    PCRE2_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/PCRE2Project/pcre2/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "RC" | grep "^refs/tags/pcre2-" | tail -n 1 | sed "s/refs\/tags\/pcre2\-//")
    QBITTORRENT_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/qbittorrent/qBittorrent/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "alpha\|beta\|rc" | grep "^refs/tags/release-" | tail -n 1 | sed "s/refs\/tags\/release\-//")
    RUST_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/rust-lang/rust/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/" | tail -n 1 | sed "s/refs\/tags\///")
    SEARXNG_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/searxng/searxng/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    SIYUAN_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/siyuan-note/siyuan/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "\-dev" | tail -n 1 | sed "s/refs\/tags\/v//")
    UNBOUND_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/NLnetLabs/unbound/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "rc" | grep "^refs/tags/release\-" | tail -n 1 | sed "s/refs\/tags\/release\-//")
    VALKEY_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/valkey-io/valkey/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/" | grep -v "\-" | tail -n 1 | sed "s/refs\/tags\///")
    VAULTWARDEN_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/dani-garcia/vaultwarden/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/" | tail -n 1 | sed "s/refs\/tags\///")
    XRAY_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/XTLS/Xray-core/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "-" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    ZLIB_NG_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/zlib-ng/zlib-ng/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/[0-9]" | grep -v "\-" | tail -n 1 | sed "s/refs\/tags\///")
}
# Generate Replacements
function GenerateReplacements() {
    replacement_list=(
        "s/{ADGUARDHOME_VERSION}/${ADGUARDHOME_VERSION_FIXED:-${ADGUARDHOME_VERSION}}/g"
        "s/{ALIST_VERSION}/${ALIST_VERSION_FIXED:-${ALIST_VERSION}}/g"
        "s/{CLOUDFLARED_VERSION}/${CLOUDFLARED_VERSION_FIXED:-${CLOUDFLARED_VERSION}}/g"
        "s/{DNSPROXY_VERSION}/${DNSPROXY_VERSION_FIXED:-${DNSPROXY_VERSION}}/g"
        "s/{DOTNET_VERSION}/${DOTNET_VERSION_FIXED:-${DOTNET_VERSION}}/g"
        "s/{EXPAT_VERSION_}/$(echo ${EXPAT_VERSION_FIXED:-${EXPAT_VERSION}} | tr '.' '_')/g"
        "s/{EXPAT_VERSION}/${EXPAT_VERSION_FIXED:-${EXPAT_VERSION}}/g"
        "s/{GOLANG_VERSION}/${GOLANG_VERSION_FIXED:-${GOLANG_VERSION}}/g"
        "s/{HAPROXY_VERSION}/${HAPROXY_VERSION_FIXED:-${HAPROXY_VERSION}}/g"
        "s/{JELLYFIN_VERSION}/${JELLYFIN_VERSION_FIXED:-${JELLYFIN_VERSION}}/g"
        "s/{JELLYFIN_WEB_VERSION}/${JELLYFIN_WEB_VERSION_FIXED:-${JELLYFIN_WEB_VERSION}}/g"
        "s/{LIBEVENT_VERSION}/${LIBEVENT_VERSION_FIXED:-${LIBEVENT_VERSION}}/g"
        "s/{LIBHIREDIS_VERSION}/${LIBHIREDIS_VERSION_FIXED:-${LIBHIREDIS_VERSION}}/g"
        "s/{LIBMNL_VERSION}/${LIBMNL_VERSION_FIXED:-${LIBMNL_VERSION}}/g"
        "s/{LIBNGHTTP2_VERSION}/${LIBNGHTTP2_VERSION_FIXED:-${LIBNGHTTP2_VERSION}}/g"
        "s/{LIBSODIUM_VERSION}/${LIBSODIUM_VERSION_FIXED:-${LIBSODIUM_VERSION}}/g"
        "s/{LOBECHAT_VERSION}/${LOBECHAT_VERSION_FIXED:-${LOBECHAT_VERSION}}/g"
        "s/{LUA_VERSION}/${LUA_VERSION_FIXED:-${LUA_VERSION}}/g"
        "s/{MINIO_VERSION}/${MINIO_VERSION_FIXED:-${MINIO_VERSION}}/g"
        "s/{NODEJS_VERSION}/${NODEJS_VERSION_FIXED:-${NODEJS_VERSION}}/g"
        "s/{OPENSSL_VERSION}/${OPENSSL_VERSION_FIXED:-${OPENSSL_VERSION}}/g"
        "s/{PCRE2_VERSION}/${PCRE2_VERSION_FIXED:-${PCRE2_VERSION}}/g"
        "s/{QBITTORRENT_VERSION}/${QBITTORRENT_VERSION_FIXED:-${QBITTORRENT_VERSION}}/g"
        "s/{RUST_VERSION}/${RUST_VERSION_FIXED:-${RUST_VERSION}}/g"
        "s/{SEARXNG_VERSION}/${SEARXNG_VERSION_FIXED:-${SEARXNG_VERSION}}/g"
        "s/{SIYUAN_VERSION}/${SIYUAN_VERSION_FIXED:-${SIYUAN_VERSION}}/g"
        "s/{UNBOUND_VERSION}/${UNBOUND_VERSION_FIXED:-${UNBOUND_VERSION}}/g"
        "s/{VALKEY_VERSION}/${VALKEY_VERSION_FIXED:-${VALKEY_VERSION}}/g"
        "s/{VAULTWARDEN_VERSION}/${VAULTWARDEN_VERSION_FIXED:-${VAULTWARDEN_VERSION}}/g"
        "s/{XRAY_VERSION}/${XRAY_VERSION_FIXED:-${XRAY_VERSION}}/g"
        "s/{ZLIB_NG_VERSION}/${ZLIB_NG_VERSION_FIXED:-${ZLIB_NG_VERSION}}/g"
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
# Sync Other Files
function SyncOtherFiles() {
    if [ ! -d "./patch/adguardhome/static" ]; then
        mkdir -p "./patch/adguardhome/static"
    fi && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/client/src/__locales/en.json" | jq -Sr . > "./patch/adguardhome/static/en-us.json"
}

## Process
# Call GetLatestVersion
GetLatestVersion
# Call GenerateReplacements
GenerateReplacements
# Call OutputPackage
OutputPackage
# Call SyncOtherFiles
SyncOtherFiles
