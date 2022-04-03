# Current Version: 1.0.3

FROM alpine:edge

RUN sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" && apk update && apk upgrade && apk add autoconf automake bash bash-completion build-base cmake curl git gnupg graphviz jq libtool linux-headers perl pkgconf py3-numpy py3-numpy-dev python3 python3-dev re2c ttf-freefont wget && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt" && rm -rf /tmp/* /var/cache/apk/*

CMD ["/bin/bash"]
