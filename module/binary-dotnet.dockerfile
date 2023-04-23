# Current Version: 1.0.1

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".module.dotnet" > "${WORKDIR}/dotnet.json" && cat "${WORKDIR}/dotnet.json" | jq -Sr ".version" && cat "${WORKDIR}/dotnet.json" | jq -Sr ".source" | sed "s/{DOTNET_ARCH}/$(uname -m)/g;s/aarch64/arm64/g;s/x86_64/x64/g" > "${WORKDIR}/dotnet.autobuild"

FROM hezhijie0327/base:alpine AS BUILD_DOTNET

WORKDIR /tmp

COPY --from=GET_INFO /tmp/dotnet.autobuild /tmp/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDLIB/DOTNET" && cd "${WORKDIR}/BUILDLIB/DOTNET" && curl -Ls -o - $(cat "${WORKDIR}/dotnet.autobuild") | tar zxvf - --strip-components=1 && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_DOTNET /tmp/BUILDLIB/DOTNET /
