# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".module.nghttp2" > "${WORKDIR}/nghttp2.json" && cat "${WORKDIR}/nghttp2.json" | jq -Sr ".version" && cat "${WORKDIR}/nghttp2.json" | jq -Sr ".source" > "${WORKDIR}/nghttp2.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_NGHTTP2

WORKDIR /tmp

COPY --from=GET_INFO /tmp/nghttp2.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/NGHTTP2" && cd "${WORKDIR}/BUILDTMP/NGHTTP2" && curl -Ls -o - $(cat "${WORKDIR}/nghttp2.autobuild") | tar zxvf - --strip-components=1 && ./configure --enable-static --prefix="${PREFIX}/NGHTTP2" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_NGHTTP2 /tmp/BUILDLIB/NGHTTP2 /
