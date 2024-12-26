# Current Version: 1.0.2

FROM alpine:latest AS build_package

WORKDIR /tmp

RUN export WORKDIR=$(pwd) \
    && sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" \
    && apk update \
    && apk add --no-cache git \
    && git clone -b "main" --depth=1 "https://github.com/hezhijie0327/DockerimageBuilder.git" "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER"

FROM scratch

COPY --from=build_package /tmp/BUILDTMP/DOCKERIMAGEBUILDER/patch/package.json /package.json
