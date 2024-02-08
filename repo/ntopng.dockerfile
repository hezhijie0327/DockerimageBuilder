# Current Version: 1.0.1

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -fsSL "https://packages.ntop.org/apt/ntop.key" | gpg --dearmor -o "${WORKDIR}/ntop-archive-keyring.gpg"

FROM debian:latest AS BUILD_NTOPNG

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=GET_INFO /tmp/ntop-archive-keyring.gpg /etc/apt/keyrings/ntop-archive-keyring.gpg

RUN export LSBCodename=$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) \
    && if [ $( dpkg --print-architecture ) = "amd64" ]; then export NTOP_URL="${LSBCodename}" NTOP_REPO="x64"; else export NTOP_URL="${LSBCodename}_pi" NTOP_REPO="arm64"; fi \
    && echo "deb [signed-by=/etc/apt/keyrings/ntop-archive-keyring.gpg] http://packages.ntop.org/apt/${NTOP_URL}/ ${NTOP_REPO}/" > "/etc/apt/sources.list.d/ntop.list" \
    && echo "deb [signed-by=/etc/apt/keyrings/ntop-archive-keyring.gpg] http://packages.ntop.org/apt/${NTOP_URL}/ all/" >> "/etc/apt/sources.list.d/ntop.list" \
    && apt update \
    && echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
    && apt install -qy ntopng ntopng-data \
    && sed -i 's/http:/https:/g' "/etc/apt/sources.list.d/ntop.list"

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
    && apt full-upgrade -qy \
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && sed -i 's/http:/https:/g' "/etc/apt/sources.list" \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

RUN echo '#!/bin/bash\n/etc/init.d/redis-server start\nntopng "$@" $NTOP_CONFIG' > /opt/ntopng_runtime.sh \
    && chmod +x /opt/ntopng_runtime.sh

FROM scratch

ENV DEBIAN_FRONTEND="noninteractive" NTOP_CONFIG=""

COPY --from=BUILD_NTOPNG / /

EXPOSE 3000/tcp 3001/tcp

ENTRYPOINT ["/opt/ntopng_runtime.sh"]
