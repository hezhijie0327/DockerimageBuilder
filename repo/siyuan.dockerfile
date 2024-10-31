# Current Version: 1.0.7

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".repo.siyuan" > "${WORKDIR}/siyuan.json" && cat "${WORKDIR}/siyuan.json" | jq -Sr ".version" && cat "${WORKDIR}/siyuan.json" | jq -Sr ".source" > "${WORKDIR}/siyuan.source.autobuild" && cat "${WORKDIR}/siyuan.json" | jq -Sr ".source_branch" > "${WORKDIR}/siyuan.source_branch.autobuild" && cat "${WORKDIR}/siyuan.json" | jq -Sr ".patch" > "${WORKDIR}/siyuan.patch.autobuild" && cat "${WORKDIR}/siyuan.json" | jq -Sr ".patch_branch" > "${WORKDIR}/siyuan.patch_branch.autobuild" && cat "${WORKDIR}/siyuan.json" | jq -Sr ".version" > "${WORKDIR}/siyuan.version.autobuild"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM hezhijie0327/base:ubuntu AS BUILD_SIYUAN

WORKDIR /tmp

COPY --from=GET_INFO /tmp/siyuan.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/siyuan.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/siyuan.source.autobuild") "${WORKDIR}/BUILDTMP/SIYUAN" && git clone -b $(cat "${WORKDIR}/siyuan.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/siyuan.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export SIYUAN_SHA=$(cd "${WORKDIR}/BUILDTMP/SIYUAN" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export SIYUAN_VERSION=$(cat "${WORKDIR}/siyuan.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export SIYUAN_CUSTOM_VERSION="${SIYUAN_VERSION}-ZHIJIE-${SIYUAN_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/SIYUAN" && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/siyuan/*.patch && cd "${WORKDIR}/BUILDTMP/SIYUAN/app" && sed -i "s/\"version\": \"[0-9]\+\.[0-9]\+\.[0-9]\+\"/\"version\": \"${SIYUAN_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/SIYUAN/app/package.json" && npm install -g pnpm && pnpm i && pnpm run build && cd "${WORKDIR}/BUILDTMP/SIYUAN/kernel" && sed -i "s/\=\ \"[0-9]\+\.[0-9]\+\.[0-9]\+\"/\=\ \"${SIYUAN_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/SIYUAN/kernel/util/working.go" && export CGO_ENABLED="1" && go build --tags fts5 -v -ldflags "-s -w" && cp -rf "${WORKDIR}/BUILDTMP/SIYUAN/kernel/kernel" "${WORKDIR}/BUILDKIT/kernel"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_SIYUAN /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/kernel"

FROM busybox:latest AS REBASED_SIYUAN

WORKDIR /tmp

COPY --from=GPG_SIGN /tmp/BUILDKIT/ /

COPY --from=BUILD_SIYUAN /tmp/BUILDTMP/SIYUAN/app/appearance /opt/siyuan/appearance
COPY --from=BUILD_SIYUAN /tmp/BUILDTMP/SIYUAN/app/stage /opt/siyuan/stage
COPY --from=BUILD_SIYUAN /tmp/BUILDTMP/SIYUAN/app/guide /opt/siyuan/guide
COPY --from=BUILD_SIYUAN /tmp/BUILDTMP/SIYUAN/app/changelogs /opt/siyuan/changelogs

RUN mv /kernel* /opt/siyuan/ && find /opt/siyuan/ -name .git | xargs rm -rf

FROM scratch

ENV SIYUAN_ACCESS_AUTH_CODE_BYPASS="true" \
    SIYUAN_TESSERACT_ENABLED="false" SIYUAN_TESSERACT_LANGS="" \
    SIYUAN_OPENAI_API_BASE_URL="" SIYUAN_OPENAI_API_KEY="" SIYUAN_OPENAI_API_PROXY=""

COPY --from=REBASED_SIYUAN / /

EXPOSE 6806/tcp 6808/tcp

ENTRYPOINT ["/opt/siyuan/kernel"]
