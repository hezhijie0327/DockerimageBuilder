# Current Version: 1.1.0

FROM ubuntu:latest as build

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

RUN apt update && apt install -qy libuv1-dev && sed -i "s/focal/impish/g" "/etc/apt/sources.list" && apt update && apt install -qy autoconf automake autopoint autotools-dev binutils ca-certificates cpp g++ git libc-ares-dev libcppunit-dev libexpat1-dev libgoogle-perftools-dev libgpg-error-dev libsqlite3-dev libssh2-1-dev libssl-dev libtool make pkg-config wget zlib1g-dev && git clone -b master "https://github.com/aria2/aria2.git" && git clone -b main --depth=1 "https://github.com/hezhijie0327/Patch.git" && ARIA2_SHA=$(cd ./aria2 && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && ARIA2_VERSION=$(cd ./aria2 && git describe --abbrev=0 | sed "s/release\-//g") && PATCH_SHA=$(cd ./Patch && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && ARIA2_CUSTOM_VERSION="${ARIA2_VERSION}-ZHIJIE-${ARIA2_SHA}${PATCH_SHA}" && cd ./aria2 && cat "./configure.ac" | sed "s/$ARIA2_VERSION/$ARIA2_CUSTOM_VERSION/g" > "./configure.ac.tmp" && mv "./configure.ac.tmp" "./configure.ac" && git apply --reject ../Patch/aria2/*.patch && autoreconf -i && ARIA2_STATIC=yes ./configure --with-ca-bundle="/etc/ssl/certs/ca-certificates.crt" --with-libcares --with-libexpat --with-libssh2 --with-libuv --with-libz --with-openssl --with-sqlite3 --with-tcmalloc --without-appletls --without-gnutls --without-jemalloc --without-libgcrypt --without-libgmp --without-libnettle --without-libxml2 --without-wintls && make -j 4 && make install && strip -s /usr/local/bin/*

FROM alpine:latest

WORKDIR /etc

COPY --from=build /usr/local/bin/aria2c /usr/local/bin/aria2c

RUN mkdir "/etc/aria2" "/etc/aria2/cert" "/etc/aria2/conf" "/etc/aria2/data" "/etc/aria2/work" && ln -s "/etc/aria2" "/opt/aria2" && /usr/local/bin/aria2c --version && rm -rf /tmp/*

WORKDIR /opt/aria2

EXPOSE 51413/tcp 51413/udp 6800/tcp 6881-6889/tcp 6881-6889/udp

VOLUME ["/opt/aria2/cert", "/opt/aria2/conf", "/opt/aria2/data", "/opt/aria2/work"]

ENTRYPOINT ["/usr/local/bin/aria2c"]

CMD ["--conf-path='/etc/aria2/conf/aria2.conf'"]
