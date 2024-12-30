# Current Version: 1.2.4

FROM alpine:latest AS rebased_alpine

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && apk update \
    && apk add --no-cache bash curl git gnupg jq openssl wget \
    && apk upgrade --no-cache \
    && git clone -b "main" --depth=1 "https://github.com/hezhijie0327/DockerimageBuilder.git" "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && cp "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/package.json" "/opt/package.json" \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt" \
    && sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" \
    && rm -rf /tmp/* /var/cache/apk/*

FROM scratch

COPY --from=rebased_alpine / /

CMD ["/bin/bash"]
