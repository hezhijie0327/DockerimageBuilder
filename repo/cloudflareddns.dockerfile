# Current Version: 1.0.6

FROM hezhijie0327/base:alpine AS GET_INFO

FROM hezhijie0327/base:alpine AS BUILD_CLOUDFLAREDDNS

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" && git clone -b "main" --depth=1 "https://github.com/hezhijie0327/CloudflareDDNS.git" "${WORKDIR}/BUILDTMP/CLOUDFLAREDDNS" && cp -rf "${WORKDIR}/BUILDTMP/CLOUDFLAREDDNS/CloudflareDDNS.sh" "${WORKDIR}/BUILDKIT/CloudflareDDNS.sh"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_CLOUDFLAREDDNS /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/CloudflareDDNS.sh"

FROM alpine:latest AS BUILD_BASEOS

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=GPG_SIGN /tmp/BUILDKIT /opt

RUN sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" \
    && apk update \
    && apk add --no-cache bind-tools curl jq \
    && apk upgrade --no-cache \
    && rm -rf /tmp/* /var/cache/apk/*

FROM scratch

COPY --from=BUILD_BASEOS / /

ENV XAUTHEMAIL=${XAUTHEMAIL} XAUTHKEY=${XAUTHKEY} ZONENAME=${ZONENAME} RECORDNAME=${RECORDNAME} TYPE=${TYPE} TTL=${TTL} STATICIP=${STATICIP} PROXYSTATUS=${PROXYSTATUS} RUNNINGMODE=${RUNNINGMODE} UPDATEFREQUENCY=${UPDATEFREQUENCY}

CMD [ "/bin/sh", "-c", "sh '/opt/CloudflareDDNS.sh' -e ${XAUTHEMAIL:-demo@zhijie.online} -k ${XAUTHKEY:-123defghijk4567pqrstuvw890} -z ${ZONENAME:-zhijie.online} -r ${RECORDNAME:-demo.zhijie.online} -t ${TYPE:-A} -l ${TTL:-3600} -i ${STATICIP:-auto} -p ${PROXYSTATUS:-false} -m ${RUNNINGMODE:-update} && sleep ${UPDATEFREQUENCY:-3600}" ]
