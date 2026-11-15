ARG GOLANG_VERSION="1"
ARG PATCH_SHA="0000"
ARG XRAY_VERSION=""

FROM alpine:latest AS get_info

ARG PATCH_SHA
ARG XRAY_VERSION

WORKDIR /tmp

COPY patches/xray /tmp/patches

RUN \
    apk add --no-cache curl git jq

RUN \
    export WORKDIR=$(pwd) \
    && export XRAY_VERSION=${XRAY_VERSION:-$( \
        curl -s --connect-timeout 15 "https://api.github.com/repos/XTLS/Xray-core/git/matching-refs/tags" \
        | jq -r '[.[].ref | select(test("^refs/tags/v(?!.*-)"))] | last // "" | sub("^refs/tags/v"; "")' \
    )} \
    && [ -n "${XRAY_VERSION}" ] \
    && echo "XRAY_VERSION=${XRAY_VERSION}" \
    && git clone -b "main" --depth=1 "https://github.com/XTLS/Xray-core.git" "${WORKDIR}/BUILDTMP/XRAY" \
    && export XRAY_SHA=$(cd "${WORKDIR}/BUILDTMP/XRAY" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export XRAY_CUSTOM_VERSION="${XRAY_VERSION}-ZHIJIE-${XRAY_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/XRAY" \
    && git apply --reject ${WORKDIR}/patches/*.patch \
    && sed -i \
        "s/Version_x, Version_y, Version_z/\"$(echo ${XRAY_CUSTOM_VERSION} | cut -d '.' -f 1)\", \"$(echo ${XRAY_CUSTOM_VERSION} | cut -d '.' -f 2)\", \"$(echo ${XRAY_CUSTOM_VERSION} | cut -d '.' -f 3)\"/g" \
        "${WORKDIR}/BUILDTMP/XRAY/core/core.go" \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/ca-certificates.crt"

FROM golang:${GOLANG_VERSION} AS build_xray

WORKDIR /xray

COPY --from=get_info /tmp/BUILDTMP/XRAY /xray

ENV \
    CGO_ENABLED="0"

RUN \
    go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main

FROM scratch AS rebased_xray

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_xray /xray/xray /xray

FROM scratch

ENV \
    XRAY_LOCATION_ASSET="/config"

COPY --from=rebased_xray / /

ENTRYPOINT ["/xray"]
