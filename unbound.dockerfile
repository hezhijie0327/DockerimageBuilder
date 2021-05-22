# Current Version: 1.0.1

FROM ubuntu:latest as build

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

RUN apt update && apt install -y binutils byacc ca-certificates gcc git libevent-dev libexpat1-dev libhiredis-dev libhiredis-dev libmnl-dev libnghttp2-dev libprotobuf-c-dev libsodium-dev libssl-dev make protobuf-c-compiler wget && git clone -b master --depth=1 "https://github.com/NLnetLabs/unbound.git" && cd ./unbound && LDFLAGS=-ldl ./configure --enable-allsymbols --enable-cachedb --enable-dnscrypt --enable-dnstap --enable-dsa --enable-ecdsa --enable-ed25519 --enable-ed448 --enable-event-api --enable-explicit-port-randomisation --enable-fully-static --enable-gost --enable-ipsecmod --enable-ipset --enable-pie --enable-relro-now --enable-sha1 --enable-sha2 --enable-subnet  --enable-swig-version-check --enable-tfo-client --enable-tfo-server --with-deprecate-rsa-1024 --with-dynlibmodule --with-libbsd --with-libevent --with-libhiredis --with-libmnl --with-libnghttp2 --with-pthreads --with-solaris-threads --with-ssl --with-chroot-dir="/etc/unbound" --with-conf-file="/etc/unbound/conf/unbound.conf" --with-dnstap-socket-path="/etc/unbound/work/unbound.sock" --with-pidfile="/etc/unbound/work/unbound.pid" --with-rootcert-file="/etc/unbound/icannbundle.pem " --with-rootkey-file="/etc/unbound/root.key" --with-run-dir="/etc/unbound" --with-share-dir="/etc/unbound" --with-username="" --prefix="/etc/unbound" && make -j 4 && make install && rm -rf /etc/unbound/sbin/unbound-control* /etc/unbound/sbin/unbound-host* && strip -s /etc/unbound/sbin/*

FROM alpine:latest

WORKDIR /etc

COPY --from=build /etc/unbound/sbin /etc/unbound

RUN /etc/unbound/unbound -V && wget -O "/etc/unbound/icannbundle.pem" "https://data.iana.org/root-anchors/icannbundle.pem" && wget -O "/etc/unbound/root.hints" "https://www.internic.net/domain/named.cache" && echo "#!/bin/sh" > "/etc/unbound/unbound.sh" && echo "/etc/unbound/unbound-anchor -a \"/etc/unbound/root.key\" -c \"/etc/unbound/icannbundle.pem\" -f \"/etc/resolv.conf\" -r \"/etc/unbound/root.hints\" -v -F" >> "/etc/unbound/unbound.sh" && echo "/etc/unbound/unbound-checkconf \"/etc/unbound/conf/unbound.conf\" > \"/etc/unbound/work/unbound-checkconf.log\"" >> "/etc/unbound/unbound.sh" && echo "/etc/unbound/unbound -c \"/etc/unbound/conf/unbound.conf\" -v" >> "/etc/unbound/unbound.sh" && mkdir "/etc/unbound/cert" "/etc/unbound/conf" "/etc/unbound/work" && ln -s "/etc/unbound" "/opt/unbound" && rm -rf /tmp/*

WORKDIR /opt/unbound

EXPOSE 443/tcp 53/tcp 53/udp 853/tcp

VOLUME ["/opt/unbound/cert", "/opt/unbound/conf", "/opt/unbound/work"]

CMD ["sh", "-c", "sh '/etc/unbound/unbound.sh'"]
