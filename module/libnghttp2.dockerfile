# Current Version: 1.0.7

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.libnghttp2" > "${WORKDIR}/libnghttp2.json" \  
    && cat "${WORKDIR}/libnghttp2.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/libnghttp2.json" | jq -Sr ".source" > "${WORKDIR}/libnghttp2.autobuild" \
    && mkdir -p "${WORKDIR}/BUILDTMP/LIBNGHTTP2" \
    && cd "${WORKDIR}/BUILDTMP/LIBNGHTTP2" \
    && curl -Ls -o - $(cat "${WORKDIR}/libnghttp2.autobuild") | tar zxvf - --strip-components=1

FROM hezhijie0327/base:ubuntu AS build_libnghttp2

WORKDIR /libnghttp2

COPY --from=get_info /tmp/BUILDTMP/LIBNGHTTP2 /libnghttp2

RUN \
    PREFIX="/BUILDLIB" \
    && export CPPFLAGS="-I$PREFIX/include" \
    && export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib -s -static --static" \
    && export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH" \
    && export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" \
    && export PATH="$PREFIX/bin:$PATH" \
    && ldconfig --verbose \
    && ./configure --enable-static --prefix="$PREFIX/LIBNGHTTP2" \
    && make -j $(nproc) \
    && make install

FROM scratch

COPY --from=build_libnghttp2 /BUILDLIB/LIBNGHTTP2 /
