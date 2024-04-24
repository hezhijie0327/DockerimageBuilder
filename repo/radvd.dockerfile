# Current Version: 1.0.1

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.radvd" > "${WORKDIR}/radvd.json" && cat "${WORKDIR}/radvd.json" | jq -Sr ".version" && cat "${WORKDIR}/radvd.json" | jq -Sr ".source" > "${WORKDIR}/radvd.source.autobuild" && cat "${WORKDIR}/radvd.json" | jq -Sr ".source_branch" > "${WORKDIR}/radvd.source_branch.autobuild" && cat "${WORKDIR}/radvd.json" | jq -Sr ".patch" > "${WORKDIR}/radvd.patch.autobuild" && cat "${WORKDIR}/radvd.json" | jq -Sr ".patch_branch" > "${WORKDIR}/radvd.patch_branch.autobuild" && cat "${WORKDIR}/radvd.json" | jq -Sr ".version" > "${WORKDIR}/radvd.version.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_RADVD

WORKDIR /tmp

COPY --from=GET_INFO /tmp/radvd.*.autobuild /tmp/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && ldconfig --verbose && git clone -b $(cat "${WORKDIR}/radvd.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/radvd.source.autobuild") "${WORKDIR}/BUILDTMP/RADVD" && git clone -b $(cat "${WORKDIR}/radvd.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/radvd.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export RADVD_SHA=$(cd "${WORKDIR}/BUILDTMP/RADVD" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export RADVD_VERSION=$(cat "${WORKDIR}/radvd.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export RADVD_CUSTOM_VERSION="${RADVD_VERSION}-ZHIJIE-${RADVD_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/RADVD" && export RADVD_CURRENT_VERSION=$(cat "${WORKDIR}/BUILDTMP/RADVD/configure.ac" | grep "AC_INIT(radvd, \[" | cut -d '[' -f 2 | cut -d ']' -f 1) && bash "${WORKDIR}/BUILDTMP/RADVD/autogen.sh" && sed -i "s/${RADVD_CURRENT_VERSION}/${RADVD_CUSTOM_VERSION}/g" "${WORKDIR}/BUILDTMP/RADVD/configure" && ./configure --prefix="${WORKDIR}/BUILDKIT" --sysconfdir="/etc" && make -j $(nproc) && make install && strip -s "${WORKDIR}/BUILDKIT/sbin/radvd" && strip -s "${WORKDIR}/BUILDKIT/sbin/radvdump"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_RADVD /tmp/BUILDKIT/sbin /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/radvd" && gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/radvdump"


FROM scratch

COPY --from=GPG_SIGN /tmp/BUILDKIT /

ENTRYPOINT ["/radvd"]
