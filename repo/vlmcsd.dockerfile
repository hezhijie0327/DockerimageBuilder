# Current Version: 1.0.3

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.vlmcsd" > "${WORKDIR}/vlmcsd.json" && cat "${WORKDIR}/vlmcsd.json" | jq -Sr ".version" && cat "${WORKDIR}/vlmcsd.json" | jq -Sr ".source" > "${WORKDIR}/vlmcsd.source.autobuild" && cat "${WORKDIR}/vlmcsd.json" | jq -Sr ".source_branch" > "${WORKDIR}/vlmcsd.source_branch.autobuild" && cat "${WORKDIR}/vlmcsd.json" | jq -Sr ".patch" > "${WORKDIR}/vlmcsd.patch.autobuild" && cat "${WORKDIR}/vlmcsd.json" | jq -Sr ".patch_branch" > "${WORKDIR}/vlmcsd.patch_branch.autobuild" && cat "${WORKDIR}/vlmcsd.json" | jq -Sr ".version" > "${WORKDIR}/vlmcsd.version.autobuild"

FROM hezhijie0327/base:alpine AS BUILD_VLMCSD

WORKDIR /tmp

COPY --from=GET_INFO /tmp/vlmcsd.*.autobuild /tmp/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && export LDFLAGS="-s -static --static" && git clone -b $(cat "${WORKDIR}/vlmcsd.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/vlmcsd.source.autobuild") "${WORKDIR}/BUILDTMP/VLMCSD" && git clone -b $(cat "${WORKDIR}/vlmcsd.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/vlmcsd.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export VLMCSD_SHA=$(cd "${WORKDIR}/BUILDTMP/VLMCSD" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export VLMCSD_VERSION=$(cat "${WORKDIR}/vlmcsd.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export VLMCSD_CUSTOM_VERSION="${VLMCSD_VERSION}-ZHIJIE-${VLMCSD_SHA}${PATCH_SHA}" && sed -i "s/private build/${VLMCSD_CUSTOM_VERSION}/g" "${WORKDIR}/BUILDTMP/VLMCSD/src/config.h" && cd "${WORKDIR}/BUILDTMP/VLMCSD" && make && cp -rf ${WORKDIR}/BUILDTMP/VLMCSD/bin/* "${WORKDIR}/BUILDKIT"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_VLMCSD /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/vlmcs" && gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/vlmcsd"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 1688/tcp

ENTRYPOINT ["/vlmcsd"]
