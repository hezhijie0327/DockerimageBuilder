# Current Version: 1.1.2

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.lobechat" > "${WORKDIR}/lobechat.json" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".version" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".source" > "${WORKDIR}/lobechat.source.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".source_branch" > "${WORKDIR}/lobechat.source_branch.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".patch" > "${WORKDIR}/lobechat.patch.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".patch_branch" > "${WORKDIR}/lobechat.patch_branch.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".version" > "${WORKDIR}/lobechat.version.autobuild"

FROM --platform=linux/amd64 hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu AS BUILD_LOBECHAT

WORKDIR /tmp

COPY --from=GET_INFO /tmp/lobechat.*.autobuild /tmp/

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PNPM_HOME="/pnpm" && export PATH="${PNPM_HOME}:${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/lobechat.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/lobechat.source.autobuild") "${WORKDIR}/BUILDTMP/LOBECHAT" && git clone -b $(cat "${WORKDIR}/lobechat.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/lobechat.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export LOBECHAT_SHA=$(cd "${WORKDIR}/BUILDTMP/LOBECHAT" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export LOBECHAT_VERSION=$(cat "${WORKDIR}/lobechat.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export LOBECHAT_CUSTOM_VERSION="${LOBECHAT_VERSION}-ZHIJIE-${LOBECHAT_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/LOBECHAT" && sed -i "s/\"version\": \"[0-9]\+\.[0-9]\+\.[0-9]\+\"/\"version\": \"${LOBECHAT_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/LOBECHAT/package.json" && corepack enable && pnpm add sharp && pnpm i && npm run build:docker && cp -rf "${WORKDIR}/BUILDTMP/LOBECHAT/.next/standalone" "${WORKDIR}/BUILDKIT/lobechat" && cp -rf "${WORKDIR}/BUILDTMP/LOBECHAT/.next/static" "${WORKDIR}/BUILDKIT/lobechat/.next/static" && cp -rf "${WORKDIR}/BUILDTMP/LOBECHAT/public" "${WORKDIR}/BUILDKIT/lobechat/public"

FROM node:current-alpine AS REBASED_LOBECHAT

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=BUILD_LOBECHAT /tmp/BUILDKIT/lobechat /opt/lobechat

RUN sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" \
    && apk update \
    && apk add --no-cache proxychains-ng \
    && apk upgrade --no-cache \
    && rm -rf /tmp/* /var/cache/apk/*

FROM scratch

ENV NODE_TLS_REJECT_UNAUTHORIZED="0" FEATURE_FLAGS="-check_updates,-welcome_suggest,+webrtc_sync" HOSTNAME="0.0.0.0" PORT="3210" PROXY_URL=""

COPY --from=REBASED_LOBECHAT / /

EXPOSE 3210/tcp

CMD if [ -n "$PROXY_URL" ]; then \
        echo -e "localnet 127.0.0.0/255.0.0.0\nlocalnet ::1/128\nproxy_dns\nremote_dns_subnet 224\nstrict_chain\ntcp_connect_time_out 8000\ntcp_read_time_out 15000\n[ProxyList]\n$(echo $PROXY_URL | cut -d: -f1) $(echo $PROXY_URL | cut -d/ -f3 | cut -d: -f1) $(echo $PROXY_URL | cut -d: -f3)" > /etc/proxychains/proxychains.conf; \
        proxychains node /opt/lobechat/server.js; \
    else \
        node /opt/lobechat/server.js; \
    fi
