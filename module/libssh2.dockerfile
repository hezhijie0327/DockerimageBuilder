# Current Version: 1.0.1

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".module.libssh2" > "${WORKDIR}/libssh2.json" && cat "${WORKDIR}/libssh2.json" | jq -Sr ".version" && cat "${WORKDIR}/libssh2.json" | jq -Sr ".source" > "${WORKDIR}/libssh2.autobuild"

FROM hezhijie0327/module:openssl AS BUILD_OPENSSL

FROM hezhijie0327/base:ubuntu AS BUILD_LIBSSH2

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/libssh2.autobuild /tmp/

COPY --from=BUILD_OPENSSL / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/LIBSSH2" && cd "${WORKDIR}/BUILDTMP/LIBSSH2" && curl -Ls -o - $(cat "${WORKDIR}/libssh2.autobuild") | tar zxvf - --strip-components=1 && ./configure --disable-examples-build --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_LIBSSH2 /tmp/BUILDLIB /
