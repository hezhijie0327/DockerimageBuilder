# Current Version: 1.0.1

FROM alpine:latest AS BUILD_PACKAGE

WORKDIR /tmp

RUN export WORKDIR=$(pwd) \
    && sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" \
    && apk update \
    && apk add --no-cache git \
    && git clone -b "main" --depth=1 "https://github.com/hezhijie0327/DockerimageBuilder.git" "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER"

FROM scratch

COPY --from=BUILD_PACKAGE /tmp/BUILDTMP/DOCKERIMAGEBUILDER/patch/package.json /package.json
