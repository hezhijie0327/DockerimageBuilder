# Current Version: 1.0.1

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".module.ngtcp2" > "${WORKDIR}/ngtcp2.json" && cat "${WORKDIR}/ngtcp2.json" | jq -Sr ".version" && cat "${WORKDIR}/ngtcp2.json" | jq -Sr ".source" > "${WORKDIR}/ngtcp2.autobuild"

FROM hezhijie0327/module:glibc-openssl-quic AS BUILD_OPENSSL

FROM hezhijie0327/base:ubuntu AS BUILD_NGTCP2

WORKDIR /tmp

COPY --from=GET_INFO /tmp/ngtcp2.autobuild /tmp/

COPY --from=BUILD_OPENSSL / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/NGTCP2" && cd "${WORKDIR}/BUILDTMP/NGTCP2" && curl -Ls -o - $(cat "${WORKDIR}/ngtcp2.autobuild") | tar zxvf - --strip-components=1 && autoreconf -i && ./configure --prefix="${PREFIX}/NGTCP2" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_NGTCP2 /tmp/BUILDLIB/NGTCP2 /
