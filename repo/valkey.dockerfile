# Current Version: 1.0.3

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".repo.valkey" > "${WORKDIR}/valkey.json" && cat "${WORKDIR}/valkey.json" | jq -Sr ".version" && cat "${WORKDIR}/valkey.json" | jq -Sr ".source" > "${WORKDIR}/valkey.source.autobuild" && cat "${WORKDIR}/valkey.json" | jq -Sr ".source_branch" > "${WORKDIR}/valkey.source_branch.autobuild" && cat "${WORKDIR}/valkey.json" | jq -Sr ".patch" > "${WORKDIR}/valkey.patch.autobuild" && cat "${WORKDIR}/valkey.json" | jq -Sr ".patch_branch" > "${WORKDIR}/valkey.patch_branch.autobuild" && cat "${WORKDIR}/valkey.json" | jq -Sr ".version" > "${WORKDIR}/valkey.version.autobuild"

FROM hezhijie0327/module:openssl AS BUILD_OPENSSL

FROM hezhijie0327/base:ubuntu AS BUILD_VALKEY

WORKDIR /tmp

COPY --from=GET_INFO /tmp/valkey.*.autobuild /tmp/

COPY --from=BUILD_OPENSSL / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CFLAGS="-I${PREFIX}/include -static" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && export OPENSSL_PREFIX="${PREFIX}" && ldconfig --verbose && git clone -b $(cat "${WORKDIR}/valkey.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/valkey.source.autobuild") "${WORKDIR}/BUILDTMP/VALKEY" && git clone -b $(cat "${WORKDIR}/valkey.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/valkey.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export VALKEY_SHA=$(cd "${WORKDIR}/BUILDTMP/VALKEY" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export VALKEY_VERSION=$(cat "${WORKDIR}/valkey.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export VALKEY_CUSTOM_VERSION="${VALKEY_VERSION}-ZHIJIE-${VALKEY_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/VALKEY" && sed -i 's/\(VALKEY_VERSION "\)[0-9]\+\(\.[0-9]\+\)*"/\1'"${VALKEY_CUSTOM_VERSION}"'"/' "${WORKDIR}/BUILDTMP/VALKEY/src/version.h" && make BUILD_TLS="yes" MALLOC="jemalloc" && make install && rm -rf ${WORKDIR}/BUILDLIB/bin/valkey-check-* "${WORKDIR}/BUILDLIB/bin/valkey-sentinel" && strip -s ${WORKDIR}/BUILDLIB/bin/valkey-* && cp -rf ${WORKDIR}/BUILDLIB/bin/valkey* ${WORKDIR}/BUILDKIT

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_VALKEY /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/valkey-benchmark" && gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/valkey-cli" && gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/valkey-server"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 6379/tcp

ENTRYPOINT ["/valkey-server"]
