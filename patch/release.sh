#!/bin/bash

# Current Version: 1.1.6

## How to get and use?
# git clone "https://github.com/hezhijie0327/DockerimageBuilder.git" && bash ./DockerimageBuilder/patch/release.sh

## Parameter
export ADGUARDHOME_VERSION_FIXED=""
export ARIA2_VERSION_FIXED=""
export CADDY_VERSION_FIXED=""
export CLASH_VERSION_FIXED=""
export C_ARES_VERSION_FIXED=""
export DNSPROXY_VERSION_FIXED=""
export DOTNET_VERSION_FIXED=""
export EXPAT_VERSION_FIXED=""
export GOLANG_VERSION_FIXED=""
export GPERFTOOLS_VERSION_FIXED="2.10"
export JELLYFIN_BRANCH_FIXED=""
export JELLYFIN_VERSION_FIXED=""
export LIBSSH2_VERSION_FIXED=""
export LIBUV_VERSION_FIXED=""
export MOSDNS_VERSION_FIXED=""
export NODEJS_VERSION_FIXED=""
export OPENSSL_VERSION_FIXED=""
export SQLITE_VERSION_FIXED=""
export SQLITE_YEAR_FIXED=""
export V2RAY_VERSION_FIXED=""
export ZLIB_NG_VERSION_FIXED=""

