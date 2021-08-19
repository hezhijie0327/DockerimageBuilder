# Current Version: 1.1.5

FROM ubuntu:devel as build

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

RUN UBUNTU_CODENAME=$(cat "/etc/os-release" | grep "UBUNTU\_CODENAME" | sed "s/UBUNTU\_CODENAME\=//g") && echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports impish main restricted universe multiverse" > "/etc/apt/sources.list" && echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports impish-backports main restricted universe multiverse" >> "/etc/apt/sources.list" && echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports impish-proposed main restricted universe multiverse" >> "/etc/apt/sources.list" && echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports impish-security main restricted universe multiverse" >> "/etc/apt/sources.list" && echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports impish-updates main restricted universe multiverse" >> "/etc/apt/sources.list" && echo "deb-src http://mirrors.ustc.edu.cn/ubuntu-ports impish-backports main restricted universe multiverse" >> "/etc/apt/sources.list" && echo "deb-src http://mirrors.ustc.edu.cn/ubuntu-ports impish-proposed main restricted universe multiverse" >> "/etc/apt/sources.list" && echo "deb-src http://mirrors.ustc.edu.cn/ubuntu-ports impish-security main restricted universe multiverse" >> "/etc/apt/sources.list" && echo "deb-src http://mirrors.ustc.edu.cn/ubuntu-ports impish-updates main restricted universe multiverse" >> "/etc/apt/sources.list" && apt update && apt upgrade -qy && apt dist-upgrade -qy && apt autoremove -qy && apt install -qy curl gnupg gnupg1 gnupg2 && curl -s --connect-timeout 15 "http://dl.yarnpkg.com/debian/pubkey.gpg" | apt-key add - && echo "deb http://dl.yarnpkg.com/debian/ stable main" > "/etc/apt/sources.list.d/yarn.list" && apt update && apt install -qy git golang make nodejs npm yarn && git clone -b master "https://github.com.cnpmjs.org/AdguardTeam/AdGuardHome.git" && git clone -b main --depth=1 "https://github.com.cnpmjs.org/hezhijie0327/Patch.git" && AGH_SHA=$(cd ./AdGuardHome && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && AGH_VERSION=$(cd ./AdGuardHome && git describe --abbrev=0 | sed "s/\-.*//g;s/v//g") && PATCH_SHA=$(cd ./Patch && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && AGH_CUSTOM_VERSION="${AGH_VERSION}-ZHIJIE-${AGH_SHA}${PATCH_SHA}" && cd ./AdGuardHome && cp -r "../Patch/adguardhome/static/filters.json" "./client/src/helpers/filters/filters.json" && cp -r "../Patch/adguardhome/static/zh-cn.json" "./client/src/__locales/zh-cn.json" && git apply --reject ../Patch/adguardhome/*.patch && make -j 1 VERSION="${AGH_CUSTOM_VERSION}"

FROM alpine:latest

WORKDIR /etc

COPY --from=build /tmp/AdGuardHome/AdGuardHome /usr/local/bin/adguardhome

RUN mkdir "/etc/adguardhome" "/etc/adguardhome/cert" "/etc/adguardhome/conf" "/etc/adguardhome/work" && /usr/local/bin/adguardhome --version

WORKDIR /etc/adguardhome

EXPOSE 3000/tcp 3001/tcp 443/tcp 443/udp 53/tcp 53/udp 5443/tcp 5443/udp 80/tcp 853/tcp 8853/udp

VOLUME ["/etc/adguardhome/cert", "/etc/adguardhome/conf", "/etc/adguardhome/work"]

ENTRYPOINT ["/usr/local/bin/adguardhome"]
