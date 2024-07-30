# Current Version: 1.0.5

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".repo.haproxy" > "${WORKDIR}/haproxy.json" && cat "${WORKDIR}/haproxy.json" | jq -Sr ".version" && cat "${WORKDIR}/haproxy.json" | jq -Sr ".source" > "${WORKDIR}/haproxy.source.autobuild" && cat "${WORKDIR}/haproxy.json" | jq -Sr ".source_branch" > "${WORKDIR}/haproxy.source_branch.autobuild" && cat "${WORKDIR}/haproxy.json" | jq -Sr ".patch" > "${WORKDIR}/haproxy.patch.autobuild" && cat "${WORKDIR}/haproxy.json" | jq -Sr ".patch_branch" > "${WORKDIR}/haproxy.patch_branch.autobuild" && cat "${WORKDIR}/haproxy.json" | jq -Sr ".version" > "${WORKDIR}/haproxy.version.autobuild"

FROM hezhijie0327/module:glibc-lua AS BUILD_LUA

FROM hezhijie0327/module:glibc-openssl AS BUILD_OPENSSL

FROM hezhijie0327/module:glibc-pcre2 AS BUILD_PCRE2

FROM hezhijie0327/module:glibc-zlibng AS BUILD_ZLIB_NG

FROM hezhijie0327/base:ubuntu AS BUILD_HAPROXY

WORKDIR /tmp

COPY --from=GET_INFO /tmp/haproxy.*.autobuild /tmp/

COPY --from=BUILD_LUA / /tmp/BUILDLIB/

COPY --from=BUILD_OPENSSL / /tmp/BUILDLIB/

COPY --from=BUILD_PCRE2 / /tmp/BUILDLIB/

COPY --from=BUILD_ZLIB_NG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && ldconfig --verbose && git clone -b $(cat "${WORKDIR}/haproxy.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/haproxy.source.autobuild") "${WORKDIR}/BUILDTMP/HAPROXY" && git clone -b $(cat "${WORKDIR}/haproxy.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/haproxy.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export HAPROXY_SHA=$(cd "${WORKDIR}/BUILDTMP/HAPROXY" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export HAPROXY_VERSION=$(cat "${WORKDIR}/haproxy.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export HAPROXY_CUSTOM_VERSION="${HAPROXY_VERSION}-ZHIJIE-${HAPROXY_SHA}${PATCH_SHA}" && echo "${HAPROXY_CUSTOM_VERSION}" > "${WORKDIR}/BUILDTMP/HAPROXY/VERSION" && cd "${WORKDIR}/BUILDTMP/HAPROXY" && sed -i "s#-Wl,-Bdynamic##g" "${WORKDIR}/BUILDTMP/HAPROXY/Makefile" \
    && make \
        CFLAGS="-O3 -march=native \$(SPEC_CFLAGS) -fPIE -fstack-protector-all -D_FORTIFY_SOURCE=2 -DLUA_C89_NUMBERS" \
        LDFLAGS="-static -pthread -ldl" \
        TARGET="linux-glibc" \
        PREFIX="${PREFIX}" \
        USE_CRYPT_H="1" \
        USE_ENGINE="1" \
        USE_GETADDRINFO="1" \
        USE_GZIP="1" \
        USE_LIBCRYPT="1" \
        USE_LINUX_CAP="1" \
        USE_NS="1" \
        USE_TFO="1" \
        USE_LUA="1" \
        USE_PCRE2_JIT="1" \
        USE_PROMEX="1" \
        USE_QUIC="1" \
        USE_QUIC_OPENSSL_COMPAT="1" \
        USE_STATIC_PCRE2="1" \
        USE_THREAD="1" \
        LUA_LIB="${PREFIX}/lib" \
        LUA_INC="${PREFIX}/include" \
        USE_OPENSSL="1" \
        SSL_INC="${PREFIX}/include" \
        SSL_LIB="${PREFIX}/lib64" \
        USE_ZLIB="1" \
        ZLIB_LIB="${PREFIX}/lib" \
        ZLIB_INC="${PREFIX}/include" \
        -j $(nproc) \
    && strip -s "${WORKDIR}/BUILDTMP/HAPROXY/haproxy" && cp -rf "${WORKDIR}/BUILDTMP/HAPROXY/haproxy" "${WORKDIR}/BUILDKIT/haproxy"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_HAPROXY /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/haproxy"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

ENTRYPOINT ["/haproxy"]