## Function
# Get Latest Version
function GetLatestVersion() {
    ADGUARDHOME_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/AdguardTeam/AdGuardHome/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "-" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    ARIA2_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/aria2/aria2/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/release\-" | tail -n 1 | sed "s/refs\/tags\/release\-//")
    CADDY_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/caddyserver/caddy/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "\-" | tail -n 1 | sed "s/refs\/tags\/v//")
    CLASH_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/Dreamacro/clash/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    C_ARES_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/c-ares/c-ares/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/cares\-" | tail -n 1 | sed "s/refs\/tags\/cares\-//" | tr "_" ".")
    DNSPROXY_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/AdguardTeam/dnsproxy/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "-" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    DOTNET_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/dotnet/sdk/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "-" | grep "v6" | tail -n 1 | sed "s/refs\/tags\/v//" | tr "_" ".")
    EXPAT_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/libexpat/libexpat/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/R\_" | tail -n 1 | sed "s/refs\/tags\/R\_//" | tr "_" ".")
    GOLANG_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/golang/go/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "beta\|rc\|[a-z]$" | grep "^refs/tags/go" | tail -n 1 | sed "s/refs\/tags\/go//")
    GPERFTOOLS_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/gperftools/gperftools/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/gperftools\-" | tail -n 1 | sed "s/refs\/tags\/gperftools\-//")
    JELLYFIN_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/jellyfin/jellyfin/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | grep -v "-" | tail -n 1 | sed "s/refs\/tags\/v//")
    LIBSSH2_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/libssh2/libssh2/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/libssh2\-" | tail -n 1 | sed "s/refs\/tags\/libssh2\-//")
    LIBUV_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/libuv/libuv/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    MOSDNS_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/IrineSistiana/mosdns/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "-" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    NODEJS_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/nodejs/node/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "\-" | grep "^refs/tags/v" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    OPENSSL_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/openssl/openssl/git/matching-refs/tags" | jq -Sr ".[].ref" | grep -v "alpha\|beta\|pre" | grep "^refs/tags/OpenSSL\_1\|^refs/tags/openssl\-3" | sort | tail -n 1 | sed "s/refs\/tags\/OpenSSL\_//;s/refs\/tags\/openssl\-//" | tr "_" ".")
    SQLITE_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/sqlite/sqlite/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/version\-" | tail -n 1 | sed "s/refs\/tags\/version\-//")
    SQLITE_YEAR=$(curl -s --connect-timeout 15 $(curl -s --connect-timeout 15 'https://api.github.com/repos/sqlite/sqlite/git/matching-refs/tags' | jq -Sr '.[].object.url' | tail -n 1) | jq -Sr '.committer.date' | cut -d '-' -f 1)
    V2RAY_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/v2fly/v2ray-core/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/v" | tail -n 1 | sed "s/refs\/tags\/v//")
    ZLIB_NG_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/zlib-ng/zlib-ng/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/[0-9]" | grep -v "\-" | tail -n 1 | sed "s/refs\/tags\///")
}
# Generate Replacements
function GenerateReplacements() {
    replacement_list=(
        "s/{ADGUARDHOME_VERSION}/${ADGUARDHOME_VERSION_FIXED:-${ADGUARDHOME_VERSION}}/g"
        "s/{ARIA2_VERSION}/${ARIA2_VERSION_FIXED:-${ARIA2_VERSION}}/g"
        "s/{CADDY_VERSION}/${CADDY_VERSION_FIXED:-${CADDY_VERSION}}/g"
        "s/{CLASH_VERSION}/${CLASH_VERSION_FIXED:-${CLASH_VERSION}}/g"
        "s/{C_ARES_VERSION}/${C_ARES_VERSION_FIXED:-${C_ARES_VERSION}}/g"
        "s/{DNSPROXY_VERSION}/${DNSPROXY_VERSION_FIXED:-${DNSPROXY_VERSION}}/g"
        "s/{DOTNET_VERSION}/${DOTNET_VERSION_FIXED:-${DOTNET_VERSION}}/g"
        "s/{EXPAT_VERSION_}/$(echo ${EXPAT_VERSION_FIXED:-${EXPAT_VERSION}} | tr '.' '_')/g"
        "s/{EXPAT_VERSION}/${EXPAT_VERSION_FIXED:-${EXPAT_VERSION}}/g"
        "s/{GOLANG_VERSION}/${GOLANG_VERSION_FIXED:-${GOLANG_VERSION}}/g"
        "s/{GPERFTOOLS_VERSION}/${GPERFTOOLS_VERSION_FIXED:-${GPERFTOOLS_VERSION}}/g"
        "s/{JELLYFIN_BRANCH}/${JELLYFIN_BRANCH_FIXED:-${JELLYFIN_VERSION%?}z}/g"
        "s/{JELLYFIN_VERSION}/${JELLYFIN_VERSION_FIXED:-${JELLYFIN_VERSION}}/g"
        "s/{LIBSSH2_VERSION}/${LIBSSH2_VERSION_FIXED:-${LIBSSH2_VERSION}}/g"
        "s/{LIBUV_VERSION}/${LIBUV_VERSION_FIXED:-${LIBUV_VERSION}}/g"
        "s/{MOSDNS_VERSION}/${MOSDNS_VERSION_FIXED:-${MOSDNS_VERSION}}/g"
        "s/{NODEJS_VERSION}/${NODEJS_VERSION_FIXED:-${NODEJS_VERSION}}/g"
        "s/{OPENSSL_VERSION}/${OPENSSL_VERSION_FIXED:-${OPENSSL_VERSION}}/g"
        "s/{SQLITE_VERSION_}/$(echo ${SQLITE_VERSION_FIXED:-${SQLITE_VERSION}} | cut -d '.' -f 1)$(echo ${SQLITE_VERSION_FIXED:-${SQLITE_VERSION}} | cut -d '.' -f 2)0$(echo ${SQLITE_VERSION_FIXED:-${SQLITE_VERSION}} | cut -d '.' -f 3)00/g"
        "s/{SQLITE_VERSION}/${SQLITE_VERSION_FIXED:-${SQLITE_VERSION}}/g"
        "s/{SQLITE_YEAR}/${SQLITE_YEAR_FIXED:-${SQLITE_YEAR}}/g"
        "s/{V2RAY_VERSION}/${V2RAY_VERSION_FIXED:-${V2RAY_VERSION}}/g"
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

## Process
# Call GetLatestVersion
GetLatestVersion
# Call GenerateReplacements
GenerateReplacements
# Call OutputPackage
OutputPackage
