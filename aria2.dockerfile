# Current Version: 1.2.9

FROM ubuntu:devel as build

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

RUN cat "/etc/apt/sources.list" | sed "s/\#\ //g" | grep "deb\ \|deb\-src" > "/tmp/apt.tmp" && cat "/tmp/apt.tmp" | sort | uniq > "/etc/apt/sources.list" && rm -rf /tmp/* && apt update && apt upgrade -qy && apt dist-upgrade -qy && apt autoremove -qy && apt install -qy autoconf automake autopoint autotools-dev binutils ca-certificates cpp curl g++ git jq libcppunit-dev libgpg-error-dev libtool make pkg-config && curl -s --connect-timeout 15 "https://packages.zhijie.online" | jq -Sr ".aria2c" > "/tmp/aria2c.json" && export C_ARES="$(cat '/tmp/aria2c.json' | jq -Sr '.lib.source.c_ares')" && export EXPAT="$(cat '/tmp/aria2c.json' | jq -Sr '.lib.source.expat')" && export GPERFTOOLS="$(cat '/tmp/aria2c.json' | jq -Sr '.lib.source.gperftools')" && export LIBSSH2="$(cat '/tmp/aria2c.json' | jq -Sr '.lib.source.libssh2')" && export LIBUV="$(cat '/tmp/aria2c.json' | jq -Sr '.lib.source.libuv')" && export OPENSSL="$(cat '/tmp/aria2c.json' | jq -Sr '.lib.source.openssl')" && export SQLITE="$(cat '/tmp/aria2c.json' | jq -Sr '.lib.source.sqlite')" && export ZLIB="$(cat '/tmp/aria2c.json' | jq -Sr '.lib.source.zlib')" && export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/build_lib" && export LD_LIBRARY_PATH="${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && mkdir "${WORKDIR}/ZLIB" && cd "${WORKDIR}/ZLIB" && curl -Ls -o - "${ZLIB}" | tar zxvf - --strip-components=1 && ./configure --prefix="${PREFIX}" --static && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/EXPAT" && cd "${WORKDIR}/EXPAT" && curl -Ls -o - "${EXPAT}" | tar jxvf - --strip-components=1 && ./configure --enable-static --prefix="${PREFIX}" --without-docbook --without-examples --without-tests && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/C_ARES" && cd "${WORKDIR}/C_ARES" && curl -Ls -o - "${C_ARES}" | tar zxvf - --strip-components=1 && ./configure --disable-tests --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/OPENSSL" && cd "${WORKDIR}/OPENSSL" && curl -Ls -o - "${OPENSSL}" | tar zxvf - --strip-components=1 && ./config --prefix="${PREFIX}" && make -j $(nproc) && make install_sw && cd "${WORKDIR}" && mkdir "${WORKDIR}/SQLITE" && cd "${WORKDIR}/SQLITE3" && curl -Ls -o - "${SQLITE}" | tar zxvf - --strip-components=1 && ./configure --disable-dynamic-extensions --disable-tcl --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/LIBSSH2" && cd "${WORKDIR}/LIBSSH2" && curl -Ls -o - "${LIBSSH2}" | tar zxvf - --strip-components=1 && ./configure --disable-examples-build --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/GPERFTOOLS" && cd "${WORKDIR}/GPERFTOOLS" && curl -Ls -o - "${GPERFTOOLS}" | tar zxvf - --strip-components=1 && ./configure --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && mkdir "${WORKDIR}/LIBUV" && cd "${WORKDIR}/LIBUV" && curl -Ls -o - "${LIBUV}" | tar zxvf - --strip-components=1 && ./autogen.sh && ./configure --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && cd "${WORKDIR}" && ldconfig --verbose && git clone -b master "$(cat '/tmp/aria2c.json' | jq -Sr '.source')" && git clone -b main --depth=1 "$(cat '/tmp/aria2c.json' | jq -Sr '.patch')" && ARIA2_SHA=$(cd ./aria2 && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && ARIA2_VERSION=$(cd ./aria2 && git describe --abbrev=0 | sed "s/release\-//g") && PATCH_SHA=$(cd ./Patch && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && ARIA2_CUSTOM_VERSION="${ARIA2_VERSION}-ZHIJIE-${ARIA2_SHA}${PATCH_SHA}" && cd ./aria2 && cat "./configure.ac" | sed "s/$ARIA2_VERSION/$ARIA2_CUSTOM_VERSION/g" > "./configure.ac.tmp" && mv "./configure.ac.tmp" "./configure.ac" && git apply --reject ../Patch/aria2/*.patch && autoreconf -i && ARIA2_STATIC=yes ./configure --with-ca-bundle="/etc/ssl/certs/ca-certificates.crt" --with-libcares --with-libexpat --with-libssh2 --with-libuv --with-libz --with-openssl --with-sqlite3 --with-tcmalloc --without-appletls --without-gnutls --without-jemalloc --without-libgcrypt --without-libgmp --without-libnettle --without-libxml2 --without-wintls && make -j 4 && make install && strip -s /usr/local/bin/aria2c

FROM alpine:latest

WORKDIR /etc

COPY --from=build /usr/local/bin/aria2c /usr/local/bin/aria2c

RUN mkdir "/etc/aria2" "/etc/aria2/cert" "/etc/aria2/conf" "/etc/aria2/data" "/etc/aria2/work" && /usr/local/bin/aria2c --version

WORKDIR /etc/aria2

EXPOSE 51413/tcp 51413/udp 6800/tcp 6881-6889/tcp 6881-6889/udp

VOLUME ["/etc/aria2/cert", "/etc/aria2/conf", "/etc/aria2/data", "/etc/aria2/work"]

ENTRYPOINT ["/usr/local/bin/aria2c"]
