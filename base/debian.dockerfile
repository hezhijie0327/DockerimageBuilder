# Current Version: 1.0.0

FROM hezhijie0327/base:package AS get_package

FROM debian:stable-slim AS rebased_debian

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=get_package /package.json /opt/package.json

RUN \
    && apt update \
    && apt install -qy autoconf automake autopoint autotools-dev binutils bzip2 curl flex g++ gcc gifsicle git glibc-source jq libbsd-dev libc6-dev libicu-dev libpng-dev libtool make nasm perl pkg-config python3 python3-pip unzip wget yacc zlib1g-dev gettext texinfo gawk bison python3-numpy graphviz re2c crossbuild-essential-amd64 crossbuild-essential-arm64 libtinfo-dev protobuf-c-compiler libprotobuf-c-dev cmake libjemalloc-dev \
    && apt full-upgrade -qy \
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && sed -i 's/http:/https:/g' "/etc/apt/sources.list" \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt" \
    && sed -i "s/deb.debian.org/mirrors.ustc.edu.cn/g" "/etc/apt/sources.list.d/debian.sources" \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM scratch

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=rebased_debian / /

CMD ["/bin/bash"]
