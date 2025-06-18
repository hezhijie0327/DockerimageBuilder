# Current Version: 1.1.4

ARG GCC_VERSION="14"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.openssl" > "${WORKDIR}/openssl.json" \
    && cat "${WORKDIR}/openssl.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/openssl.json" | jq -Sr ".source" > "${WORKDIR}/openssl.autobuild" \
    && mkdir -p "${WORKDIR}/BUILDTMP/OPENSSL" \
    && cd "${WORKDIR}/BUILDTMP/OPENSSL" \
    && curl -Ls -o - $(cat "${WORKDIR}/openssl.autobuild") | tar zxvf - --strip-components=1

FROM gcc:${GCC_VERSION} AS build_openssl

WORKDIR /openssl

COPY --from=get_info /tmp/BUILDTMP/OPENSSL /openssl

RUN \
    PREFIX="/BUILDLIB" \
    && export CPPFLAGS="-I$PREFIX/include" \
    && export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib -s -static --static" \
    && export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH" \
    && export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" \
    && export PATH="$PREFIX/bin:$PATH" \
    && ldconfig --verbose \
    && ./config --prefix="$PREFIX/OPENSSL" --static enable-ktls enable-quic enable-tls1_3 \
    && make -j $(nproc) \
    && make install_sw

FROM scratch

COPY --from=build_openssl /BUILDLIB/OPENSSL /
