# Current Version: 1.0.3

ARG NODEJS_VERSION="24"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.rsshub" > "${WORKDIR}/rsshub.json" \
    && cat "${WORKDIR}/rsshub.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/rsshub.json" | jq -Sr ".source" > "${WORKDIR}/rsshub.source.autobuild" \
    && cat "${WORKDIR}/rsshub.json" | jq -Sr ".source_branch" > "${WORKDIR}/rsshub.source_branch.autobuild" \
    && cat "${WORKDIR}/rsshub.json" | jq -Sr ".patch" > "${WORKDIR}/rsshub.patch.autobuild" \
    && cat "${WORKDIR}/rsshub.json" | jq -Sr ".patch_branch" > "${WORKDIR}/rsshub.patch_branch.autobuild" \
    && cat "${WORKDIR}/rsshub.json" | jq -Sr ".version" > "${WORKDIR}/rsshub.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/rsshub.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/rsshub.source.autobuild") "${WORKDIR}/BUILDTMP/RSSHUB" \
    && git clone -b $(cat "${WORKDIR}/rsshub.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/rsshub.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER"\
    && export RSSHUB_SHA=$(cd "${WORKDIR}/BUILDTMP/RSSHUB" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export RSSHUB_VERSION=$(cat "${WORKDIR}/rsshub.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export RSSHUB_CUSTOM_VERSION="${RSSHUB_VERSION}-ZHIJIE-${RSSHUB_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/RSSHUB" \
    && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/rsshub/*.patch \
    && sed -i "s/\"version\": \".*\"/\"version\": \"${RSSHUB_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/RSSHUB/package.json"

FROM node:${NODEJS_VERSION}-slim AS build_baseos

ENV DEBIAN_FRONTEND="noninteractive"

RUN \
    apt update \
    && apt install proxychains-ng -qy \
    && mkdir -p /distroless/bin /distroless/etc /distroless/lib \
    && cp /usr/lib/$(arch)-linux-gnu/libstdc++.so.6 /distroless/lib/libstdc++.so.6 \
    && cp /usr/lib/$(arch)-linux-gnu/libgcc_s.so.1 /distroless/lib/libgcc_s.so.1 \
    && cp /usr/local/bin/node /distroless/bin/node \
    && cp /usr/lib/$(arch)-linux-gnu/libproxychains.so.4 /distroless/lib/libproxychains.so.4 \
    && cp /usr/lib/$(arch)-linux-gnu/libdl.so.2 /distroless/lib/libdl.so.2 \
    && cp /usr/bin/proxychains4 /distroless/bin/proxychains \
    && cp /etc/proxychains4.conf /distroless/etc/proxychains4.conf \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM build_baseos AS build_rsshub

WORKDIR /app

COPY --from=get_info /tmp/BUILDTMP/RSSHUB/patches ./patches

COPY --from=get_info /tmp/BUILDTMP/RSSHUB/package.json ./package.json
COPY --from=get_info /tmp/BUILDTMP/RSSHUB/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=get_info /tmp/BUILDTMP/RSSHUB/tsconfig.json ./tsconfig.json

RUN \
    apt update \
    && apt install -qy git python3 python3-pip \
    && export COREPACK_NPM_REGISTRY=$(npm config get registry | sed 's/\/$//') \
    && npm i -g corepack@latest \
    && corepack enable \
    && corepack use $(sed -n 's/.*"packageManager": "\(.*\)".*/\1/p' package.json) \
    && pnpm i \
    && pnpm rb \
    && pnpm add @vercel/nft@$(grep -Po '(?<="@vercel/nft": ")[^\s"]*(?=")' package.json) fs-extra@$(grep -Po '(?<="fs-extra": ")[^\s"]*(?=")' package.json) --save-prod

COPY --from=get_info /tmp/BUILDTMP/RSSHUB/ .

ENV \
    PROJECT_ROOT="/app"

RUN \
    pnpm run build \
    && node scripts/docker/minify-docker.js

FROM busybox:latest AS rebased_rsshub

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_baseos /distroless/ /

COPY --from=build_rsshub /app/dist /app/

COPY --from=build_rsshub /app/startServer.js /app/startServer.js

COPY --from=build_rsshub /app/app-minimal/node_modules /app/node_modules

FROM scratch

ENV \
    NODE_ENV="production" NODE_TLS_REJECT_UNAUTHORIZED="" \
    NODE_OPTIONS="--dns-result-order=ipv4first --use-openssl-ca" NODE_EXTRA_CA_CERTS="" \
    SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt" \
    DEBUG_INFO="some_string" LOGGER_LEVEL="info" \
    LISTEN_INADDR_ANY="true" PORT="1200" PROXY_URI="" \
    ACCESS_KEY="" \
    CACHE_TYPE="memory" REDIS_URL="" \
    PUPPETEER_WS_ENDPOINT=""

COPY --from=rebased_rsshub / /

EXPOSE 1200/tcp

ENTRYPOINT ["/bin/node"]

CMD ["/app/startServer.js"]
