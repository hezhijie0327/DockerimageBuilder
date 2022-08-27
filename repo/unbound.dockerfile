# Current Version: 1.0.6

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".repo.unbound" > "${WORKDIR}/unbound.json" && cat "${WORKDIR}/unbound.json" | jq -Sr ".version" && cat "${WORKDIR}/unbound.json" | jq -Sr ".source" > "${WORKDIR}/unbound.source.autobuild" && cat "${WORKDIR}/unbound.json" | jq -Sr ".source_branch" > "${WORKDIR}/unbound.source_branch.autobuild" && cat "${WORKDIR}/unbound.json" | jq -Sr ".patch" > "${WORKDIR}/unbound.patch.autobuild" && cat "${WORKDIR}/unbound.json" | jq -Sr ".patch_branch" > "${WORKDIR}/unbound.patch_branch.autobuild" && cat "${WORKDIR}/unbound.json" | jq -Sr ".version" > "${WORKDIR}/unbound.version.autobuild"

FROM hezhijie0327/module:glibc-expat AS BUILD_EXPAT

FROM hezhijie0327/module:glibc-libevent AS BUILD_LIBEVENT

FROM hezhijie0327/module:glibc-libhiredis AS BUILD_LIBHIREDIS

FROM hezhijie0327/module:glibc-libmnl AS BUILD_LIBMNL

FROM hezhijie0327/module:glibc-libsodium AS BUILD_LIBSODIUM

FROM hezhijie0327/module:glibc-nghttp2 AS BUILD_NGHTTP2

FROM hezhijie0327/module:glibc-openssl AS BUILD_OPENSSL

FROM hezhijie0327/module:glibc-protobuf_c AS BUILD_PROOTOBUF_C

FROM hezhijie0327/base:ubuntu AS BUILD_UNBOUND

WORKDIR /tmp

COPY --from=GET_INFO /tmp/unbound.*.autobuild /tmp/

COPY --from=BUILD_EXPAT / /tmp/BUILDLIB/

COPY --from=BUILD_LIBEVENT / /tmp/BUILDLIB/

COPY --from=BUILD_LIBHIREDIS / /tmp/BUILDLIB/

COPY --from=BUILD_LIBMNL / /tmp/BUILDLIB/

COPY --from=BUILD_LIBSODIUM / /tmp/BUILDLIB/

COPY --from=BUILD_NGHTTP2 / /tmp/BUILDLIB/

COPY --from=BUILD_OPENSSL / /tmp/BUILDLIB/

COPY --from=BUILD_PROOTOBUF_C / /tmp/BUILDLIB/

RUN apt update && apt install -qy libmnl-dev && export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && ldconfig --verbose && git clone -b $(cat "${WORKDIR}/unbound.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/unbound.source.autobuild") "${WORKDIR}/BUILDTMP/UNBOUND" && git clone -b $(cat "${WORKDIR}/unbound.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/unbound.patch.autobuild") "${WORKDIR}/BUILDTMP/PATCH" && cd "${WORKDIR}/BUILDTMP/UNBOUND" && ./configure --enable-cachedb --enable-event-api --enable-fully-static --enable-ipsecmod --enable-ipset --enable-linux-ip-local-port-range --enable-pie --enable-relro-now --enable-subnet --enable-tfo-client --enable-tfo-server --with-libbsd --with-libevent="${PREFIX}" --with-libexpat="${PREFIX}" --with-libhiredis="${PREFIX}" --with-libmnl="${PREFIX}" --with-libnghttp2="${PREFIX}" --with-libsodium="${PREFIX}" --with-protobuf-c="${PREFIX}" --with-pthreads --with-ssl="${PREFIX}" && make -j $(nproc) && make install && strip -s /usr/local/sbin/unbound && cp -rf "/usr/local/sbin/unbound" "${WORKDIR}/BUILDKIT/unbound"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_UNBOUND /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/unbound"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 443/tcp 53/tcp 53/udp 853/tcp

ENTRYPOINT ["/unbound"]
