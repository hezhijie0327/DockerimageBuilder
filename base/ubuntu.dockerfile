# Current Version: 1.0.0

FROM ubuntu:devel

ENV DEBIAN_FRONTEND="noninteractive"

RUN cat "/etc/apt/sources.list" | sed "s/\#\ //g" | grep "deb\ \|deb\-src" > "/tmp/apt.tmp" && cat "/tmp/apt.tmp" | sed "s/archive.ubuntu.com/mirrors.ustc.edu.cn/g;s/ports.ubuntu.com/mirrors.ustc.edu.cn/g;s/security.ubuntu.com/mirrors.ustc.edu.cn/g" | sort | uniq > "/etc/apt/sources.list" && rm -rf /tmp/*.tmp && apt update && apt upgrade -yq && apt dist-upgrade -yq && apt autoremove -yq && apt install -qy autoconf automake autopoint autotools-dev binutils curl g++ gcc git libtool make perl pkg-config && apt autoclean && rm -rf /tmp/*

CMD ["/bin/bash"]
