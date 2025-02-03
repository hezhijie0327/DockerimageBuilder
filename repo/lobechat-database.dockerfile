# Current Version: 1.4.1

ARG NODEJS_VERSION="22"

FROM hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.lobechat" > "${WORKDIR}/lobechat.json" \
    && cat "${WORKDIR}/lobechat.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/lobechat.json" | jq -Sr ".source" > "${WORKDIR}/lobechat.source.autobuild" \
    && cat "${WORKDIR}/lobechat.json" | jq -Sr ".source_branch" > "${WORKDIR}/lobechat.source_branch.autobuild" \
    && cat "${WORKDIR}/lobechat.json" | jq -Sr ".patch" > "${WORKDIR}/lobechat.patch.autobuild" \
    && cat "${WORKDIR}/lobechat.json" | jq -Sr ".patch_branch" > "${WORKDIR}/lobechat.patch_branch.autobuild" \
    && cat "${WORKDIR}/lobechat.json" | jq -Sr ".version" > "${WORKDIR}/lobechat.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/lobechat.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/lobechat.source.autobuild") "${WORKDIR}/BUILDTMP/LOBECHAT" \
    && git clone -b $(cat "${WORKDIR}/lobechat.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/lobechat.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER"\
    && export LOBECHAT_SHA=$(cd "${WORKDIR}/BUILDTMP/LOBECHAT" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export LOBECHAT_VERSION=$(cat "${WORKDIR}/lobechat.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export LOBECHAT_CUSTOM_VERSION="${LOBECHAT_VERSION}-ZHIJIE-${LOBECHAT_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/LOBECHAT" \
    && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/lobechat/*.patch \
    && sed -i "s/\"version\": \"[0-9]\+\.[0-9]\+\.[0-9]\+\"/\"version\": \"${LOBECHAT_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/LOBECHAT/package.json"

FROM node:${NODEJS_VERSION}-slim AS build_baseos

ENV DEBIAN_FRONTEND="noninteractive"

RUN \
    apt update \
    && apt install jq proxychains-ng -qy \
    && mkdir -p /distroless/bin /distroless/etc /distroless/lib \
    && cp /usr/lib/$(arch)-linux-gnu/libproxychains.so.4 /distroless/lib/libproxychains.so.4 \
    && cp /usr/lib/$(arch)-linux-gnu/libdl.so.2 /distroless/lib/libdl.so.2 \
    && cp /usr/bin/proxychains4 /distroless/bin/proxychains \
    && cp /etc/proxychains4.conf /distroless/etc/proxychains4.conf \
    && cp /usr/lib/$(arch)-linux-gnu/libstdc++.so.6 /distroless/lib/libstdc++.so.6 \
    && cp /usr/lib/$(arch)-linux-gnu/libgcc_s.so.1 /distroless/lib/libgcc_s.so.1 \
    && cp /usr/local/bin/node /distroless/bin/node \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM build_baseos AS build_lobechat

ENV \
    NODE_OPTIONS="--max-old-space-size=8192" \
    NEXT_PUBLIC_SERVICE_MODE="server" \
    APP_URL="http://app.com" \
    DATABASE_DRIVER="node" \
    DATABASE_URL="postgres://postgres:password@localhost:5432/postgres" \
    KEY_VAULTS_SECRET="use-for-build"

WORKDIR /app

COPY --from=get_info /tmp/BUILDTMP/LOBECHAT/package.json ./
COPY --from=get_info /tmp/BUILDTMP/LOBECHAT/.npmrc ./

RUN \
    export PNPM_HOME="/pnpm" \
    && npm i -g $(jq -r .packageManager package.json) \
    && pnpm i \
    && mkdir -p /deps \
    && pnpm add sharp pg drizzle-orm --prefix /deps

COPY --from=get_info /tmp/BUILDTMP/LOBECHAT/ .

RUN npm run build:docker

FROM busybox:latest AS rebased_lobechat

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_baseos /distroless/ /

COPY --from=build_lobechat /app/public /app/public

COPY --from=build_lobechat /app/.next/standalone /app/
COPY --from=build_lobechat /app/.next/static /app/.next/static
COPY --from=build_lobechat /deps/node_modules/.pnpm /app/node_modules/.pnpm
COPY --from=build_lobechat /deps/node_modules/pg /app/node_modules/pg
COPY --from=build_lobechat /deps/node_modules/drizzle-orm /app/node_modules/drizzle-orm

COPY --from=build_lobechat /app/src/database/migrations /app/migrations
COPY --from=build_lobechat /app/scripts/migrateServerDB/docker.cjs /app/docker.cjs
COPY --from=build_lobechat /app/scripts/migrateServerDB/errorHint.js /app/errorHint.js

COPY --from=build_lobechat /app/scripts/serverLauncher/startServer.js /app/startServer.js

FROM scratch

ENV \
    DATABASE_DRIVER="node" \
    NODE_ENV="production" NODE_TLS_REJECT_UNAUTHORIZED="" \
    NODE_OPTIONS="--dns-result-order=ipv4first --use-openssl-ca" NODE_EXTRA_CA_CERTS="" \
    SSL_CERT_DIR="/etc/ssl/certs/ca-certificates.crt" \
    FEATURE_FLAGS="-check_updates,+pin_list,-welcome_suggest" \
    HOSTNAME="0.0.0.0" PORT="3210"

COPY --from=rebased_lobechat / /

EXPOSE 3210/tcp

ENTRYPOINT ["/bin/node"]

CMD ["/app/startServer.js"]
