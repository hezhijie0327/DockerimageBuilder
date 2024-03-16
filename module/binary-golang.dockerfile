# Current Version: 1.0.4

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".module.golang" > "${WORKDIR}/golang.json" && cat "${WORKDIR}/golang.json" | jq -Sr ".version" && cat "${WORKDIR}/golang.json" | jq -Sr ".source" | sed "s/{GOLANG_ARCH}/$(uname -m)/g;s/aarch64/arm64/g;s/x86_64/amd64/g" > "${WORKDIR}/golang.autobuild"

FROM hezhijie0327/base:alpine AS BUILD_GOLANG

WORKDIR /tmp

COPY --from=GET_INFO /tmp/golang.autobuild /tmp/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDLIB/GOLANG" && cd "${WORKDIR}/BUILDLIB/GOLANG" && curl -Ls -o - $(cat "${WORKDIR}/golang.autobuild") | tar zxvf - --strip-components=1 && cd "${WORKDIR}"

FROM hezhijie0327/base:ubuntu AS BUILD_GOLANG_CF

WORKDIR /tmp

COPY --from=BUILD_GOLANG /tmp/BUILDLIB/GOLANG /tmp/BUILDLIB

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDKIT/GOLANG_CF" "${WORKDIR}/BUILDKIT/GOLANG" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDTMP/cf" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b "cf" --depth 1 "https://github.com/cloudflare/go.git" "${WORKDIR}/BUILDTMP/go" && cd "${WORKDIR}/BUILDTMP/go/src" && bash "${WORKDIR}/BUILDTMP/go/src/make.bash" && cp -rf ${WORKDIR}/BUILDTMP/go/* "${WORKDIR}/BUILDKIT/GOLANG_CF/" && cp -rf ${WORKDIR}/BUILDLIB/* "${WORKDIR}/BUILDKIT/GOLANG/"

FROM scratch

COPY --from=BUILD_GOLANG_CF /tmp/BUILDKIT /
