# Current Version: 1.0.3

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.redis" > "${WORKDIR}/redis.json" && cat "${WORKDIR}/redis.json" | jq -Sr ".version" && cat "${WORKDIR}/redis.json" | jq -Sr ".source" > "${WORKDIR}/redis.source.autobuild" && cat "${WORKDIR}/redis.json" | jq -Sr ".source_branch" > "${WORKDIR}/redis.source_branch.autobuild" && cat "${WORKDIR}/redis.json" | jq -Sr ".patch" > "${WORKDIR}/redis.patch.autobuild" && cat "${WORKDIR}/redis.json" | jq -Sr ".patch_branch" > "${WORKDIR}/redis.patch_branch.autobuild" && cat "${WORKDIR}/redis.json" | jq -Sr ".version" > "${WORKDIR}/redis.version.autobuild"

FROM hezhijie0327/module:glibc-glibc AS BUILD_GLIBC

FROM hezhijie0327/module:glibc-openssl AS BUILD_OPENSSL

FROM hezhijie0327/base:ubuntu AS BUILD_REDIS

WORKDIR /tmp

COPY --from=GET_INFO /tmp/redis.*.autobuild /tmp/

COPY --from=BUILD_GLIBC / /tmp/BUILDLIB/

COPY --from=BUILD_OPENSSL / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CFLAGS="-I${PREFIX}/include -static" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && export OPENSSL_PREFIX="${PREFIX}" && ldconfig --verbose && git clone -b $(cat "${WORKDIR}/redis.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/redis.source.autobuild") "${WORKDIR}/BUILDTMP/REDIS" && git clone -b $(cat "${WORKDIR}/redis.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/redis.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export REDIS_SHA=$(cd "${WORKDIR}/BUILDTMP/REDIS" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export REDIS_VERSION=$(cat "${WORKDIR}/redis.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export REDIS_CUSTOM_VERSION="${REDIS_VERSION}-ZHIJIE-${REDIS_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/REDIS" && sed -i 's/\(REDIS_VERSION "\)[0-9]\+\(\.[0-9]\+\)*"/\1'"${REDIS_CUSTOM_VERSION}"'"/' "${WORKDIR}/BUILDTMP/REDIS/src/version.h" && make BUILD_TLS="yes" MALLOC="jemalloc" && make install && rm -rf ${WORKDIR}/BUILDLIB/bin/redis-check-* "${WORKDIR}/BUILDLIB/bin/redis-sentinel" && strip -s ${WORKDIR}/BUILDLIB/bin/redis-* && cp -rf ${WORKDIR}/BUILDLIB/bin/redis* ${WORKDIR}/BUILDKIT

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_REDIS /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/redis-benchmark" && gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/redis-cli" && gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/redis-server"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 6379/tcp

ENTRYPOINT ["/redis-server"]
