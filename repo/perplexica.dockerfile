# Current Version: 1.0.1

ARG NODEJS_VERSION="20"

FROM hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.perplexica" > "${WORKDIR}/perplexica.json" \
    && cat "${WORKDIR}/perplexica.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/perplexica.json" | jq -Sr ".source" > "${WORKDIR}/perplexica.source.autobuild" \
    && cat "${WORKDIR}/perplexica.json" | jq -Sr ".source_branch" > "${WORKDIR}/perplexica.source_branch.autobuild" \
    && cat "${WORKDIR}/perplexica.json" | jq -Sr ".patch" > "${WORKDIR}/perplexica.patch.autobuild" \
    && cat "${WORKDIR}/perplexica.json" | jq -Sr ".patch_branch" > "${WORKDIR}/perplexica.patch_branch.autobuild" \
    && cat "${WORKDIR}/perplexica.json" | jq -Sr ".version" > "${WORKDIR}/perplexica.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/perplexica.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/perplexica.source.autobuild") "${WORKDIR}/BUILDTMP/PERPLEXICA" \
    && git clone -b $(cat "${WORKDIR}/perplexica.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/perplexica.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER"\
    && export PERPLEXICA_SHA=$(cd "${WORKDIR}/BUILDTMP/PERPLEXICA" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export PERPLEXICA_VERSION=$(cat "${WORKDIR}/perplexica.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export PERPLEXICA_CUSTOM_VERSION="${PERPLEXICA_VERSION}-ZHIJIE-${PERPLEXICA_SHA}${PATCH_SHA}" \
    && sed -i "s/\"version\": \"[0-9]\+\.[0-9]\+\.[0-9]\+\"/\"version\": \"${PERPLEXICA_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/PERPLEXICA/package.json"

FROM node:${NODEJS_VERSION}-slim AS build_baseos

ENV DEBIAN_FRONTEND="noninteractive"

RUN \
    mkdir -p /distroless/bin /distroless/lib \
    && cp /usr/lib/$(arch)-linux-gnu/libdl.so.2 /distroless/lib/libdl.so.2 \
    && cp /usr/lib/$(arch)-linux-gnu/librt.so.1 /distroless/lib/librt.so.1 \
    && cp /usr/lib/$(arch)-linux-gnu/libstdc++.so.6 /distroless/lib/libstdc++.so.6 \
    && cp /usr/lib/$(arch)-linux-gnu/libgcc_s.so.1 /distroless/lib/libgcc_s.so.1 \
    && cp /usr/local/bin/node /distroless/bin/node \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM build_baseos AS build_perplexica

WORKDIR /app

COPY --from=get_info /tmp/BUILDTMP/PERPLEXICA/ .

RUN \
    yarn install --frozen-lockfile --network-timeout 600000 \
    && yarn build

FROM busybox:latest AS rebased_perplexica

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_baseos /distroless/ /

COPY --from=build_perplexica /app/.next/standalone /app/
COPY --from=build_perplexica /app/public /app/

COPY --from=build_perplexica /app/.next/static /app/public/_next/static

COPY --from=build_perplexica /app/data /app/data
COPY --from=build_perplexica /app/data /app/uploads
COPY --from=build_perplexica /app/sample.config.toml /app/config.toml

FROM scratch

ENV \
    HOSTNAME="0.0.0.0" PORT="3000" \
    SEARXNG_API_URL="http://127.0.0.1:8080"

COPY --from=rebased_perplexica / /

EXPOSE 3000/tcp

ENTRYPOINT ["/bin/node"]

CMD ["/app/server.js"]
