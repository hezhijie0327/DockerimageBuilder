# Current Version: 1.0.2

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".module.zlib_ng" > "${WORKDIR}/zlib_ng.json" && cat "${WORKDIR}/zlib_ng.json" | jq -Sr ".version" && cat "${WORKDIR}/zlib_ng.json" | jq -Sr ".source" > "${WORKDIR}/zlib_ng.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_ZLIB_NG

WORKDIR /tmp

COPY --from=GET_INFO /tmp/zlib_ng.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/ZLIB_NG" && cd "${WORKDIR}/BUILDTMP/ZLIB_NG" && curl -Ls -o - $(cat "${WORKDIR}/zlib_ng.autobuild") | tar zxvf - --strip-components=1 && ./configure --prefix="${PREFIX}" --static --zlib-compat && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_ZLIB_NG /tmp/BUILDLIB /
