# Current Version: 1.0.5

ARG GOLANG_VERSION="1"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.minio" > "${WORKDIR}/minio.json" \
    && cat "${WORKDIR}/minio.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/minio.json" | jq -Sr ".source" > "${WORKDIR}/minio.source.autobuild" \
    && cat "${WORKDIR}/minio.json" | jq -Sr ".source_branch" > "${WORKDIR}/minio.source_branch.autobuild" \
    && cat "${WORKDIR}/minio.json" | jq -Sr ".patch" > "${WORKDIR}/minio.patch.autobuild" \
    && cat "${WORKDIR}/minio.json" | jq -Sr ".patch_branch" > "${WORKDIR}/minio.patch_branch.autobuild" \
    && cat "${WORKDIR}/minio.json" | jq -Sr ".version" > "${WORKDIR}/minio.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/minio.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/minio.source.autobuild") "${WORKDIR}/BUILDTMP/MINIO" \
    && git clone -b $(cat "${WORKDIR}/minio.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/minio.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export MINIO_SHA=$(cd "${WORKDIR}/BUILDTMP/MINIO" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export MINIO_VERSION=$(cat "${WORKDIR}/minio.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export MINIO_CUSTOM_VERSION="${MINIO_VERSION}-ZHIJIE-${MINIO_SHA}${PATCH_SHA}" \
    && echo "${MINIO_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/MINIO/MINIO_CUSTOM_VERSION"

FROM golang:${GOLANG_VERSION} AS build_minio

WORKDIR /minio

ENV \
    CGO_ENABLED="0"

COPY --from=get_info /tmp/BUILDTMP/MINIO /minio

RUN \
    go build -o minio -trimpath -ldflags "$(go run buildscripts/gen-ldflags.go) -X github.com/minio/minio/cmd.ReleaseTag=DEVELOPMENT.$(cat /minio/MINIO_CUSTOM_VERSION)"

FROM scratch AS rebased_minio

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_minio /minio/minio /minio

FROM scratch

COPY --from=rebased_minio / /

EXPOSE 9000/tcp 9001/tcp

ENTRYPOINT ["/minio"]
