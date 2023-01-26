# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://proxy.zhijie.online/https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".module.dotnet" > "${WORKDIR}/dotnet.json" && cat "${WORKDIR}/dotnet.json" | jq -Sr ".version" && cat "${WORKDIR}/dotnet.json" | jq -Sr ".source" | sed "s/{DOTNET_ARCH}/$(uname -m)/g;s/aarch64/arm64/g;s/x86_64/amd64/g" > "${WORKDIR}/dotnet.autobuild"

FROM hezhijie0327/base:alpine AS BUILD_DOTNET

WORKDIR /tmp

COPY --from=GET_INFO /tmp/dotnet.autobuild /tmp/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDLIB/DOTNET" && cd "${WORKDIR}/BUILDLIB/DOTNET" && curl -Ls -o - $(cat "${WORKDIR}/dotnet.autobuild") | tar zxvf - --strip-components=1 && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_DOTNET /tmp/BUILDLIB/DOTNET /
