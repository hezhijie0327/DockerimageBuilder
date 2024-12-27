# Current Version: 1.2.0

FROM hezhijie0327/base:package AS get_package

FROM alpine:latest AS rebased_alpine

COPY --from=get_package /package.json /opt/package.json

RUN \
    apk update \
    && apk add --no-cache autoconf automake bash bash-completion build-base cmake curl git gnupg graphviz jq libtool linux-headers perl pkgconf py3-numpy py3-numpy-dev python3 python3-dev re2c ttf-freefont wget openssl-dev openssl-libs-static \
    && apk upgrade --no-cache \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt" \
    && sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" \
    && rm -rf /tmp/* /var/cache/apk/*

FROM scratch

COPY --from=rebased_alpine / /

CMD ["/bin/bash"]
