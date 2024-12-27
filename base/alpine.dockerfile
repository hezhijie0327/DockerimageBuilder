# Current Version: 1.2.1

FROM alpine:latest AS rebased_alpine

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && apk update \
    && apk add --no-cache bash curl git gnupg jq wget \
    && apk upgrade --no-cache \
    && git clone -b "main" --depth=1 "https://github.com/hezhijie0327/DockerimageBuilder.git" "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && cp "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/package.json" "/opt/package.json" \
    && sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" \
    && rm -rf /tmp/* /var/cache/apk/*

FROM scratch

COPY --from=rebased_alpine / /

CMD ["/bin/bash"]
