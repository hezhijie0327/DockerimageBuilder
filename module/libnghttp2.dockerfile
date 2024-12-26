# Current Version: 1.0.5

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.libnghttp2" > "${WORKDIR}/libnghttp2.json" \  
    && cat "${WORKDIR}/libnghttp2.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/libnghttp2.json" | jq -Sr ".source" > "${WORKDIR}/libnghttp2.autobuild"

FROM hezhijie0327/base:ubuntu AS build_libnghttp2

WORKDIR /tmp

COPY --from=get_info /tmp/libnghttp2.autobuild /tmp/

RUN \
    export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDTMP/LIBNGHTTP2" \
    && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" \
    && cd "${WORKDIR}/BUILDTMP/LIBNGHTTP2" \
    && curl -Ls -o - $(cat "${WORKDIR}/libnghttp2.autobuild") | tar zxvf - --strip-components=1 \
    && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" \
    && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" \
    && export CPPFLAGS="-I${PREFIX}/include" \
    && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" \
    && ./configure --enable-static --prefix="${PREFIX}/LIBNGHTTP2" \
    && make -j $(nproc) \
    && make install

FROM scratch

COPY --from=build_libnghttp2 /tmp/BUILDLIB/LIBNGHTTP2 /
