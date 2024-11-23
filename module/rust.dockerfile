# Current Version: 1.0.1

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".module.rust" > "${WORKDIR}/rust.json" && cat "${WORKDIR}/rust.json" | jq -Sr ".version" && cat "${WORKDIR}/rust.json" | jq -Sr ".source" | sed "s/{RUST_ARCH}/$(uname -m)/g" > "${WORKDIR}/rust.autobuild"

FROM hezhijie0327/base:alpine AS BUILD_RUST

WORKDIR /tmp

COPY --from=GET_INFO /tmp/rust.autobuild /tmp/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDLIB/RUST" && cd "${WORKDIR}/BUILDLIB/RUST" && curl -Ls -o - $(cat "${WORKDIR}/rust.autobuild") | tar zxvf - --strip-components=1 && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_RUST /tmp/BUILDLIB/RUST /
