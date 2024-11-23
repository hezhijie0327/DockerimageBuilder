# Current Version: 1.0.4

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".module.libevent" > "${WORKDIR}/libevent.json" && cat "${WORKDIR}/libevent.json" | jq -Sr ".version" && cat "${WORKDIR}/libevent.json" | jq -Sr ".source" > "${WORKDIR}/libevent.autobuild"

FROM hezhijie0327/module:openssl AS BUILD_OPENSSL

FROM hezhijie0327/base:ubuntu AS BUILD_LIBEVENT

WORKDIR /tmp

COPY --from=GET_INFO /tmp/libevent.autobuild /tmp/

COPY --from=BUILD_OPENSSL / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/LIBEVENT" && cd "${WORKDIR}/BUILDTMP/LIBEVENT" && curl -Ls -o - $(cat "${WORKDIR}/libevent.autobuild") | tar zxvf - --strip-components=1 && ./configure --enable-static --prefix="${PREFIX}/LIBEVENT" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_LIBEVENT /tmp/BUILDLIB/LIBEVENT /
