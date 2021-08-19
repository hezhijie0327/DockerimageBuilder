# Current Version: 1.1.7

FROM ubuntu:devel as build

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

RUN cat "/etc/apt/sources.list" | sed "s/\#\ //g" | grep "deb\ \|deb\-src" > "/tmp/apt_raw.tmp" && cat "/tmp/apt_raw.tmp" | grep "backports" | sed "s/backports/proposed/g" > "/tmp/apt_proposed.tmp" && cat /tmp/apt_*.tmp | sort | uniq > "/etc/apt/sources.list" && rm -rf /tmp/* && apt update && apt upgrade -qy && apt dist-upgrade -qy && apt autoremove -qy && apt install -qy autoconf automake autopoint autotools-dev binutils ca-certificates cpp g++ git libc-ares-dev libcppunit-dev libexpat1-dev libgoogle-perftools-dev libgpg-error-dev libsqlite3-dev libssh2-1-dev libssl-dev libtool libuv1-dev make pkg-config wget zlib1g-dev && git clone -b master --depth=1 "https://github.com.cnpmjs.org/libuv/libuv.git" && cd ./libuv && sh ./autogen.sh && ./configure && make && make install && cd .. && git clone -b master "https://github.com.cnpmjs.org/aria2/aria2.git" && git clone -b main --depth=1 "https://github.com.cnpmjs.org/hezhijie0327/Patch.git" && ARIA2_SHA=$(cd ./aria2 && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && ARIA2_VERSION=$(cd ./aria2 && git describe --abbrev=0 | sed "s/release\-//g") && PATCH_SHA=$(cd ./Patch && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && ARIA2_CUSTOM_VERSION="${ARIA2_VERSION}-ZHIJIE-${ARIA2_SHA}${PATCH_SHA}" && cd ./aria2 && cat "./configure.ac" | sed "s/$ARIA2_VERSION/$ARIA2_CUSTOM_VERSION/g" > "./configure.ac.tmp" && mv "./configure.ac.tmp" "./configure.ac" && git apply --reject ../Patch/aria2/*.patch && ldconfig && autoreconf -i && ARIA2_STATIC=yes ./configure --with-ca-bundle="/etc/ssl/certs/ca-certificates.crt" --with-libcares --with-libexpat --with-libssh2 --with-libuv --with-libz --with-openssl --with-sqlite3 --with-tcmalloc --without-appletls --without-gnutls --without-jemalloc --without-libgcrypt --without-libgmp --without-libnettle --without-libxml2 --without-wintls && make -j 4 && make install && strip -s /usr/local/bin/*

FROM alpine:latest

WORKDIR /etc

COPY --from=build /usr/local/bin/aria2c /usr/local/bin/aria2c

RUN mkdir "/etc/aria2" "/etc/aria2/cert" "/etc/aria2/conf" "/etc/aria2/data" "/etc/aria2/work" && /usr/local/bin/aria2c --version

WORKDIR /etc/aria2

EXPOSE 51413/tcp 51413/udp 6800/tcp 6881-6889/tcp 6881-6889/udp

VOLUME ["/etc/aria2/cert", "/etc/aria2/conf", "/etc/aria2/data", "/etc/aria2/work"]

ENTRYPOINT ["/usr/local/bin/aria2c"]
