# Current Version: 1.4.3

FROM ubuntu:devel as build

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/etc/apt/sources.list" | sed "s/\#\ //g" | grep "deb\ \|deb\-src" > "${WORKDIR}/apt.tmp" && cat "${WORKDIR}/apt.tmp" | sort | uniq > "/etc/apt/sources.list" && rm -rf ${WORKDIR}/*.tmp && apt update && apt install -qy autoconf automake autopoint autotools-dev binutils ca-certificates cpp curl g++ git jq libcppunit-dev libgpg-error-dev libtool make pkg-config upx-ucl && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".aria2c" > "${WORKDIR}/aria2c.json" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.version" && export C_ARES=$(cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.c_ares") && export EXPAT=$(cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.expat") && export GPERFTOOLS=$(cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.gperftools") && export LIBSSH2=$(cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.libssh2") && export LIBUV=$(cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.libuv") && export OPENSSL=$(cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.openssl") && export SQLITE=$(cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.sqlite") && export ZLIB=$(cat "${WORKDIR}/aria2c.json" | jq -Sr ".lib.source.zlib") && export PREFIX="${WORKDIR}/build_lib" && export LD_LIBRARY_PATH="${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && mkdir "${WORKDIR}/ZLIB" && cd "${WORKDIR}/ZLIB" && curl -Ls -o - "${ZLIB}" | tar zxvf - --strip-components=1 && ./configure --prefix="${PREFIX}" --static && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/EXPAT" && cd "${WORKDIR}/EXPAT" && curl -Ls -o - "${EXPAT}" | tar jxvf - --strip-components=1 && ./configure --enable-static --prefix="${PREFIX}" --without-docbook --without-examples --without-tests && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/C_ARES" && cd "${WORKDIR}/C_ARES" && curl -Ls -o - "${C_ARES}" | tar zxvf - --strip-components=1 && ./configure --disable-tests --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/OPENSSL" && cd "${WORKDIR}/OPENSSL" && curl -Ls -o - "${OPENSSL}" | tar zxvf - --strip-components=1 && ./config --prefix="${PREFIX}" && make -j $(nproc) && make install_sw && cd "${WORKDIR}" && mkdir "${WORKDIR}/SQLITE" && cd "${WORKDIR}/SQLITE" && curl -Ls -o - "${SQLITE}" | tar zxvf - --strip-components=1 && ./configure --disable-dynamic-extensions --disable-tcl --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/LIBSSH2" && cd "${WORKDIR}/LIBSSH2" && curl -Ls -o - "${LIBSSH2}" | tar zxvf - --strip-components=1 && ./configure --disable-examples-build --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/GPERFTOOLS" && cd "${WORKDIR}/GPERFTOOLS" && curl -Ls -o - "${GPERFTOOLS}" | tar zxvf - --strip-components=1 && ./configure --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/LIBUV" && cd "${WORKDIR}/LIBUV" && curl -Ls -o - "${LIBUV}" | tar zxvf - --strip-components=1 && ./autogen.sh && ./configure --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && ldconfig --verbose && git clone -b master --depth=1 $(cat "${WORKDIR}/aria2c.json" | jq -Sr ".source") && git clone -b main --depth=1 $(cat "${WORKDIR}/aria2c.json" | jq -Sr ".patch") && export ARIA2_SHA=$(cd "./aria2" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export ARIA2_VERSION=$(cat "${WORKDIR}/aria2c.json" | jq -Sr ".version") && export PATCH_SHA=$(cd ./Patch && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export ARIA2_CUSTOM_VERSION="${ARIA2_VERSION}-ZHIJIE-${ARIA2_SHA}${PATCH_SHA}" && cd ./aria2 && cat "./configure.ac" | sed "s/$ARIA2_VERSION/$ARIA2_CUSTOM_VERSION/g" > "./configure.ac.tmp" && mv "./configure.ac.tmp" "./configure.ac" && git apply --reject ../Patch/aria2/*.patch && autoreconf -i && ARIA2_STATIC=yes ./configure --with-ca-bundle="/etc/ssl/certs/ca-certificates.crt" --with-libcares --with-libcares-prefix=${PREFIX} --with-libexpat --with-libexpat-prefix=${PREFIX} --with-libssh2 --with-libssh2-prefix=${PREFIX} --with-libuv --with-libuv-prefix=${PREFIX} --with-libz --with-libz-prefix=${PREFIX} --with-openssl --with-openssl-prefix=${PREFIX} --with-sqlite3 --with-sqlite3-prefix=${PREFIX} --with-tcmalloc --with-tcmalloc-prefix=${PREFIX} --without-appletls --without-gnutls --without-jemalloc --without-libgcrypt --without-libgmp --without-libnettle --without-libxml2 --without-wintls && make -j $(nproc) && make install && strip -s /usr/local/bin/aria2c && upx --ultra-brute /usr/local/bin/aria2c

FROM alpine:latest

COPY --from=build /usr/local/bin/aria2c /bin/aria2c

EXPOSE 51413/tcp 51413/udp 6800/tcp 6881-6889/tcp 6881-6889/udp

ENTRYPOINT ["/bin/aria2c"]
