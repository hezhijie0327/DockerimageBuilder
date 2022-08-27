# Current Version: 1.0.3

FROM ubuntu:devel

ENV DEBIAN_FRONTEND="noninteractive"

RUN cat "/etc/apt/sources.list" | sed "s/\#\ //g" | grep "deb\ \|deb\-src" > "/tmp/apt.tmp" && cat "/tmp/apt.tmp" | sort | uniq > "/etc/apt/sources.list" && apt update && apt upgrade -yq && apt dist-upgrade -yq && apt autoremove -yq && apt install -qy autoconf automake autopoint autotools-dev binutils curl g++ gcc git libtool make perl pkg-config yacc && apt autoclean && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt" && sed -i "s/archive.ubuntu.com/mirrors.ustc.edu.cn/g;s/ports.ubuntu.com/mirrors.ustc.edu.cn/g;s/security.ubuntu.com/mirrors.ustc.edu.cn/g" "/etc/apt/sources.list" && rm -rf /tmp/*

CMD ["/bin/bash"]
