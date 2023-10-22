# Current Version: 1.1.3

FROM alpine:latest AS REBASED_ALPINE

RUN apk update \
    && apk add --no-cache autoconf automake bash bash-completion build-base cmake curl git gnupg graphviz jq libtool linux-headers perl pkgconf py3-numpy py3-numpy-dev python3 python3-dev re2c ttf-freefont wget \
    && apk upgrade --no-cache \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt" \
    && sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" \
    && rm -rf /tmp/* /var/cache/apk/*

FROM scratch

COPY --from=REBASED_ALPINE / /

CMD ["/bin/bash"]
