# Current Version: 1.0.3

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".module.libhiredis" > "${WORKDIR}/libhiredis.json" && cat "${WORKDIR}/libhiredis.json" | jq -Sr ".version" && cat "${WORKDIR}/libhiredis.json" | jq -Sr ".source" > "${WORKDIR}/libhiredis.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_LIBHIREDIS

WORKDIR /tmp

COPY --from=GET_INFO /tmp/libhiredis.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB/LIBHIREDIS" && export PATH="${PREFIX}/bin:${PATH}" && mkdir -p "${WORKDIR}/BUILDTMP/LIBHIREDIS" && cd "${WORKDIR}/BUILDTMP/LIBHIREDIS" && curl -Ls -o - $(cat "${WORKDIR}/libhiredis.autobuild") | tar zxvf - --strip-components=1 && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_LIBHIREDIS /tmp/BUILDLIB/LIBHIREDIS /
