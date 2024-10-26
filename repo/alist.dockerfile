# Current Version: 1.0.2

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".repo.alist" > "${WORKDIR}/alist.json" && cat "${WORKDIR}/alist.json" | jq -Sr ".version" && cat "${WORKDIR}/alist.json" | jq -Sr ".source" > "${WORKDIR}/alist.source.autobuild" && cat "${WORKDIR}/alist.json" | jq -Sr ".source_branch" > "${WORKDIR}/alist.source_branch.autobuild" && cat "${WORKDIR}/alist.json" | jq -Sr ".patch" > "${WORKDIR}/alist.patch.autobuild" && cat "${WORKDIR}/alist.json" | jq -Sr ".patch_branch" > "${WORKDIR}/alist.patch_branch.autobuild" && cat "${WORKDIR}/alist.json" | jq -Sr ".version" > "${WORKDIR}/alist.version.autobuild"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_ALIST_WEB

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT/alist-web" && cd "${WORKDIR}/BUILDKIT/alist-web" && curl -Ls -o - "https://github.com/alist-org/alist-web/releases/latest/download/dist.tar.gz" | tar zxvf - --strip-components=1

FROM hezhijie0327/base:ubuntu AS BUILD_ALIST

WORKDIR /tmp

COPY --from=GET_INFO /tmp/alist.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

COPY --from=BUILD_ALIST_WEB /tmp/BUILDKIT/alist-web /tmp/BUILDTMP/alist-web/dist

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/alist.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/alist.source.autobuild") "${WORKDIR}/BUILDTMP/ALIST" && git clone -b $(cat "${WORKDIR}/alist.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/alist.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export ALIST_SHA=$(cd "${WORKDIR}/BUILDTMP/ALIST" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export ALIST_VERSION=$(cat "${WORKDIR}/alist.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export ALIST_CUSTOM_VERSION="${ALIST_VERSION}-ZHIJIE-${ALIST_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/ALIST" && rm -rf "${WORKDIR}/BUILDTMP/ALIST/public/dist" && mv "${WORKDIR}/BUILDTMP/alist-web/dist" "${WORKDIR}/BUILDTMP/ALIST/public/dist" && ls -alh "${WORKDIR}/BUILDTMP/ALIST/public/dist" && go build -o "${WORKDIR}/BUILDKIT/alist" -ldflags="-w -s -X github.com/alist-org/alist/v3/internal/conf.Version=${ALIST_CUSTOM_VERSION}" -tags=jsoniter .

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_alist /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/alist"

FROM busybox:latest AS REBASED_ALIST

WORKDIR /tmp

COPY --from=GPG_SIGN /tmp/BUILDKIT/ /

RUN mkdir -p "/opt/alist" && mv /alist /opt/alist/alist

FROM scratch

COPY --from=REBASED_ALIST / /

EXPOSE 5244/tcp

ENTRYPOINT ["/opt/alist/alist"]
