# Current Version: 1.1.3

ARG GCC_VERSION="14"

FROM hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.valkey" > "${WORKDIR}/valkey.json" \
    && cat "${WORKDIR}/valkey.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/valkey.json" | jq -Sr ".source" > "${WORKDIR}/valkey.source.autobuild" \
    && cat "${WORKDIR}/valkey.json" | jq -Sr ".source_branch" > "${WORKDIR}/valkey.source_branch.autobuild" \
    && cat "${WORKDIR}/valkey.json" | jq -Sr ".patch" > "${WORKDIR}/valkey.patch.autobuild" \
    && cat "${WORKDIR}/valkey.json" | jq -Sr ".patch_branch" > "${WORKDIR}/valkey.patch_branch.autobuild" \
    && cat "${WORKDIR}/valkey.json" | jq -Sr ".version" > "${WORKDIR}/valkey.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/valkey.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/valkey.source.autobuild") "${WORKDIR}/BUILDTMP/VALKEY" \
    && git clone -b $(cat "${WORKDIR}/valkey.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/valkey.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export VALKEY_SHA=$(cd "${WORKDIR}/BUILDTMP/VALKEY" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export VALKEY_VERSION=$(cat "${WORKDIR}/valkey.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export VALKEY_CUSTOM_VERSION="${VALKEY_VERSION}-ZHIJIE-${VALKEY_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/VALKEY" \
    && sed -i 's/\(VALKEY_VERSION "\)[0-9]\+\(\.[0-9]\+\)*"/\1'"${VALKEY_CUSTOM_VERSION}"'"/' "${WORKDIR}/BUILDTMP/VALKEY/src/version.h"

FROM hezhijie0327/module:openssl AS build_openssl

FROM gcc:${GCC_VERSION} AS build_valkey

WORKDIR /valkey

COPY --from=get_info /tmp/BUILDTMP/VALKEY /valkey

COPY --from=build_openssl / /BUILDLIB/

RUN \
    PREFIX="/BUILDLIB" \
    && export CPPFLAGS="-I$PREFIX/include -static" \
    && export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib -s -static --static" \
    && export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH" \
    && export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" \
    && export PATH="$PREFIX/bin:$PATH" \
    && export OPENSSL_PREFIX="$PREFIX" \
    && ldconfig --verbose \
    && apt update \
    && apt install -qy \
          libjemalloc-dev \
    && make -j $(nproc) BUILD_TLS="yes" MALLOC="jemalloc" \
    && make install \
    && rm -rf /usr/local/bin/valkey-check-* "/usr/local/bin/valkey-sentinel" \
    && strip -s /usr/local/bin/valkey-*

FROM hezhijie0327/gpg:latest AS gpg_sign

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /tmp/BUILDKIT/etc/ssl/certs/ca-certificates.crt

COPY --from=build_valkey /usr/local/bin/valkey-* /tmp/BUILDKIT/

RUN \
    gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/valkey-benchmark" \
    && gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/valkey-cli" \
    && gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/valkey-server"

FROM scratch

COPY --from=gpg_sign /tmp/BUILDKIT /

EXPOSE 6379/tcp

ENTRYPOINT ["/valkey-server"]
