# Current Version: 1.0.0

ARG BUN_VERSION="1"

FROM hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.morphic" > "${WORKDIR}/morphic.json" \
    && cat "${WORKDIR}/morphic.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/morphic.json" | jq -Sr ".source" > "${WORKDIR}/morphic.source.autobuild" \
    && cat "${WORKDIR}/morphic.json" | jq -Sr ".source_branch" > "${WORKDIR}/morphic.source_branch.autobuild" \
    && cat "${WORKDIR}/morphic.json" | jq -Sr ".patch" > "${WORKDIR}/morphic.patch.autobuild" \
    && cat "${WORKDIR}/morphic.json" | jq -Sr ".patch_branch" > "${WORKDIR}/morphic.patch_branch.autobuild" \
    && cat "${WORKDIR}/morphic.json" | jq -Sr ".version" > "${WORKDIR}/morphic.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/morphic.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/morphic.source.autobuild") "${WORKDIR}/BUILDTMP/MORPHIC" \
    && git clone -b $(cat "${WORKDIR}/morphic.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/morphic.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER"\
    && export MORPHIC_SHA=$(cd "${WORKDIR}/BUILDTMP/MORPHIC" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export MORPHIC_VERSION=$(cat "${WORKDIR}/morphic.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export MORPHIC_CUSTOM_VERSION="${MORPHIC_VERSION}-ZHIJIE-${MORPHIC_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/MORPHIC" \
    && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/morphic/*.patch \
    && sed -i "s/\"version\": \"[0-9]\+\.[0-9]\+\.[0-9]\+\"/\"version\": \"${MORPHIC_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/MORPHIC/package.json"

FROM oven/bun:${BUN_VERSION}-slim AS build_baseos

ENV DEBIAN_FRONTEND="noninteractive"

RUN \
    mkdir -p /distroless/bin /distroless/lib \
    && cp /lib/ld-linux-$(arch).so.1 /distroless/lib/libdl.so.2 \
    && cp /usr/local/bin/bun /distroless/bin/bun \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM base AS build_morphic

ENV \
    DOCKER="true" \
    NODE_ENV="production"

WORKDIR /app

COPY --from=get_info /tmp/BUILDTMP/MORPHIC/package.json ./
COPY --from=get_info /tmp/BUILDTMP/MORPHIC/bun.lockb ./

RUN \
    bun install

COPY --from=get_info /tmp/BUILDTMP/MORPHIC/ .

RUN \
    bun next build

FROM busybox:latest AS rebased_morphic

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_baseos /distroless/ /

COPY --from=build_morphic /app/public /app/public
COPY --from=build_morphic /app/.next/standalone /app/
COPY --from=build_morphic /app/.next/static /app/.next/static

FROM scratch

ENV \
    HOSTNAME="0.0.0.0" \
    PORT="3000"

COPY --from=rebased_morphic / /

EXPOSE 3000/tcp

ENTRYPOINT ["/bin/bun"]

CMD ["/app/startServer.js"]
