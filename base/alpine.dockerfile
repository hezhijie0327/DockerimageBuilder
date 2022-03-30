# Current Version: 1.0.2

FROM alpine:edge

RUN sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" && apk update && apk upgrade && apk add bash curl gnupg jq wget && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt" && rm -rf /tmp/* /var/cache/apk/*

CMD ["/bin/bash"]
