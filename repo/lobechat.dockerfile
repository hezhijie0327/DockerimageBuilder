# Current Version: 1.3.6

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".repo.lobechat" > "${WORKDIR}/lobechat.json" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".version" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".source" > "${WORKDIR}/lobechat.source.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".source_branch" > "${WORKDIR}/lobechat.source_branch.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".patch" > "${WORKDIR}/lobechat.patch.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".patch_branch" > "${WORKDIR}/lobechat.patch_branch.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".version" > "${WORKDIR}/lobechat.version.autobuild"

FROM --platform=linux/amd64 hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu AS BUILD_LOBECHAT

WORKDIR /tmp

COPY --from=GET_INFO /tmp/lobechat.*.autobuild /tmp/

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDTMP" && export PREFIX="${WORKDIR}/BUILDLIB" && export PNPM_HOME="/pnpm" && export PATH="${PNPM_HOME}:${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/lobechat.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/lobechat.source.autobuild") "${WORKDIR}/BUILDTMP/LOBECHAT" && git clone -b $(cat "${WORKDIR}/lobechat.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/lobechat.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export LOBECHAT_SHA=$(cd "${WORKDIR}/BUILDTMP/LOBECHAT" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export LOBECHAT_VERSION=$(cat "${WORKDIR}/lobechat.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export LOBECHAT_CUSTOM_VERSION="${LOBECHAT_VERSION}-ZHIJIE-${LOBECHAT_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/LOBECHAT" && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/lobechat/*.patch && sed -i "s/\"version\": \"[0-9]\+\.[0-9]\+\.[0-9]\+\"/\"version\": \"${LOBECHAT_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/LOBECHAT/package.json" && corepack enable && corepack use pnpm && pnpm i && mkdir -p "${WORKDIR}/BUILDTMP/LOBECHAT/sharp" && pnpm add sharp --prefix "${WORKDIR}/BUILDTMP/LOBECHAT/sharp" && npm run build:docker && cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/lobechat/webrtc" && npm i

FROM scratch AS APP_LOBECHAT

COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/DOCKERIMAGEBUILDER/patch/lobechat/webrtc /tmp/BUILDKIT/webrtc

COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/.next/standalone /tmp/BUILDKIT/lobechat
COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/.next/static /tmp/BUILDKIT/lobechat/.next/static
COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/public /tmp/BUILDKIT/lobechat/public
COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/sharp/node_modules/.pnpm /tmp/BUILDKIT/lobechat/node_modules/.pnpm

FROM node:current-alpine AS REBASED_LOBECHAT

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=APP_LOBECHAT /tmp/BUILDKIT/ /opt/

RUN sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" \
    && apk update \
    && apk add --no-cache proxychains-ng \
    && apk upgrade --no-cache \
    && rm -rf /tmp/* /var/cache/apk/*

FROM scratch

ENV NODE_ENV="production" NODE_TLS_REJECT_UNAUTHORIZED="0" \
    FEATURE_FLAGS="-check_updates,-welcome_suggest" \
    HOSTNAME="0.0.0.0" PORT="3210" \
    PROXY_URL="" \
    ENABLE_WEBRTC_SIGNALING_SERVER="false" \
    WEBRTC_HOST="0.0.0.0" WEBRTC_PORT="3211" \
    WEBRTC_ALLOWED_TOPICS="" \
    WEBRTC_LOG_LEVEL="notice" \
    WEBRTC_PING_TIMEOUT="30000"

COPY --from=REBASED_LOBECHAT / /

EXPOSE 3210/tcp 3211/tcp

CMD \
    if [ "$ENABLE_WEBRTC_SIGNALING_SERVER" = "true" ] && echo "$FEATURE_FLAGS" | grep -q '+webrtc_sync'; then \
        node /opt/webrtc/webrtc.js & \
    fi; \
    if [ -n "$PROXY_URL" ]; then \
        echo -e "localnet 127.0.0.0/255.0.0.0\nlocalnet ::1/128\nproxy_dns\nremote_dns_subnet 224\nstrict_chain\ntcp_connect_time_out 8000\ntcp_read_time_out 15000\n[ProxyList]\n$(echo $PROXY_URL | cut -d: -f1) $(echo $PROXY_URL | cut -d/ -f3 | cut -d: -f1) $(echo $PROXY_URL | cut -d: -f3)" > /etc/proxychains/proxychains.conf; \
        proxychains -q node /opt/lobechat/server.js; \
    else \
        node /opt/lobechat/server.js; \
    fi
