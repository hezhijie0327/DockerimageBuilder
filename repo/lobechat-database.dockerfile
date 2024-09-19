# Current Version: 1.1.9

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".repo.lobechat" > "${WORKDIR}/lobechat.json" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".version" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".source" > "${WORKDIR}/lobechat.source.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".source_branch" > "${WORKDIR}/lobechat.source_branch.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".patch" > "${WORKDIR}/lobechat.patch.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".patch_branch" > "${WORKDIR}/lobechat.patch_branch.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".version" > "${WORKDIR}/lobechat.version.autobuild"

FROM --platform=linux/amd64 hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu AS BUILD_LOBECHAT

WORKDIR /tmp

COPY --from=GET_INFO /tmp/lobechat.*.autobuild /tmp/

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

ENV NEXT_PUBLIC_SERVICE_MODE="server" \
    APP_URL="http://app.com" \
    DATABASE_DRIVER="node" \
    DATABASE_URL="postgres://postgres:password@localhost:5432/postgres" \
    KEY_VAULTS_SECRET="use-for-build"

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDTMP" && export PREFIX="${WORKDIR}/BUILDLIB" && export PNPM_HOME="/pnpm" && export PATH="${PNPM_HOME}:${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/lobechat.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/lobechat.source.autobuild") "${WORKDIR}/BUILDTMP/LOBECHAT" && git clone -b $(cat "${WORKDIR}/lobechat.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/lobechat.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export LOBECHAT_SHA=$(cd "${WORKDIR}/BUILDTMP/LOBECHAT" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export LOBECHAT_VERSION=$(cat "${WORKDIR}/lobechat.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export LOBECHAT_CUSTOM_VERSION="${LOBECHAT_VERSION}-ZHIJIE-${LOBECHAT_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/LOBECHAT" && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/lobechat/*.patch && sed -i "s/\"version\": \"[0-9]\+\.[0-9]\+\.[0-9]\+\"/\"version\": \"${LOBECHAT_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/LOBECHAT/package.json" && corepack enable && corepack use pnpm && pnpm i && mkdir -p "${WORKDIR}/BUILDTMP/LOBECHAT/deps" && pnpm add sharp pg drizzle-orm --prefix "${WORKDIR}/BUILDTMP/LOBECHAT/deps" && npm run build:docker

FROM node:lts-slim AS BUILD_BASEOS

ENV DEBIAN_FRONTEND="noninteractive"

RUN sed -i "s/deb.debian.org/mirrors.ustc.edu.cn/g" "/etc/apt/sources.list.d/debian.sources" \
    && apt update \
    && apt install proxychains-ng -qy \
    && mkdir -p /distroless/bin /distroless/etc /distroless/lib \
    && cp /usr/lib/$(arch)-linux-gnu/libproxychains.so.4 /distroless/lib/libproxychains.so.4 \
    && cp /usr/lib/$(arch)-linux-gnu/libdl.so.2 /distroless/lib/libdl.so.2 \
    && cp /usr/bin/proxychains4 /distroless/bin/proxychains \
    && cp /etc/proxychains4.conf /distroless/etc/proxychains4.conf \
    && cp /usr/lib/$(arch)-linux-gnu/libstdc++.so.6 /distroless/lib/libstdc++.so.6 \
    && cp /usr/lib/$(arch)-linux-gnu/libgcc_s.so.1 /distroless/lib/libgcc_s.so.1 \
    && cp /usr/local/bin/node /distroless/bin/node \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM busybox:latest AS REBASED_LOBECHAT

COPY --from=BUILD_BASEOS /distroless/ /

COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/.next/standalone /app
COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/.next/static /app/.next/static

COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/public /app/public

COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/deps/node_modules/.pnpm /app/node_modules/.pnpm
COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/deps/node_modules/drizzle-orm /app/node_modules/drizzle-orm
COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/deps/node_modules/pg /app/node_modules/pg

COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/src/database/server/migrations /app/migrations
COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/scripts/migrateServerDB/docker.cjs /app/docker.cjs
COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/scripts/migrateServerDB/errorHint.js /app/errorHint.js

COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/scripts/serverLauncher/startServer.js /app/startServer.js

RUN \
    # Add nextjs:nodejs to run the app
    addgroup -S -g 1001 nodejs \
    && adduser -D -G nodejs -H -S -h /app -u 1001 nextjs \
    # Set permission for nextjs:nodejs
    && chown -R nextjs:nodejs /app /etc/proxychains4.conf

FROM scratch

ENV NODE_ENV="production" NODE_TLS_REJECT_UNAUTHORIZED="1" \
    FEATURE_FLAGS="-check_updates,-welcome_suggest" \
    HOSTNAME="0.0.0.0" PORT="3210" \
    DATABASE_DRIVER="node"

COPY --from=REBASED_LOBECHAT / /

USER nextjs

EXPOSE 3210/tcp

CMD ["node", "/app/startServer.js"]
