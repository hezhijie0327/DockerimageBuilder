# Current Version: 1.0.5

FROM ubuntu:latest AS REBASED_UBUNTU

ENV DEBIAN_FRONTEND="noninteractive"

RUN cat "/etc/apt/sources.list" | sed "s/\#\ //g" | grep "deb\ \|deb\-src" > "/tmp/apt.tmp" && cat "/tmp/apt.tmp" | sort | uniq > "/etc/apt/sources.list" \
    && apt update \
    && apt install -qy autoconf automake autopoint autotools-dev binutils curl g++ gcc git libtool make openssl perl pkg-config yacc && apt autoclean \
    && apt -t $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release )-backports full-upgrade -qy > "/dev/null" 2>&1 \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt" \
    && sed -i "s/http:/https:/g;s/archive.ubuntu.com/mirrors.ustc.edu.cn/g;s/ports.ubuntu.com/mirrors.ustc.edu.cn/g;s/security.ubuntu.com/mirrors.ustc.edu.cn/g" "/etc/apt/sources.list" \
    && apt autoremove -qy && apt clean autoclean -qy && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM scratch

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=REBASED_UBUNTU / /

CMD ["/bin/bash"]
