# Current Version: 1.0.0

ARG NODEJS_VERSION="22"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && git clone -b main --depth=1 https://github.com/samanhappy/mcphub "${WORKDIR}/BUILDTMP/MCPHUB" \
    && git clone -b main --depth=1 https://github.com/hezhijie0327/DockerimageBuilder "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export MCPHUB_SHA=$(cd "${WORKDIR}/BUILDTMP/MCPHUB" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export MCPHUB_VERSION=$(cat "${WORKDIR}/mcphub.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export MCPHUB_CUSTOM_VERSION="${MCPHUB_VERSION}-ZHIJIE-${MCPHUB_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/MCPHUB" \
    && sed -i "s/\"version\": \"dev\"/\"version\": \"${MCPHUB_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/MCPHUB/package.json"

FROM node:${NODEJS_VERSION}-alpine AS build_mcphub

WORKDIR /app

COPY --from=get_info /tmp/BUILDTMP/MCPHUB/ .

RUN \
    corepack enable \
    && corepack use pnpm \
    && pnpm i \
    && pnpm build \
    && pnpm prune --prod

RUN \
    wget "https://astral.sh/uv/install.sh" \
    && sh install.sh

RUN \
    rm -rf /app/servers.json \
    && wget "https://mcpm.sh/api/servers.json"

FROM node:${NODEJS_VERSION}-alpine AS rebase_mcphub

COPY --from=build_mcphub /app/dist /app/dist
COPY --from=build_mcphub /app/node_modules /app/node_modules
COPY --from=build_mcphub /app/package.json /app/package.json

COPY --from=build_mcphub /app/frontend/dist /app/frontend/dist

COPY --from=build_mcphub /app/servers.json /app/servers.json

COPY --from=build_mcphub /root/.local/bin/ /bin/

RUN \
    apk update \
    && apk add --no-cache python3 \
    && apk upgrade --no-cache \
    && sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" \
    && rm -rf /tmp/* /var/cache/apk/*

FROM scratch

COPY --from=rebase_mcphub / /

EXPOSE 3000/tcp

ENTRYPOINT ["node"]

CMD ["/app/dist/index.js"]
