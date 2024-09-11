# Current Version: 1.0.9

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".module.golang" > "${WORKDIR}/golang.json" && cat "${WORKDIR}/golang.json" | jq -Sr ".version" && cat "${WORKDIR}/golang.json" | jq -Sr ".source" | sed "s/{GOLANG_ARCH}/$(uname -m)/g;s/aarch64/arm64/g;s/x86_64/amd64/g" > "${WORKDIR}/golang.autobuild"

FROM hezhijie0327/base:alpine AS BUILD_GOLANG

WORKDIR /tmp

COPY --from=GET_INFO /tmp/golang.autobuild /tmp/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDLIB/GOLANG" && cd "${WORKDIR}/BUILDLIB/GOLANG" && curl -Ls -o - $(cat "${WORKDIR}/golang.autobuild") | tar zxvf - --strip-components=1 && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_GOLANG /tmp/BUILDLIB/GOLANG/ /
