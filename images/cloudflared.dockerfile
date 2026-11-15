ARG CLOUDFLARED_VERSION=""
ARG GOLANG_VERSION="1"
ARG PATCH_SHA="0000"

FROM alpine:latest AS get_info

ARG CLOUDFLARED_VERSION
ARG PATCH_SHA

WORKDIR /tmp

RUN \
    apk add --no-cache curl git jq

RUN \
    export WORKDIR=$(pwd) \
    && export CLOUDFLARED_VERSION=${CLOUDFLARED_VERSION:-$( \
        curl -s --connect-timeout 15 "https://api.github.com/repos/cloudflare/cloudflared/git/matching-refs/tags" \
        | jq -r '[.[].ref | select(test("^refs/tags/"))] | last // "" | sub("^refs/tags/"; "")' \
    )} \
    && [ -n "${CLOUDFLARED_VERSION}" ] \
    && echo "CLOUDFLARED_VERSION=${CLOUDFLARED_VERSION}" \
    && git clone -b "master" --depth=1 "https://github.com/cloudflare/cloudflared.git" "${WORKDIR}/BUILDTMP/CLOUDFLARED" \
    && export CLOUDFLARED_SHA=$(cd "${WORKDIR}/BUILDTMP/CLOUDFLARED" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export CLOUDFLARED_CUSTOM_VERSION="${CLOUDFLARED_VERSION}-ZHIJIE-${CLOUDFLARED_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/CLOUDFLARED" \
    && echo $(uname -m | sed "s/x86_64/amd64/g;s/x86-64/amd64/g;s/amd64/amd64/g;s/aarch64/arm64/g") \
        > "${WORKDIR}/BUILDTMP/CLOUDFLARED/SYS_ARCH" \
    && sed -i \
        "s/\$(shell git describe --tags --always --match \"\[0-9\]\[0-9\]\[0-9\]\[0-9\].\*.\*\")/${CLOUDFLARED_CUSTOM_VERSION}/g" \
        "${WORKDIR}/BUILDTMP/CLOUDFLARED/Makefile" \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/ca-certificates.crt"

FROM golang:${GOLANG_VERSION} AS build_cloudflared

WORKDIR /cloudflared

COPY --from=get_info /tmp/BUILDTMP/CLOUDFLARED /cloudflared

ENV \
    CGO_ENABLED="0" \
    CONTAINER_BUILD="1"

RUN \
    export GOARCH=$(cat '/cloudflared/SYS_ARCH') \
           GOOS="linux" \
    && make cloudflared

FROM scratch AS rebased_cloudflared

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_cloudflared /cloudflared/cloudflared /cloudflared

FROM scratch

COPY --from=rebased_cloudflared / /

ENTRYPOINT ["/cloudflared"]
