# Current Version: 1.0.0

ARG GCC_VERSION="14"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.libngtcp2" > "${WORKDIR}/libngtcp2.json" \  
    && cat "${WORKDIR}/libngtcp2.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/libngtcp2.json" | jq -Sr ".source" > "${WORKDIR}/libngtcp2.autobuild" \
    && mkdir -p "${WORKDIR}/BUILDTMP/LIBNGTCP2" \
    && cd "${WORKDIR}/BUILDTMP/LIBNGTCP2" \
    && curl -Ls -o - $(cat "${WORKDIR}/libngtcp2.autobuild") | tar zxvf - --strip-components=1

FROM ghcr.io/hezhijie0327/module:openssl AS build_openssl

FROM gcc:${GCC_VERSION} AS build_libngtcp2

WORKDIR /libngtcp2

COPY --from=get_info /tmp/BUILDTMP/LIBNGTCP2 /libngtcp2

COPY --from=build_openssl / /BUILDLIB/

RUN \
    PREFIX="/BUILDLIB" \
    && export CPPFLAGS="-I$PREFIX/include" \
    && export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib -s -static --static" \
    && export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH" \
    && export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" \
    && export PATH="$PREFIX/bin:$PATH" \
    && ldconfig --verbose \
    && ./configure --enable-static --prefix="$PREFIX/LIBNGTCP2" \
    && make -j $(nproc) \
    && make install

FROM scratch

COPY --from=build_libngtcp2 /BUILDLIB/LIBNGTCP2 /
