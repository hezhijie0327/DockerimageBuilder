# Current Version: 1.0.4

FROM ubuntu:latest as build

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

RUN apt update && apt install -y libuv1-dev && sed -i "s/focal/impish/g" "/etc/apt/sources.list" && apt update && apt install -y autoconf automake autopoint autotools-dev binutils ca-certificates cpp g++ git libc-ares-dev libcppunit-dev libexpat1-dev libgoogle-perftools-dev libgpg-error-dev libsqlite3-dev libssh2-1-dev libssl-dev libtool make pkg-config wget zlib1g-dev && git clone -b master --depth=1 "https://github.com/aria2/aria2.git" && git clone -b master --depth=1 "https://github.com/P3TERX/Aria2-Pro-Core.git" && cd ./aria2 && git apply --reject ../Aria2-Pro-Core/patch/*.patch && autoreconf -i && ARIA2_STATIC=yes ./configure --with-ca-bundle="/etc/ssl/certs/ca-certificates.crt" --with-libcares --with-libexpat --with-libssh2 --with-libuv --with-libz --with-openssl --with-sqlite3 --with-tcmalloc --without-appletls --without-gnutls --without-jemalloc --without-libgcrypt --without-libgmp --without-libnettle --without-libxml2 --without-wintls && make -j 4 && make install && strip -s /usr/local/bin/*

FROM alpine:latest

WORKDIR /etc

COPY --from=build /usr/local/bin/aria2c /usr/local/bin/aria2c

RUN mkdir "/etc/aria2" "/etc/aria2/cert" "/etc/aria2/conf" "/etc/aria2/data" "/etc/aria2/work" && ln -s "/etc/aria2" "/opt/aria2" && wget -P "/etc/aria2" "https://raw.githubusercontent.com/hezhijie0327/aria2.conf/source/aria2.sh" && /usr/local/bin/aria2c --version && rm -rf /tmp/*

WORKDIR /opt/aria2

EXPOSE 51413/tcp 51413/udp 6800/tcp 6881-6889/tcp 6881-6889/udp

VOLUME ["/opt/aria2/cert", "/opt/aria2/conf", "/opt/aria2/data", "/opt/aria2/work"]

ENV CHECKALIVE=${CHECKALIVE} EXPIRATION=${EXPIRATION} MASQUERADE=${MASQUERADE} SYNCREMOTE=${SYNCREMOTE} SELFUPDATE=${SELFUPDATE}

CMD [ "sh", "-c", "sh '/etc/aria2/aria2.sh' -c ${CHECKALIVE:-https://dns.alidns.com} -e ${EXPIRATION:-86400} -m ${MASQUERADE:-a2} -s ${SYNCREMOTE:-false} -u ${SELFUPDATE:-false}" ]
