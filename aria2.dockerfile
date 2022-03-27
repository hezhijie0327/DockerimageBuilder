# Current Version: 1.5.8

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".aria2c" > "${WORKDIR}/aria2c.json" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.version" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.c_ares" > "${WORKDIR}/c_ares.autobuild" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.expat" > "${WORKDIR}/expat.autobuild" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.gperftools" > "${WORKDIR}/gperftools.autobuild" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.libssh2" > "${WORKDIR}/libssh2.autobuild" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.libuv" > "${WORKDIR}/libuv.autobuild" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.openssl" > "${WORKDIR}/openssl.autobuild" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.sqlite" > "${WORKDIR}/sqlite.autobuild" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.zlib_ng" > "${WORKDIR}/zlib_ng.autobuild" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".source" > "${WORKDIR}/aria2c.source.autobuild" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".patch" > "${WORKDIR}/aria2c.patch.autobuild" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".version" > "${WORKDIR}/aria2c.version.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_C_ARES

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/c_ares.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/C_ARES" && cd "${WORKDIR}/BUILDTMP/C_ARES" && curl -Ls -o - $(cat "${WORKDIR}/c_ares.autobuild") | tar zxvf - --strip-components=1 && ./configure --disable-tests --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM hezhijie0327/base:ubuntu AS BUILD_EXPAT

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/expat.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/EXPAT" && cd "${WORKDIR}/BUILDTMP/EXPAT" && curl -Ls -o - $(cat "${WORKDIR}/expat.autobuild") | tar zxvf - --strip-components=1 && ./configure --enable-static --prefix="${PREFIX}" --without-docbook --without-examples --without-tests && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM hezhijie0327/base:ubuntu AS BUILD_GPERFTOOLS

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/gperftools.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/GPERFTOOLS" && cd "${WORKDIR}/BUILDTMP/GPERFTOOLS" && curl -Ls -o - $(cat "${WORKDIR}/gperftools.autobuild") | tar zxvf - --strip-components=1 && ./configure --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM hezhijie0327/base:ubuntu AS BUILD_LIBUV

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/libuv.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/LIBUV" && cd "${WORKDIR}/BUILDTMP/LIBUV" && curl -Ls -o - $(cat "${WORKDIR}/libuv.autobuild") | tar zxvf - --strip-components=1 && ./autogen.sh && ./configure --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM hezhijie0327/base:ubuntu AS BUILD_SQLITE

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/sqlite.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/SQLITE" && cd "${WORKDIR}/BUILDTMP/SQLITE" && curl -Ls -o - $(cat "${WORKDIR}/sqlite.autobuild") | tar zxvf - --strip-components=1 && ./configure --disable-dynamic-extensions --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM hezhijie0327/base:ubuntu AS BUILD_ZLIB_NG

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/zlib_ng.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/ZLIB_NG" && cd "${WORKDIR}/BUILDTMP/ZLIB_NG" && curl -Ls -o - $(cat "${WORKDIR}/zlib_ng.autobuild") | tar zxvf - --strip-components=1 && ./configure --prefix="${PREFIX}" --static --zlib-compat && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM hezhijie0327/base:ubuntu AS BUILD_OPENSSL

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/openssl.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/OPENSSL" && cd "${WORKDIR}/BUILDTMP/OPENSSL" && curl -Ls -o - $(cat "${WORKDIR}/openssl.autobuild") | tar zxvf - --strip-components=1 && ./config --prefix="${PREFIX}" && make -j $(nproc) && make install_sw && ldconfig --verbose && cd "${WORKDIR}"

FROM hezhijie0327/base:ubuntu AS BUILD_LIBSSH2

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/libssh2.autobuild /tmp/

COPY --from=BUILD_OPENSSL /tmp/BUILDLIB /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/LIBSSH2" && cd "${WORKDIR}/BUILDTMP/LIBSSH2" && curl -Ls -o - $(cat "${WORKDIR}/libssh2.autobuild") | tar zxvf - --strip-components=1 && ./configure --disable-examples-build --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM hezhijie0327/base:ubuntu AS BUILD_ARIA2

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/aria2c.*.autobuild /tmp/

COPY --from=BUILD_C_ARES /tmp/BUILDLIB /tmp/BUILDLIB/

COPY --from=BUILD_EXPAT /tmp/BUILDLIB /tmp/BUILDLIB/

COPY --from=BUILD_GPERFTOOLS /tmp/BUILDLIB /tmp/BUILDLIB/

COPY --from=BUILD_LIBUV /tmp/BUILDLIB /tmp/BUILDLIB/

COPY --from=BUILD_SQLITE /tmp/BUILDLIB /tmp/BUILDLIB/

COPY --from=BUILD_ZLIB_NG /tmp/BUILDLIB /tmp/BUILDLIB/

COPY --from=BUILD_OPENSSL /tmp/BUILDLIB /tmp/BUILDLIB/

COPY --from=BUILD_LIBSSH2 /tmp/BUILDLIB /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && ldconfig --verbose && git clone -b master --depth=1 $(cat "${WORKDIR}/aria2c.source.autobuild") "${WORKDIR}/BUILDTMP/ARIA2" && git clone -b main --depth=1 $(cat "${WORKDIR}/aria2c.patch.autobuild") "${WORKDIR}/BUILDTMP/PATCH" && export ARIA2_SHA=$(cd "${WORKDIR}/BUILDTMP/ARIA2" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export ARIA2_VERSION=$(cat "${WORKDIR}/aria2c.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/PATCH" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export ARIA2_CUSTOM_VERSION="${ARIA2_VERSION}-ZHIJIE-${ARIA2_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/ARIA2" && cat "./configure.ac" | sed "s/$ARIA2_VERSION/$ARIA2_CUSTOM_VERSION/g" > "./configure.ac.tmp" && mv "./configure.ac.tmp" "./configure.ac" && git apply --reject ${WORKDIR}/BUILDTMP/PATCH/aria2/*.patch && autoreconf -i && ARIA2_STATIC=yes ./configure --with-ca-bundle="/etc/ssl/certs/ca-certificates.crt" --with-libcares --with-libcares-prefix=${PREFIX} --with-libexpat --with-libexpat-prefix=${PREFIX} --with-libssh2 --with-libssh2-prefix=${PREFIX} --with-libuv --with-libuv-prefix=${PREFIX} --with-libz --with-libz-prefix=${PREFIX} --with-openssl --with-openssl-prefix=${PREFIX} --with-sqlite3 --with-sqlite3-prefix=${PREFIX} --with-tcmalloc --with-tcmalloc-prefix=${PREFIX} --without-appletls --without-gnutls --without-jemalloc --without-libgcrypt --without-libgmp --without-libnettle --without-libxml2 --without-wintls && make -j $(nproc) && make install && strip -s /usr/local/bin/aria2c && cp -rf "/usr/local/bin/aria2c" "${WORKDIR}/BUILDKIT/aria2c" && ${WORKDIR}/BUILDKIT/aria2c --version

FROM scratch

COPY --from=BUILD_ARIA2 /tmp/BUILDKIT /

EXPOSE 51413/tcp 51413/udp 6800/tcp 6881-6889/tcp 6881-6889/udp 6969/tcp 6969/udp

ENTRYPOINT ["/aria2c"]
