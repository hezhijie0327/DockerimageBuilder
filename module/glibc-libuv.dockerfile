# Current Version: 1.0.5

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".module.libuv" > "${WORKDIR}/libuv.json" && cat "${WORKDIR}/libuv.json" | jq -Sr ".version" && cat "${WORKDIR}/libuv.json" | jq -Sr ".source" > "${WORKDIR}/libuv.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_LIBUV

WORKDIR /tmp

COPY --from=GET_INFO /tmp/libuv.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/LIBUV" && cd "${WORKDIR}/BUILDTMP/LIBUV" && curl -Ls -o - $(cat "${WORKDIR}/libuv.autobuild") | tar zxvf - --strip-components=1 && ./autogen.sh && ./configure --enable-static --prefix="${PREFIX}/LIBUV" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_LIBUV /tmp/BUILDLIB/LIBUV /
