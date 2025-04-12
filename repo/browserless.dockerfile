# Current Version: 1.1.5

ARG NODEJS_VERSION="22"
ARG PLAYWRIGHT_CORE="chromium" # chromium, firefox, webkit, chrome, edge

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.browserless" > "${WORKDIR}/browserless.json" \
    && cat "${WORKDIR}/browserless.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/browserless.json" | jq -Sr ".source" > "${WORKDIR}/browserless.source.autobuild" \
    && cat "${WORKDIR}/browserless.json" | jq -Sr ".source_branch" > "${WORKDIR}/browserless.source_branch.autobuild" \
    && cat "${WORKDIR}/browserless.json" | jq -Sr ".patch" > "${WORKDIR}/browserless.patch.autobuild" \
    && cat "${WORKDIR}/browserless.json" | jq -Sr ".patch_branch" > "${WORKDIR}/browserless.patch_branch.autobuild" \
    && cat "${WORKDIR}/browserless.json" | jq -Sr ".version" > "${WORKDIR}/browserless.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/browserless.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/browserless.source.autobuild") "${WORKDIR}/BUILDTMP/BROWSERLESS" \
    && git clone -b $(cat "${WORKDIR}/browserless.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/browserless.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER"\
    && export BROWSERLESS_SHA=$(cd "${WORKDIR}/BUILDTMP/BROWSERLESS" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export BROWSERLESS_VERSION=$(cat "${WORKDIR}/browserless.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export BROWSERLESS_CUSTOM_VERSION="${BROWSERLESS_VERSION}-ZHIJIE-${BROWSERLESS_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/BROWSERLESS" \
    && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/browserless/*.patch \
    && sed -i "s/\"version\": \"[0-9]\+\.[0-9]\+\.[0-9]\+\"/\"version\": \"${BROWSERLESS_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/BROWSERLESS/package.json"

FROM node:${NODEJS_VERSION}-slim AS build_browserless

ARG PLAYWRIGHT_CORE

ENV \
    DEBIAN_FRONTEND="noninteractive" \
    PLAYWRIGHT_BROWSERS_PATH="/app/playwright-browsers" \
    PLAYWRIGHT_CORE="${PLAYWRIGHT_CORE}"

WORKDIR /app

COPY --from=get_info /tmp/BUILDTMP/BROWSERLESS/assets /app/assets
COPY --from=get_info /tmp/BUILDTMP/BROWSERLESS/bin /app/bin
COPY --from=get_info /tmp/BUILDTMP/BROWSERLESS/extensions /app/extensions
COPY --from=get_info /tmp/BUILDTMP/BROWSERLESS/external /app/external
COPY --from=get_info /tmp/BUILDTMP/BROWSERLESS/scripts /app/scripts
COPY --from=get_info /tmp/BUILDTMP/BROWSERLESS/static /app/static

COPY --from=get_info /tmp/BUILDTMP/BROWSERLESS/package.json /app/package.json
COPY --from=get_info /tmp/BUILDTMP/BROWSERLESS/package-lock.json /app/package-lock.json
COPY --from=get_info /tmp/BUILDTMP/BROWSERLESS/tsconfig.json /app/tsconfig.json

COPY --from=get_info /tmp/BUILDTMP/BROWSERLESS/startServer.cjs /app/startServer.cjs

RUN \
    npm i --production=false

COPY --from=get_info /tmp/BUILDTMP/BROWSERLESS/fonts/* /usr/share/fonts/truetype/
COPY --from=get_info /tmp/BUILDTMP/BROWSERLESS/src /app/src

RUN \
    rm -rf /app/src/routes

COPY --from=get_info /tmp/BUILDTMP/BROWSERLESS/src/routes/management /app/src/routes/management
COPY --from=get_info /tmp/BUILDTMP/BROWSERLESS/src/routes/${PLAYWRIGHT_CORE} /app/src/routes/${PLAYWRIGHT_CORE}

RUN \
    if [ "${PLAYWRIGHT_CORE}" = "edge" ]; then \
        PLAYWRIGHT_CORE="msedge"; \
    fi \
    && ./node_modules/playwright-core/cli.js install --with-deps ${PLAYWRIGHT_CORE} \
    && npm run build \
    && npm run build:function \
    && npm prune production \
    && npm run install:debugger \
    && fc-cache -f -v \
    && apt-get -qq clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/fonts/truetype/noto

RUN \
    mkdir -p /distroless/bin /distroless/lib \
    && cp /usr/lib/$(arch)-linux-gnu/libdl.so.2 /distroless/lib/libdl.so.2 \
    && cp /usr/lib/$(arch)-linux-gnu/libstdc++.so.6 /distroless/lib/libstdc++.so.6 \
    && cp /usr/lib/$(arch)-linux-gnu/libgcc_s.so.1 /distroless/lib/libgcc_s.so.1 \
    && cp /usr/lib/$(arch)-linux-gnu/*.so* /distroless/lib/ \
    && cp /usr/local/bin/node /distroless/bin/node \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM busybox:latest AS rebased_browserless

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_browserless /distroless /

COPY --from=build_browserless /app /app

COPY --from=build_browserless /usr/share/fonts/truetype/ /usr/share/fonts/truetype/

FROM scratch

ENV \
    NODE_ENV="production" NODE_TLS_REJECT_UNAUTHORIZED="" \
    NODE_OPTIONS="--dns-result-order=ipv4first --use-openssl-ca" NODE_EXTRA_CA_CERTS="" \
    SSL_CERT_DIR="/etc/ssl/certs/ca-certificates.crt" \
    PLAYWRIGHT_BROWSERS_PATH="/app/playwright-browsers" \
    ALL_PROXY="" HTTPS_PROXY="" HTTP_PROXY="" NO_PROXY="" \
    HOST="0.0.0.0" PORT="3000" TOKEN="6R0W53R135510" \
    ALLOW_GET="false" ALLOW_FILE_PROTOCOL="false" \
    HEALTH="true" MAX_CPU_PERCENT="75" MAX_MEMORY_PERCENT="75" \
    CORS="true" CORS_ALLOW_METHODS="" CORS_ALLOW_ORIGIN="" CORS_MAX_AGE="2592000" \
    CONCURRENT="5" QUEUED="5" TIMEOUT="90000" \
    DATA_DIR="" DOWNLOAD_DIR="" \
    METRICS_JSON_PATH=""

COPY --from=rebased_browserless / /

ENTRYPOINT ["/bin/node"]

CMD ["/app/startServer.cjs"]
