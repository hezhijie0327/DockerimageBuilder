# Current Version: 1.0.5

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.libhiredis" > "${WORKDIR}/libhiredis.json" \
    && cat "${WORKDIR}/libhiredis.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/libhiredis.json" | jq -Sr ".source" > "${WORKDIR}/libhiredis.autobuild"

FROM hezhijie0327/base:ubuntu AS build_libhiredis

WORKDIR /tmp

COPY --from=get_info /tmp/libhiredis.autobuild /tmp/

RUN \
    export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDTMP/LIBHIREDIS" \
    && export PREFIX="${WORKDIR}/BUILDLIB/LIBHIREDIS" && export PATH="${PREFIX}/bin:${PATH}" \
    && cd "${WORKDIR}/BUILDTMP/LIBHIREDIS" \
    && curl -Ls -o - $(cat "${WORKDIR}/libhiredis.autobuild") | tar zxvf - --strip-components=1 \
    && make -j $(nproc) \
    && make install

FROM scratch

COPY --from=build_libhiredis /tmp/BUILDLIB/LIBHIREDIS /
