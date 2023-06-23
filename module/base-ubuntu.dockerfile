# Current Version: 1.1.6

FROM ubuntu:rolling AS REBASED_UBUNTU

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt update \
    && apt install -qy autoconf automake autopoint autotools-dev binutils curl flex g++ gcc git jq libtool make perl pkg-config unzip wget yacc \
    && apt full-upgrade -qy \
    && apt autoremove -qy && apt clean autoclean -qy \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt" \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* \
    export LSBCodename=$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) \
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
    && echo "Package: *" > "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-backports" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 990" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" >> "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-security" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 500" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" >> "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-updates" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 500" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" >> "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 500" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" >> "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-proposed" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 100" >> "/etc/apt/preferences"

FROM scratch

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=REBASED_UBUNTU / /

CMD ["/bin/bash"]
