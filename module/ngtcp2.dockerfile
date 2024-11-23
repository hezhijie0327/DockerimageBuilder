# Current Version: 1.0.5

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".module.ngtcp2" > "${WORKDIR}/ngtcp2.json" && cat "${WORKDIR}/ngtcp2.json" | jq -Sr ".version" && cat "${WORKDIR}/ngtcp2.json" | jq -Sr ".source" > "${WORKDIR}/ngtcp2.autobuild"

FROM hezhijie0327/module:jemalloc AS BUILD_JEMALLOC

FROM hezhijie0327/module:quictls AS BUILD_QUICTLS

FROM hezhijie0327/base:ubuntu AS BUILD_NGTCP2

WORKDIR /tmp

COPY --from=GET_INFO /tmp/ngtcp2.autobuild /tmp/

COPY --from=BUILD_JEMALLOC / /tmp/BUILDLIB/

COPY --from=BUILD_QUICTLS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s" && mkdir -p "${WORKDIR}/BUILDTMP/NGTCP2" && cd "${WORKDIR}/BUILDTMP/NGTCP2" && curl -Ls -o - $(cat "${WORKDIR}/ngtcp2.autobuild") | tar zxvf - --strip-components=1 && autoreconf -i && ./configure --disable-shared --enable-asan --enable-static --enable-year2038 --prefix=${PREFIX}/NGTCP2 --with-jemalloc && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_NGTCP2 /tmp/BUILDLIB/NGTCP2 /
