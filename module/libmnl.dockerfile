# Current Version: 1.0.6

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.libmnl" > "${WORKDIR}/libmnl.json" \
    && cat "${WORKDIR}/libmnl.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/libmnl.json" | jq -Sr ".source" > "${WORKDIR}/libmnl.autobuild"

FROM hezhijie0327/base:ubuntu AS build_libmnl

WORKDIR /tmp

COPY --from=get_info /tmp/libmnl.autobuild /tmp/

RUN \
    export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDTMP/LIBMNL" \
    && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" \
    && cd "${WORKDIR}/BUILDTMP/LIBMNL" \
    && curl -Ls -o - $(cat "${WORKDIR}/libmnl.autobuild") | tar jxvf - --strip-components=1 \
    && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" \
    && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" \
    && export CPPFLAGS="-I${PREFIX}/include" \
    && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" \
    && ./configure --enable-static --prefix="${PREFIX}/LIBMNL" \
    && make -j $(nproc) \
    && make install

FROM scratch

COPY --from=build_libmnl /tmp/BUILDLIB/LIBMNL /
