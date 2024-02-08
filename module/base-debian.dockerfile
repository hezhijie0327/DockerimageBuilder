# Current Version: 1.0.1

FROM debian:rolling AS REBASED_DEBIAN

ENV DEBIAN_FRONTEND="noninteractive"

RUN export LSBCodename=$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) \
    && rm -rf "/etc/apt/sources.list.d/debian.sources" \
    && echo "deb http://mirrors.ustc.edu.cn/debian-security ${LSBCodename}-security contrib main non-free non-free-firmware" > "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/debian ${LSBCodename} contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/debian ${LSBCodename}-backports contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/debian ${LSBCodename}-backports-sloppy contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/debian ${LSBCodename}-proposed-updates contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/debian ${LSBCodename}-updates contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/debian-security ${LSBCodename}-security contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/debian ${LSBCodename} contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/debian ${LSBCodename}-backports contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/debian ${LSBCodename}-backports-sloppy contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/debian ${LSBCodename}-proposed-updates contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/debian ${LSBCodename}-updates contrib main non-free non-free-firmware" >> "/etc/apt/sources.list" \
    && echo "Package: *" > "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-backports-sloppy" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 990" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" > "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-backports" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 990" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" > "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-security" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 500" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" > "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-updates" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 500" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" > "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 500" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" > "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-proposed-updates" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 100" >> "/etc/apt/preferences" \
    && apt update \
    && apt install -qy autoconf automake autopoint autotools-dev binutils bzip2 curl flex g++ gcc gifsicle git glibc-source jq libbsd-dev libc6-dev libicu-dev libpng-dev libtool make nasm perl pkg-config python3 python3-pip unzip wget yacc zlib1g-dev \
    && apt full-upgrade -qy \
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && sed -i 's/http:/https:/g' "/etc/apt/sources.list" \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt" \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM scratch

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=REBASED_DEBIAN / /

CMD ["/bin/bash"]
