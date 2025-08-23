# Current Version: 1.0.2

ARG NODEJS_VERSION="22"
ARG RUST_VERSION="1"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.rustfs" > "${WORKDIR}/rustfs.json" \
    && cat "${WORKDIR}/rustfs.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/rustfs.json" | jq -Sr ".source" > "${WORKDIR}/rustfs.source.autobuild" \
    && cat "${WORKDIR}/rustfs.json" | jq -Sr ".source_branch" > "${WORKDIR}/rustfs.source_branch.autobuild" \
    && cat "${WORKDIR}/rustfs.json" | jq -Sr ".patch" > "${WORKDIR}/rustfs.patch.autobuild" \
    && cat "${WORKDIR}/rustfs.json" | jq -Sr ".patch_branch" > "${WORKDIR}/rustfs.patch_branch.autobuild" \
    && cat "${WORKDIR}/rustfs.json" | jq -Sr ".version" > "${WORKDIR}/rustfs.version.autobuild" \
    && cat "/opt/package.json" | jq -Sr ".repo.rustfs_web" > "${WORKDIR}/rustfs_web.json" \
    && cat "${WORKDIR}/rustfs_web.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/rustfs_web.json" | jq -Sr ".source" > "${WORKDIR}/rustfs_web.source.autobuild" \
    && cat "${WORKDIR}/rustfs_web.json" | jq -Sr ".source_branch" > "${WORKDIR}/rustfs_web.source_branch.autobuild" \
    && cat "${WORKDIR}/rustfs_web.json" | jq -Sr ".patch" > "${WORKDIR}/rustfs_web.patch.autobuild" \
    && cat "${WORKDIR}/rustfs_web.json" | jq -Sr ".patch_branch" > "${WORKDIR}/rustfs_web.patch_branch.autobuild" \
    && cat "${WORKDIR}/rustfs_web.json" | jq -Sr ".version" > "${WORKDIR}/rustfs_web.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/rustfs.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/rustfs.source.autobuild") "${WORKDIR}/BUILDTMP/RUSTFS" \
    && git clone -b $(cat "${WORKDIR}/rustfs.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/rustfs.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && git clone -b $(cat "${WORKDIR}/rustfs_web.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/rustfs_web.source.autobuild") "${WORKDIR}/BUILDTMP/RUSTFS_WEB" \
    && export RUSTFS_SHA=$(cd "${WORKDIR}/BUILDTMP/RUSTFS" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export RUSTFS_VERSION=$(cat "${WORKDIR}/rustfs.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export RUSTFS_CUSTOM_VERSION="${RUSTFS_VERSION}-ZHIJIE-${RUSTFS_SHA}${PATCH_SHA}" \
    && echo "${RUSTFS_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/RUSTFS/RUSTFS_CUSTOM_VERSION" \
    && echo "${RUSTFS_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/RUSTFS_WEB/RUSTFS_CUSTOM_VERSION" \
    && cd "${WORKDIR}/BUILDTMP/RUSTFS" \
    && git tag ${RUSTFS_CUSTOM_VERSION}

FROM node:${NODEJS_VERSION}-slim AS build_rustfs_web

WORKDIR /rustfs

COPY --from=get_info /tmp/BUILDTMP/RUSTFS_WEB /rustfs

RUN \
    npm i \
    && npm run generate

FROM rust:${RUST_VERSION}-alpine AS build_rustfs

ENV CARGO_NET_GIT_FETCH_WITH_CLI=true \
    CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse \
    CARGO_INCREMENTAL=0 \
    CARGO_PROFILE_RELEASE_DEBUG=false \
    CARGO_PROFILE_RELEASE_SPLIT_DEBUGINFO=off \
    CARGO_PROFILE_RELEASE_STRIP=symbols

WORKDIR /rustfs

COPY --from=get_info /tmp/BUILDTMP/RUSTFS /rustfs

COPY --from=build_rustfs_web /rustfs/.output/public /rustfs/rustfs/static

RUN \
    apk add --no-cache \
        build-base \
        ca-certificates \
        curl \
        git \
        pkgconfig \
        openssl-dev \
        lld \
        protobuf-dev \
        protobuf \
        flatbuffers \
        flatbuffers-dev \
    && mkdir -p /opt/rustfs/data /opt/rustfs/logs \
    && touch "./rustfs/build.rs" \
    && cargo run --bin gproto \
    && cargo build --release --bin rustfs -j "$(nproc)"

FROM scratch AS rebased_rustfs

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_rustfs /rustfs/target/release/rustfs /rustfs
COPY --from=build_rustfs /opt/rustfs/ /

FROM scratch

ENV \
    RUST_LOG="warn" \
    RUSTFS_ADDRESS=":9000" RUSTFS_CONSOLE_ENABLE="true" \
    RUSTFS_ACCESS_KEY="rustfsadmin" RUSTFS_SECRET_KEY="rustfsadmin" \
    RUSTFS_VOLUMES="/data" \
    RUSTFS_OBS_LOG_DIRECTORY="/logs" RUSTFS_SINKS_FILE_PATH="/logs" \
    RUSTFS_TLS_PATH=""

COPY --from=rebased_rustfs / /

EXPOSE 9000/tcp

ENTRYPOINT ["/rustfs"]
