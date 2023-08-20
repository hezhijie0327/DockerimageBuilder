# Current Version: 1.0.3

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.smartdns" > "${WORKDIR}/smartdns.json" && cat "${WORKDIR}/smartdns.json" | jq -Sr ".version" && cat "${WORKDIR}/smartdns.json" | jq -Sr ".source" > "${WORKDIR}/smartdns.source.autobuild" && cat "${WORKDIR}/smartdns.json" | jq -Sr ".source_branch" > "${WORKDIR}/smartdns.source_branch.autobuild" && cat "${WORKDIR}/smartdns.json" | jq -Sr ".patch" > "${WORKDIR}/smartdns.patch.autobuild" && cat "${WORKDIR}/smartdns.json" | jq -Sr ".patch_branch" > "${WORKDIR}/smartdns.patch_branch.autobuild" && cat "${WORKDIR}/smartdns.json" | jq -Sr ".version" > "${WORKDIR}/smartdns.version.autobuild"

FROM hezhijie0327/module:glibc-openssl AS BUILD_OPENSSL

FROM hezhijie0327/base:ubuntu AS BUILD_SMARTDNS

WORKDIR /tmp

COPY --from=GET_INFO /tmp/smartdns.*.autobuild /tmp/

COPY --from=BUILD_OPENSSL / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export CFLAGS="-I ${PREFIX}/include" && export LDFLAGS="-L ${PREFIX}/lib64 -L ${PREFIX}/lib" && ldconfig --verbose && git clone -b $(cat "${WORKDIR}/smartdns.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/smartdns.source.autobuild") "${WORKDIR}/BUILDTMP/SMARTDNS" && git clone -b $(cat "${WORKDIR}/smartdns.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/smartdns.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export SMARTDNS_SHA=$(cd "${WORKDIR}/BUILDTMP/SMARTDNS" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export SMARTDNS_VERSION=$(cat "${WORKDIR}/smartdns.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export SMARTDNS_CUSTOM_VERSION="${SMARTDNS_VERSION}-ZHIJIE-${SMARTDNS_SHA}${PATCH_SHA}" && sed -i 's/VER="`date +"1.%Y.%m.%d-%H%M"`"/VER=""/g' "${WORKDIR}/BUILDTMP/SMARTDNS/package/build-pkg.sh" && sed -i "s/VER=\"\"/VER=\"${SMARTDNS_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/SMARTDNS/package/build-pkg.sh" && sed -i "s/DNS_MAX_SERVERS 64/DNS_MAX_SERVERS 128/g" "${WORKDIR}/BUILDTMP/SMARTDNS/src/dns_conf.h" && cd "${WORKDIR}/BUILDTMP/SMARTDNS" && sh "${WORKDIR}/BUILDTMP/SMARTDNS/package/build-pkg.sh" --platform linux --arch $(dpkg --print-architecture) --static && cd "${WORKDIR}/BUILDTMP/SMARTDNS/package" && tar -xvf *.tar.gz && chmod a+x "${WORKDIR}/BUILDTMP/SMARTDNS/package/smartdns/usr/sbin/smartdns" && strip -s "${WORKDIR}/BUILDTMP/SMARTDNS/package/smartdns/usr/sbin/smartdns" && cp "${WORKDIR}/BUILDTMP/SMARTDNS/package/smartdns/usr/sbin/smartdns" "${WORKDIR}/BUILDKIT/smartdns"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_SMARTDNS /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/smartdns"

FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

EXPOSE 53/tcp 53/udp 853/tcp

ENTRYPOINT ["/smartdns"]
