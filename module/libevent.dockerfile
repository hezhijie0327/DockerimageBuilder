# Current Version: 1.0.8

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.libevent" > "${WORKDIR}/libevent.json" \
    && cat "${WORKDIR}/libevent.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/libevent.json" | jq -Sr ".source" > "${WORKDIR}/libevent.autobuild" \
    && mkdir -p "${WORKDIR}/BUILDTMP/LIBEVENT" \
    && cd "${WORKDIR}/BUILDTMP/LIBEVENT" \
    && curl -Ls -o - $(cat "${WORKDIR}/libevent.autobuild") | tar zxvf - --strip-components=1

FROM hezhijie0327/module:openssl AS build_openssl

FROM hezhijie0327/base:ubuntu AS build_libevent

WORKDIR /libevent

COPY --from=get_info /tmp/BUILDTMP/LIBEVENT /libevent

COPY --from=build_openssl / /BUILDLIB/

RUN \
    PREFIX="/BUILDLIB" \
    && export CPPFLAGS="-I$PREFIX/include" \
    && export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib -s -static --static" \
    && export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH" \
    && export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" \
    && export PATH="$PREFIX/bin:$PATH" \
    && ldconfig --verbose \
    && ./configure --enable-static --prefix="${PREFIX}/LIBEVENT" \
    && make -j $(nproc) \
    && make install

FROM scratch

COPY --from=build_libevent /BUILDLIB/LIBEVENT /
