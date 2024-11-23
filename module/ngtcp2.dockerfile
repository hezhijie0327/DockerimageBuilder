# Current Version: 1.0.2

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".module.ngtcp2" > "${WORKDIR}/ngtcp2.json" && cat "${WORKDIR}/ngtcp2.json" | jq -Sr ".version" && cat "${WORKDIR}/ngtcp2.json" | jq -Sr ".source" > "${WORKDIR}/ngtcp2.autobuild"

FROM hezhijie0327/module:jemalloc AS BUILD_JEMALLOC

FROM hezhijie0327/module:nghttp3 AS BUILD_NGHTTP3

FROM hezhijie0327/module:quictls AS BUILD_QUICTLS

FROM hezhijie0327/base:ubuntu AS BUILD_NGTCP2

WORKDIR /tmp

COPY --from=GET_INFO /tmp/ngtcp2.autobuild /tmp/

COPY --from=BUILD_JEMALLOC / /tmp/BUILDLIB/

COPY --from=BUILD_NGHTTP3 / /tmp/BUILDLIB/

COPY --from=BUILD_QUICTLS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB/NGTCP2" && export PATH="${PREFIX}/bin:${PATH}" && mkdir -p "${WORKDIR}/BUILDTMP/NGTCP2" && cd "${WORKDIR}/BUILDTMP/NGTCP2" && curl -Ls -o - $(cat "${WORKDIR}/ngtcp2.autobuild") | tar zxvf - --strip-components=1 && autoreconf -i && ./configure --disable-shared --enable-asan --enable-static --enable-year2038 --prefix=${PREFIX} --with-jemalloc --with-libev --with-libnghttp3 && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_NGTCP2 /tmp/BUILDLIB/NGTCP2 /
