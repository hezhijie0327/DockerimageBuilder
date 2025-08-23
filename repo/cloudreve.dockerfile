# Current Version: 1.0.0

ARG GOLANG_VERSION="1"
ARG NODEJS_VERSION="22"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.cloudreve" > "${WORKDIR}/cloudreve.json" \
    && cat "${WORKDIR}/cloudreve.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/cloudreve.json" | jq -Sr ".source" > "${WORKDIR}/cloudreve.source.autobuild" \
    && cat "${WORKDIR}/cloudreve.json" | jq -Sr ".source_branch" > "${WORKDIR}/cloudreve.source_branch.autobuild" \
    && cat "${WORKDIR}/cloudreve.json" | jq -Sr ".patch" > "${WORKDIR}/cloudreve.patch.autobuild" \
    && cat "${WORKDIR}/cloudreve.json" | jq -Sr ".patch_branch" > "${WORKDIR}/cloudreve.patch_branch.autobuild" \
    && cat "${WORKDIR}/cloudreve.json" | jq -Sr ".version" > "${WORKDIR}/cloudreve.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/cloudreve.source_branch.autobuild") --depth=1 --recurse-submodules $(cat "${WORKDIR}/cloudreve.source.autobuild") "${WORKDIR}/BUILDTMP/CLOUDREVE" \
    && git clone -b $(cat "${WORKDIR}/cloudreve.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/cloudreve.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export CLOUDREVE_SHA=$(cd "${WORKDIR}/BUILDTMP/CLOUDREVE" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export CLOUDREVE_VERSION=$(cat "${WORKDIR}/cloudreve.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export CLOUDREVE_CUSTOM_VERSION="${CLOUDREVE_VERSION}-ZHIJIE-${CLOUDREVE_SHA}${PATCH_SHA}" \
    && echo "${CLOUDREVE_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/CLOUDREVE/CLOUDREVE_CUSTOM_VERSION" \
    && sed -i 's|yarn version|#yarn version|g' "${WORKDIR}/BUILDTMP/CLOUDREVE/.build/build-assets.sh"

FROM node:${NODEJS_VERSION}-slim AS build_cloudreve_web

WORKDIR /cloudreve

COPY --from=get_info /tmp/BUILDTMP/CLOUDREVE /cloudreve

RUN \
    apt update \
    && apt install git zip -qy \
    && chmod +x ./.build/build-assets.sh \
    && ./.build/build-assets.sh

FROM golang:${GOLANG_VERSION} AS build_cloudreve

WORKDIR /cloudreve

COPY --from=build_cloudreve_web /tmp/BUILDTMP/CLOUDREVE /cloudreve

ENV CGO_ENABLED="0"

RUN \
    export VERSION=$(cat /cloudreve/CLOUDREVE_CUSTOM_VERSION) \
    && go build -a -o cloudreve -ldflags "-s -w -X 'github.com/cloudreve/Cloudreve/v4/application/constants.BackendVersion=$VERSION'"

FROM scratch AS rebased_cloudreve

WORKDIR /tmp

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_cloudreve /cloudreve/cloudreve /cloudreve

FROM scratch

COPY --from=rebased_cloudreve / /

EXPOSE 443/tcp 5212/tcp

ENTRYPOINT ["/cloudreve"]
