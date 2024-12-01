# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".repo.perplexica" > "${WORKDIR}/perplexica.json" && cat "${WORKDIR}/perplexica.json" | jq -Sr ".version" && cat "${WORKDIR}/perplexica.json" | jq -Sr ".source" > "${WORKDIR}/perplexica.source.autobuild" && cat "${WORKDIR}/perplexica.json" | jq -Sr ".source_branch" > "${WORKDIR}/perplexica.source_branch.autobuild" && cat "${WORKDIR}/perplexica.json" | jq -Sr ".patch" > "${WORKDIR}/perplexica.patch.autobuild" && cat "${WORKDIR}/perplexica.json" | jq -Sr ".patch_branch" > "${WORKDIR}/perplexica.patch_branch.autobuild" && cat "${WORKDIR}/perplexica.json" | jq -Sr ".version" > "${WORKDIR}/perplexica.version.autobuild"

RUN echo "master" > "/tmp/perplexica.source_branch.autobuild" && echo "main" > "/tmp/perplexica.patch_branch.autobuild" && echo "https://github.com/ItzCrazyKns/Perplexica" > "/tmp/perplexica.source.autobuild" && echo "https://github.com/hezhijie0327/DockerimageBuilder" > "/tmp/perplexica.patch.autobuild" && echo "1.0.0" > "/tmp/perplexica.version.autobuild"

FROM --platform=linux/amd64 hezhijie0327/module:nodejs AS BUILD_NODEJS

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu AS BUILD_PERPLEXICA

WORKDIR /tmp

COPY --from=GET_INFO /tmp/perplexica.*.autobuild /tmp/

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDTMP" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PNPM_HOME}:${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/perplexica.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/perplexica.source.autobuild") "${WORKDIR}/BUILDTMP/PERPLEXICA" && git clone -b $(cat "${WORKDIR}/perplexica.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/perplexica.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export PERPLEXICA_SHA=$(cd "${WORKDIR}/BUILDTMP/PERPLEXICA" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export PERPLEXICA_VERSION=$(cat "${WORKDIR}/perplexica.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export PERPLEXICA_CUSTOM_VERSION="${PERPLEXICA_VERSION}-ZHIJIE-${PERPLEXICA_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/PERPLEXICA" && npm i && npm npm run build && cd ui && npm i && npm run build

FROM node:20-alpine AS REBASED_PERPLEXICA

ENV DEBIAN_FRONTEND="noninteractive"

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=BUILD_PERPLEXICA /tmp/BUILDTMP/PERPLEXICA/.next /app/frontend/.next
COPY --from=BUILD_PERPLEXICA /tmp/BUILDTMP/PERPLEXICA/node_modules /app/frontend/node_modules
COPY --from=BUILD_PERPLEXICA /tmp/BUILDTMP/PERPLEXICA/package.json /app/frontend/package.json
COPY --from=BUILD_PERPLEXICA /tmp/BUILDTMP/PERPLEXICA/public /app/frontend/public

COPY --from=BUILD_PERPLEXICA /tmp/BUILDTMP/PERPLEXICA/ui/dist /app/backend/dist
COPY --from=BUILD_PERPLEXICA /tmp/BUILDTMP/PERPLEXICA/ui/node_modules /app/backend/node_modules
COPY --from=BUILD_PERPLEXICA /tmp/BUILDTMP/PERPLEXICA/ui/drizzle.config.ts /app/backend/drizzle.config.ts
COPY --from=BUILD_PERPLEXICA /tmp/BUILDTMP/PERPLEXICA/ui/tsconfig.json /app/backend/tsconfig.json
COPY --from=BUILD_PERPLEXICA /tmp/BUILDTMP/PERPLEXICA/ui/src/db/schema.ts /app/backend/src/db/schema.ts
COPY --from=BUILD_PERPLEXICA /tmp/BUILDTMP/PERPLEXICA/ui/package.json /app/backend/package.json

FROM scratch

ENV NEXT_PUBLIC_API_URL="http://localhost:3001/api" \
    NEXT_PUBLIC_WS_URL="ws://localhost:3001"

COPY --from=REBASED_PERPLEXICA / /

EXPOSE 3000/tcp 3001/tcp

CMD \
    cd /app/backend && npm run start & \
    cd /app/frontend && npm run start
