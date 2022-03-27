# Current Version: 1.0.0

FROM alpine:edge

RUN sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" && apk update && apk upgrade && apk add bash curl jq wget && rm -rf /tmp/* /var/cache/apk/*

CMD ["/bin/bash"]
