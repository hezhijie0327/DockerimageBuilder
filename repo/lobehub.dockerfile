# Current Version: 1.8.6

ARG NODEJS_VERSION="24"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.lobehub" > "${WORKDIR}/lobehub.json" \
    && cat "${WORKDIR}/lobehub.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/lobehub.json" | jq -Sr ".source" > "${WORKDIR}/lobehub.source.autobuild" \
    && cat "${WORKDIR}/lobehub.json" | jq -Sr ".source_branch" > "${WORKDIR}/lobehub.source_branch.autobuild" \
    && cat "${WORKDIR}/lobehub.json" | jq -Sr ".patch" > "${WORKDIR}/lobehub.patch.autobuild" \
    && cat "${WORKDIR}/lobehub.json" | jq -Sr ".patch_branch" > "${WORKDIR}/lobehub.patch_branch.autobuild" \
    && cat "${WORKDIR}/lobehub.json" | jq -Sr ".version" > "${WORKDIR}/lobehub.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/lobehub.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/lobehub.source.autobuild") "${WORKDIR}/BUILDTMP/LOBEHUB" \
    && git clone -b $(cat "${WORKDIR}/lobehub.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/lobehub.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER"\
    && export LOBEHUB_SHA=$(cd "${WORKDIR}/BUILDTMP/LOBEHUB" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export LOBEHUB_VERSION=$(cat "${WORKDIR}/lobehub.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export LOBEHUB_CUSTOM_VERSION="${LOBEHUB_VERSION}-ZHIJIE-${LOBEHUB_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/LOBEHUB" \
    && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/lobehub/*.patch \
    && sed -i "s/\"version\": \".*\"/\"version\": \"${LOBEHUB_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/LOBEHUB/package.json"

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

FROM build_baseos AS build_lobehub

ENV \
    NODE_OPTIONS="--max-old-space-size=8192" \
    NEXT_PUBLIC_ENABLE_BETTER_AUTH="1" \
    NEXT_PUBLIC_ENABLE_NEXT_AUTH="0" \
    NEXT_PUBLIC_SERVICE_MODE="server" \
    PNPM_HOME="/pnpm" \
    APP_URL="http://app.com" \
    DATABASE_DRIVER="node" \
    DATABASE_URL="postgres://postgres:password@localhost:5432/postgres" \
    KEY_VAULTS_SECRET="use-for-build" \
    FEATURE_FLAGS="-check_updates,-welcome_suggest"

WORKDIR /app

COPY --from=get_info /tmp/BUILDTMP/LOBEHUB/apps/desktop/src/main/package.json ./apps/desktop/src/main/package.json
COPY --from=get_info /tmp/BUILDTMP/LOBEHUB/package.json /tmp/BUILDTMP/LOBEHUB/pnpm-workspace.yaml ./
COPY --from=get_info /tmp/BUILDTMP/LOBEHUB/.npmrc ./
COPY --from=get_info /tmp/BUILDTMP/LOBEHUB/packages ./packages
COPY --from=get_info /tmp/BUILDTMP/LOBEHUB/patches ./patches

RUN \
    export COREPACK_NPM_REGISTRY=$(npm config get registry | sed 's/\/$//') \
    && npm i -g corepack@latest \
    && corepack enable \
    && corepack use $(sed -n 's/.*"packageManager": "\(.*\)".*/\1/p' package.json) \
    && pnpm i \
    && mkdir -p /deps \
    && cd /deps \
    && pnpm init \
    && pnpm add pg drizzle-orm

COPY --from=get_info /tmp/BUILDTMP/LOBEHUB/ .

RUN \
    npm run build:docker

FROM busybox:latest AS rebased_lobehub

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_baseos /distroless/ /

COPY --from=build_lobehub /app/.next/standalone /app/

COPY --from=build_lobehub /app/packages/database/migrations /app/migrations
COPY --from=build_lobehub /app/scripts/migrateServerDB/docker.cjs /app/docker.cjs
COPY --from=build_lobehub /app/scripts/migrateServerDB/errorHint.js /app/errorHint.js

COPY --from=build_lobehub /deps/node_modules/.pnpm /app/node_modules/.pnpm
COPY --from=build_lobehub /deps/node_modules/pg /app/node_modules/pg
COPY --from=build_lobehub /deps/node_modules/drizzle-orm /app/node_modules/drizzle-orm

COPY --from=build_lobehub /app/scripts/serverLauncher/startServer.js /app/startServer.js

FROM scratch

ENV \
    DATABASE_DRIVER="node" \
    NODE_ENV="production" NODE_TLS_REJECT_UNAUTHORIZED="" \
    NODE_OPTIONS="--dns-result-order=ipv4first --use-openssl-ca" NODE_EXTRA_CA_CERTS="" \
    SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt" \
    MIDDLEWARE_REWRITE_THROUGH_LOCAL="1" \
    NEXT_AUTH_SSO_SESSION_STRATEGY="database" \
    NEXT_PUBLIC_ENABLE_BETTER_AUTH="1" NEXT_PUBLIC_ENABLE_NEXT_AUTH="0" ENABLE_MAGIC_LINK="1" AUTH_EMAIL_VERIFICATION="0" \
    FEATURE_FLAGS="-check_updates,-welcome_suggest" \
    HOSTNAME="0.0.0.0" PORT="3210"

COPY --from=rebased_lobehub / /

EXPOSE 3210/tcp

ENTRYPOINT ["/bin/node"]

CMD ["/app/startServer.js"]
