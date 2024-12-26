# Current Version: 1.0.7

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.openssl" > "${WORKDIR}/openssl.json" \
    && cat "${WORKDIR}/openssl.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/openssl.json" | jq -Sr ".source" > "${WORKDIR}/openssl.autobuild"

FROM hezhijie0327/base:ubuntu AS build_openssl

WORKDIR /tmp

COPY --from=get_info /tmp/openssl.autobuild /tmp/

RUN \
    export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDTMP/OPENSSL" \
    && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" \
    && cd "${WORKDIR}/BUILDTMP/OPENSSL" \
    && curl -Ls -o - $(cat "${WORKDIR}/openssl.autobuild") | tar zxvf - --strip-components=1 \
    && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" \
    && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" \
    && export CPPFLAGS="-I${PREFIX}/include" \
    && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" \
    && ./config --prefix="${PREFIX}/OPENSSL" \
    && make -j $(nproc) \
    && make install_sw

FROM scratch

COPY --from=build_openssl /tmp/BUILDLIB/OPENSSL /
