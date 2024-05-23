# Current Version: 1.2.5

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.unbound" > "${WORKDIR}/unbound.json" && cat "${WORKDIR}/unbound.json" | jq -Sr ".version" && cat "${WORKDIR}/unbound.json" | jq -Sr ".source" > "${WORKDIR}/unbound.source.autobuild" && cat "${WORKDIR}/unbound.json" | jq -Sr ".source_branch" > "${WORKDIR}/unbound.source_branch.autobuild" && cat "${WORKDIR}/unbound.json" | jq -Sr ".patch" > "${WORKDIR}/unbound.patch.autobuild" && cat "${WORKDIR}/unbound.json" | jq -Sr ".patch_branch" > "${WORKDIR}/unbound.patch_branch.autobuild" && cat "${WORKDIR}/unbound.json" | jq -Sr ".version" > "${WORKDIR}/unbound.version.autobuild" && wget -O "${WORKDIR}/root.hints" "https://www.internic.net/domain/named.cache"

FROM hezhijie0327/module:glibc-expat AS BUILD_EXPAT

FROM hezhijie0327/module:glibc-libevent AS BUILD_LIBEVENT

FROM hezhijie0327/module:glibc-libhiredis AS BUILD_LIBHIREDIS

FROM hezhijie0327/module:glibc-libmnl AS BUILD_LIBMNL

FROM hezhijie0327/module:glibc-libnghttp2 AS BUILD_LIBNGHTTP2

FROM hezhijie0327/module:glibc-libsodium AS BUILD_LIBSODIUM

FROM hezhijie0327/module:glibc-openssl AS BUILD_OPENSSL

FROM hezhijie0327/base:ubuntu AS BUILD_UNBOUND

WORKDIR /tmp

COPY --from=GET_INFO /tmp/root.hints /tmp/BUILDKIT/etc/unbound/root.hints
COPY --from=GET_INFO /tmp/unbound.*.autobuild /tmp/

COPY --from=BUILD_EXPAT / /tmp/BUILDLIB/

COPY --from=BUILD_LIBEVENT / /tmp/BUILDLIB/

COPY --from=BUILD_LIBHIREDIS / /tmp/BUILDLIB/

COPY --from=BUILD_LIBMNL / /tmp/BUILDLIB/

COPY --from=BUILD_LIBNGHTTP2 / /tmp/BUILDLIB/

COPY --from=BUILD_LIBSODIUM / /tmp/BUILDLIB/

COPY --from=BUILD_OPENSSL / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && ldconfig --verbose && git clone -b $(cat "${WORKDIR}/unbound.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/unbound.source.autobuild") "${WORKDIR}/BUILDTMP/UNBOUND" && git clone -b $(cat "${WORKDIR}/unbound.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/unbound.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export UNBOUND_SHA=$(cd "${WORKDIR}/BUILDTMP/UNBOUND" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export UNBOUND_VERSION=$(cat "${WORKDIR}/unbound.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export UNBOUND_CUSTOM_VERSION="${UNBOUND_VERSION}-ZHIJIE-${UNBOUND_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/UNBOUND" && sed -i "s/\(PACKAGE_STRING='unbound \)[0-9]\+\(\.[0-9]\+\)*'/\1${UNBOUND_CUSTOM_VERSION}'/;s/\(PACKAGE_VERSION='\)[0-9]\+\(\.[0-9]\+\)*'/\1${UNBOUND_CUSTOM_VERSION}'/" "${WORKDIR}/BUILDTMP/UNBOUND/configure" && ./configure --enable-cachedb --enable-dnscrypt --enable-dnstap --enable-fully-static --enable-ipsecmod --enable-ipset --enable-pie --enable-relro-now --enable-subnet --enable-tfo-client --enable-tfo-server --with-dynlibmodule --with-libbsd --with-libevent="${PREFIX}" --with-libexpat="${PREFIX}" --with-libhiredis="${PREFIX}" --with-libmnl="${PREFIX}" --with-libnghttp2="${PREFIX}" --with-libsodium="${PREFIX}" --without-pthreads --without-solaris-threads --with-ssl="${PREFIX}" && make -j $(nproc) && make install && rm -rf "/usr/local/sbin/unbound-control-setup" && strip -s /usr/local/sbin/unbound* && cp -rf /usr/local/sbin/unbound* ${WORKDIR}/BUILDKIT && ${WORKDIR}/BUILDKIT/unbound-anchor -a "${WORKDIR}/BUILDKIT/etc/unbound/root.key" -c "${WORKDIR}/BUILDKIT/etc/unbound/icannbundle.pem" -f "/etc/resolv.conf" -r "${WORKDIR}/BUILDKIT/etc/unbound/root.hints"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_UNBOUND /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/unbound" && gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/unbound-anchor" && gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/unbound-checkconf" && gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/unbound-control" && gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/unbound-host"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 443/tcp 53/tcp 53/udp 853/tcp

ENTRYPOINT ["/unbound"]
