# Current Version: 1.0.1

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".module.nodejs" > "${WORKDIR}/nodejs.json" && cat "${WORKDIR}/nodejs.json" | jq -Sr ".version" && cat "${WORKDIR}/nodejs.json" | jq -Sr ".source" | sed "s/{NODEJS_ARCH}/$(uname -m)/g;s/aarch64/arm64/g;s/x86_64/x64/g" > "${WORKDIR}/nodejs.autobuild"

FROM hezhijie0327/base:alpine AS BUILD_NODEJS

WORKDIR /tmp

COPY --from=GET_INFO /tmp/nodejs.autobuild /tmp/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDLIB" && cd "${WORKDIR}/BUILDLIB" && curl -Ls -o - $(cat "${WORKDIR}/nodejs.autobuild") | tar zxvf - --strip-components=1 && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_NODEJS /tmp/BUILDLIB /
