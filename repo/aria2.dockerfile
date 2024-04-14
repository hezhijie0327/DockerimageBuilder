# Current Version: 1.7.0

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.aria2c" > "${WORKDIR}/aria2c.json" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".version" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".source" > "${WORKDIR}/aria2c.source.autobuild" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".source_branch" > "${WORKDIR}/aria2c.source_branch.autobuild" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".patch" > "${WORKDIR}/aria2c.patch.autobuild" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".patch_branch" > "${WORKDIR}/aria2c.patch_branch.autobuild" && cat "${WORKDIR}/aria2c.json" | jq -Sr ".version" > "${WORKDIR}/aria2c.version.autobuild"

FROM hezhijie0327/module:glibc-cares AS BUILD_C_ARES

FROM hezhijie0327/module:glibc-expat AS BUILD_EXPAT

FROM hezhijie0327/module:glibc-glibc AS BUILD_GLIBC

FROM hezhijie0327/module:glibc-gperftools AS BUILD_GPERFTOOLS

FROM hezhijie0327/module:glibc-libuv AS BUILD_LIBUV

FROM hezhijie0327/module:glibc-libssh2 AS BUILD_LIBSSH2

FROM hezhijie0327/module:glibc-openssl AS BUILD_OPENSSL

FROM hezhijie0327/module:glibc-sqlite AS BUILD_SQLITE

FROM hezhijie0327/module:glibc-zlibng AS BUILD_ZLIB_NG

FROM hezhijie0327/base:ubuntu AS BUILD_ARIA2

WORKDIR /tmp

COPY --from=GET_INFO /tmp/aria2c.*.autobuild /tmp/

COPY --from=BUILD_C_ARES / /tmp/BUILDLIB/

COPY --from=BUILD_EXPAT / /tmp/BUILDLIB/

COPY --from=BUILD_GLIBC / /tmp/BUILDLIB/

COPY --from=BUILD_GPERFTOOLS / /tmp/BUILDLIB/

COPY --from=BUILD_LIBUV / /tmp/BUILDLIB/

COPY --from=BUILD_LIBSSH2 / /tmp/BUILDLIB/

COPY --from=BUILD_OPENSSL / /tmp/BUILDLIB/

COPY --from=BUILD_SQLITE / /tmp/BUILDLIB/

COPY --from=BUILD_ZLIB_NG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && ldconfig --verbose && git clone -b $(cat "${WORKDIR}/aria2c.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/aria2c.source.autobuild") "${WORKDIR}/BUILDTMP/ARIA2" && git clone -b $(cat "${WORKDIR}/aria2c.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/aria2c.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export ARIA2_SHA=$(cd "${WORKDIR}/BUILDTMP/ARIA2" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export ARIA2_VERSION=$(cat "${WORKDIR}/aria2c.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export ARIA2_CUSTOM_VERSION="${ARIA2_VERSION}-ZHIJIE-${ARIA2_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/ARIA2" && cat "./configure.ac" | sed "s/$ARIA2_VERSION/$ARIA2_CUSTOM_VERSION/g" > "./configure.ac.tmp" && mv "./configure.ac.tmp" "./configure.ac" && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/aria2/*.patch && autoreconf -i && ARIA2_STATIC=yes ./configure --with-ca-bundle="/etc/ssl/certs/ca-certificates.crt" --with-libcares --with-libcares-prefix=${PREFIX} --with-libexpat --with-libexpat-prefix=${PREFIX} --with-libssh2 --with-libssh2-prefix=${PREFIX} --with-libuv --with-libuv-prefix=${PREFIX} --with-libz --with-libz-prefix=${PREFIX} --with-openssl --with-openssl-prefix=${PREFIX} --with-sqlite3 --with-sqlite3-prefix=${PREFIX} --with-tcmalloc --with-tcmalloc-prefix=${PREFIX} --without-appletls --without-gnutls --without-jemalloc --without-libgcrypt --without-libgmp --without-libnettle --without-libxml2 --without-wintls && make -j $(nproc) && make install && strip -s /usr/local/bin/aria2c && cp -rf "/usr/local/bin/aria2c" "${WORKDIR}/BUILDKIT/aria2c"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_ARIA2 /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/aria2c"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 51413/tcp 51413/udp 6800/tcp 6881-6889/tcp 6881-6889/udp 6969/tcp 6969/udp

ENTRYPOINT ["/aria2c"]
