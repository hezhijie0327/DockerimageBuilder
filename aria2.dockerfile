# Current Version: 1.2.8

FROM ubuntu:devel as build

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

RUN cat "/etc/apt/sources.list" | sed "s/\#\ //g" | grep "deb\ \|deb\-src" > "/tmp/apt.tmp" && cat "/tmp/apt.tmp" | sort | uniq > "/etc/apt/sources.list" && rm -rf /tmp/* && apt update && apt upgrade -qy && apt dist-upgrade -qy && apt autoremove -qy && apt install -qy autoconf automake autopoint autotools-dev binutils ca-certificates cpp curl g++ git libcppunit-dev libgpg-error-dev libtool make pkg-config && C_ARES="https://c-ares.haxx.se/download/c-ares-1.17.2.tar.gz" && EXPAT="https://github.com/libexpat/libexpat/releases/download/R_2_4_1/expat-2.4.1.tar.bz2" && LIBSSH2="https://www.libssh2.org/download/libssh2-1.9.0.tar.gz" && LIBUV="https://dist.libuv.org/dist/v1.42.0/libuv-v1.42.0.tar.gz" && OPENSSL="https://www.openssl.org/source/openssl-1.1.1k.tar.gz" && SQLITE3="https://www.sqlite.org/2021/sqlite-autoconf-3360000.tar.gz" && TCMALLOC="https://github.com/gperftools/gperftools/releases/download/gperftools-2.9.1/gperftools-2.9.1.tar.gz" && ZLIB="https://www.zlib.net/zlib-1.2.11.tar.gz" && export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/build_lib" && export LD_LIBRARY_PATH="${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && mkdir "${WORKDIR}/ZLIB" && cd "${WORKDIR}/ZLIB" && curl -Ls -o - "${ZLIB}" | tar zxvf - --strip-components=1 && ./configure --prefix="${PREFIX}" --static && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/EXPAT" && cd "${WORKDIR}/EXPAT" && curl -Ls -o - "${EXPAT}" | tar jxvf - --strip-components=1 && ./configure --enable-static --prefix="${PREFIX}" --without-docbook --without-examples --without-tests && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/C_ARES" && cd "${WORKDIR}/C_ARES" && curl -Ls -o - "${C_ARES}" | tar zxvf - --strip-components=1 && ./configure --disable-tests --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/OPENSSL" && cd "${WORKDIR}/OPENSSL" && curl -Ls -o - "${OPENSSL}" | tar zxvf - --strip-components=1 && ./config --prefix="${PREFIX}" && make -j $(nproc) && make install_sw && cd "${WORKDIR}" && mkdir "${WORKDIR}/SQLITE3" && cd "${WORKDIR}/SQLITE3" && curl -Ls -o - "${SQLITE3}" | tar zxvf - --strip-components=1 && ./configure --disable-dynamic-extensions --disable-tcl --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/LIBSSH2" && cd "${WORKDIR}/LIBSSH2" && curl -Ls -o - "${LIBSSH2}" | tar zxvf - --strip-components=1 && ./configure --disable-examples-build --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/TCMALLOC" && cd "${WORKDIR}/TCMALLOC" && curl -Ls -o - "${TCMALLOC}" | tar zxvf - --strip-components=1 && ./configure --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/LIBUV" && cd "${WORKDIR}/LIBUV" && curl -Ls -o - "${LIBUV}" | tar zxvf - --strip-components=1 && ./autogen.sh && ./configure --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && ldconfig --verbose && git clone -b master "https://github.com/aria2/aria2.git" && git clone -b main --depth=1 "https://github.com/hezhijie0327/Patch.git" && ARIA2_SHA=$(cd ./aria2 && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && ARIA2_VERSION=$(cd ./aria2 && git describe --abbrev=0 | sed "s/release\-//g") && PATCH_SHA=$(cd ./Patch && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && ARIA2_CUSTOM_VERSION="${ARIA2_VERSION}-ZHIJIE-${ARIA2_SHA}${PATCH_SHA}" && cd ./aria2 && cat "./configure.ac" | sed "s/$ARIA2_VERSION/$ARIA2_CUSTOM_VERSION/g" > "./configure.ac.tmp" && mv "./configure.ac.tmp" "./configure.ac" && git apply --reject ../Patch/aria2/*.patch && autoreconf -i && ARIA2_STATIC=yes ./configure --with-ca-bundle="/etc/ssl/certs/ca-certificates.crt" --with-libcares --with-libexpat --with-libssh2 --with-libuv --with-libz --with-openssl --with-sqlite3 --with-tcmalloc --without-appletls --without-gnutls --without-jemalloc --without-libgcrypt --without-libgmp --without-libnettle --without-libxml2 --without-wintls && make -j 4 && make install && strip -s /usr/local/bin/aria2c

FROM alpine:latest

WORKDIR /etc

COPY --from=build /usr/local/bin/aria2c /usr/local/bin/aria2c

RUN mkdir "/etc/aria2" "/etc/aria2/cert" "/etc/aria2/conf" "/etc/aria2/data" "/etc/aria2/work" && /usr/local/bin/aria2c --version

WORKDIR /etc/aria2

EXPOSE 51413/tcp 51413/udp 6800/tcp 6881-6889/tcp 6881-6889/udp

VOLUME ["/etc/aria2/cert", "/etc/aria2/conf", "/etc/aria2/data", "/etc/aria2/work"]

ENTRYPOINT ["/usr/local/bin/aria2c"]
