# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".module.openssl_quic" > "${WORKDIR}/openssl.json" && cat "${WORKDIR}/openssl.json" | jq -Sr ".version" && cat "${WORKDIR}/openssl.json" | jq -Sr ".source" > "${WORKDIR}/openssl.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_OPENSSL

WORKDIR /tmp

COPY --from=GET_INFO /tmp/openssl.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/OPENSSL" && cd "${WORKDIR}/BUILDTMP/OPENSSL" && curl -Ls -o - $(cat "${WORKDIR}/openssl.autobuild") | tar zxvf - --strip-components=1 && ./config --prefix="${PREFIX}/OPENSSL" && make -j $(nproc) && make install_sw && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_OPENSSL /tmp/BUILDLIB/OPENSSL /
