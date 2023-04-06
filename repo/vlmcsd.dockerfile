# Current Version: 1.0.1

FROM hezhijie0327/module:musl-openssl AS BUILD_OPENSSL

FROM hezhijie0327/base:alpine AS BUILD_VLMCSD

WORKDIR /tmp

COPY --from=BUILD_OPENSSL / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && ldconfig --verbose && git clone -b "master" --depth=1 "https://github.com/Wind4/vlmcsd.git" "${WORKDIR}/BUILDTMP/VLMCSD" && cd "${WORKDIR}/BUILDTMP/VLMCSD" && make && cp -rf ${WORKDIR}/BUILDTMP/VLMCSD/bin/* "${WORKDIR}/BUILDKIT"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_VLMCSD /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/vlmcs" && gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/vlmcsd"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 1688/tcp

ENTRYPOINT ["/vlmcsd"]
