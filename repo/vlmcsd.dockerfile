# Current Version: 1.0.2

FROM hezhijie0327/base:alpine AS BUILD_VLMCSD

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && export LDFLAGS="-s -static --static" && git clone -b "master" --depth=1 "https://github.com/Wind4/vlmcsd.git" "${WORKDIR}/BUILDTMP/VLMCSD" && cd "${WORKDIR}/BUILDTMP/VLMCSD" && make && cp -rf ${WORKDIR}/BUILDTMP/VLMCSD/bin/* "${WORKDIR}/BUILDKIT"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_VLMCSD /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/vlmcs" && gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/vlmcsd"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 1688/tcp

ENTRYPOINT ["/vlmcsd"]
