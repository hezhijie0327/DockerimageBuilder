# Current Version: 1.0.1

ARG BUN_VERSION="1"
ARG GOLANG_VERSION="1"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.newapi" > "${WORKDIR}/newapi.json" \
    && cat "${WORKDIR}/newapi.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/newapi.json" | jq -Sr ".source" > "${WORKDIR}/newapi.source.autobuild" \
    && cat "${WORKDIR}/newapi.json" | jq -Sr ".source_branch" > "${WORKDIR}/newapi.source_branch.autobuild" \
    && cat "${WORKDIR}/newapi.json" | jq -Sr ".patch" > "${WORKDIR}/newapi.patch.autobuild" \
    && cat "${WORKDIR}/newapi.json" | jq -Sr ".patch_branch" > "${WORKDIR}/newapi.patch_branch.autobuild" \
    && cat "${WORKDIR}/newapi.json" | jq -Sr ".version" > "${WORKDIR}/newapi.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/newapi.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/newapi.source.autobuild") "${WORKDIR}/BUILDTMP/NEWAPI" \
    && git clone -b $(cat "${WORKDIR}/newapi.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/newapi.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export NEWAPI_SHA=$(cd "${WORKDIR}/BUILDTMP/NEWAPI" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export NEWAPI_VERSION=$(cat "${WORKDIR}/newapi.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export NEWAPI_CUSTOM_VERSION="${NEWAPI_VERSION}-ZHIJIE-${NEWAPI_SHA}${PATCH_SHA}" \
    && echo "${NEWAPI_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/NEWAPI/NEWAPI_CUSTOM_VERSION"

FROM oven/bun:${BUN_VERSION} AS build_newapi_web

ENV \
    DISABLE_ESLINT_PLUGIN="true"

WORKDIR /newapi

COPY --from=get_info /tmp/BUILDTMP/NEWAPI/NEWAPI_CUSTOM_VERSION .
COPY --from=get_info /tmp/BUILDTMP/NEWAPI/web/package.json .

RUN \
    bun install

COPY --from=get_info /tmp/BUILDTMP/NEWAPI/web/ .

RUN \
    VITE_REACT_APP_VERSION=$(cat NEWAPI_CUSTOM_VERSION) bun run build

FROM golang:${GOLANG_VERSION} AS build_newapi

ENV \
    GO111MODULE="on" \
    CGO_ENABLED="0" \
    GOOS="linux"

WORKDIR /newapi

COPY --from=get_info /tmp/BUILDTMP/NEWAPI/go.mod /newapi/go.mod
COPY --from=get_info /tmp/BUILDTMP/NEWAPI/go.sum /newapi/go.sum

RUN \
    go mod download

COPY --from=get_info /tmp/BUILDTMP/NEWAPI/ .
COPY --from=build_newapi_web /newapi/dist ./web/dist

RUN \
    go build -ldflags "-s -w -X 'one-api/common.Version=$(cat NEWAPI_CUSTOM_VERSION)'" -o newapi

FROM scratch AS rebased_newapi

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_newapi /newapi/newapi /newapi

FROM scratch

ENV \
    PORT="3000" \
    SQLITE_PATH="/newapi.db"

COPY --from=rebased_newapi / /

EXPOSE 3000/tcp

ENTRYPOINT ["/newapi"]
