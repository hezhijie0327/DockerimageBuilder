# Current Version: 1.1.1

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

FROM scratch AS REBASED_LOBECHAT

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

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

FROM hezhijie0327/lobechat:base

ENV NODE_ENV="production" NODE_TLS_REJECT_UNAUTHORIZED="0" \
    DATABASE_DRIVER="node" \
    FEATURE_FLAGS="-check_updates,-welcome_suggest" \
    HOSTNAME="0.0.0.0" PORT="3210" \
    DEFAULT_AGENT_CONFIG="" SYSTEM_AGENT="" \
    PROXY_URL=""

COPY --from=REBASED_LOBECHAT --chown=nextjs:nodejs /app /app

USER nextjs

EXPOSE 3210/tcp 3211/tcp

CMD ["node", "/app/startServer.js"]
