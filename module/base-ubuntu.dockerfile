# Current Version: 1.1.0

FROM ubuntu:latest AS REBASED_UBUNTU

ENV DEBIAN_FRONTEND="noninteractive"

RUN export LSBCodename=$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) \
    && if [ $( dpkg --print-architecture ) = "amd64" ]; then export MIRROR_URL="ubuntu" ; else export MIRROR_URL="ubuntu-ports" ; fi \
    && echo "deb https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename} main multiverse restricted universe" > "/etc/apt/sources.list" \
    && echo "deb https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-backports main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-proposed main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-security main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-updates main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename} main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-backports main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-proposed main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-security main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src https://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-updates main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && cat <<EOF > "/etc/apt/preferences"
Package: *
Pin: release a=${LSBCodename}-backports
Pin-Priority: 990

Package: *
Pin: release a=${LSBCodename}-security
Pin-Priority: 500

Package: *
Pin: release a=${LSBCodename}-updates
Pin-Priority: 500

Package: *
Pin: release a=${LSBCodename}
Pin-Priority: 500

Package: *
Pin: release a=${LSBCodename}-proposed
Pin-Priority: 100
EOF \
    && apt update \
    && apt install -qy autoconf automake autopoint autotools-dev binutils curl g++ gcc git libtool make perl pkg-config yacc \
    && apt full-upgrade -qy \
    && apt autoremove -qy && apt clean autoclean -qy \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt" \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM scratch

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=REBASED_UBUNTU / /

CMD ["/bin/bash"]
