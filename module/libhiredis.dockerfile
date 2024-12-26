# Current Version: 1.0.8

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.libhiredis" > "${WORKDIR}/libhiredis.json" \
    && cat "${WORKDIR}/libhiredis.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/libhiredis.json" | jq -Sr ".source" > "${WORKDIR}/libhiredis.autobuild" \
    && mkdir -p "${WORKDIR}/BUILDTMP/LIBHIREDIS" \
    && cd "${WORKDIR}/BUILDTMP/LIBHIREDIS" \
    && curl -Ls -o - $(cat "${WORKDIR}/libhiredis.autobuild") | tar zxvf - --strip-components=1

FROM hezhijie0327/module:openssl AS build_openssl

FROM hezhijie0327/base:ubuntu AS build_libhiredis

WORKDIR /libhiredis

COPY --from=get_info /tmp/BUILDTMP/LIBHIREDIS /libhiredis

COPY --from=build_openssl / /BUILDLIB/

RUN \
    PREFIX="/BUILDLIB" \
    && export CPPFLAGS="-I$PREFIX/include" \
    && export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib -s -static --static" \
    && export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH" \
    && export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" \
    && export PATH="$PREFIX/bin:$PATH" \
    && export OPENSSL_PREFIX="$PREFIX" \
    && ldconfig --verbose \
    && make -j $(nproc) USE_SSL="1" \
    && make install PREFIX="$PREFIX/LIBHIREDIS"

FROM scratch

COPY --from=build_libhiredis /BUILDLIB/LIBHIREDIS /
