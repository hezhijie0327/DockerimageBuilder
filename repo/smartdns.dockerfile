# Current Version: 1.0.7

ARG GCC_VERSION="14"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.smartdns" > "${WORKDIR}/smartdns.json" \
    && cat "${WORKDIR}/smartdns.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/smartdns.json" | jq -Sr ".source" > "${WORKDIR}/smartdns.source.autobuild" \
    && cat "${WORKDIR}/smartdns.json" | jq -Sr ".source_branch" > "${WORKDIR}/smartdns.source_branch.autobuild" \
    && cat "${WORKDIR}/smartdns.json" | jq -Sr ".patch" > "${WORKDIR}/smartdns.patch.autobuild" \
    && cat "${WORKDIR}/smartdns.json" | jq -Sr ".patch_branch" > "${WORKDIR}/smartdns.patch_branch.autobuild" \
    && cat "${WORKDIR}/smartdns.json" | jq -Sr ".version" > "${WORKDIR}/smartdns.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/smartdns.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/smartdns.source.autobuild") "${WORKDIR}/BUILDTMP/SMARTDNS" \
    && git clone -b $(cat "${WORKDIR}/smartdns.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/smartdns.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export SMARTDNS_SHA=$(cd "${WORKDIR}/BUILDTMP/SMARTDNS" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export SMARTDNS_VERSION=$(cat "${WORKDIR}/smartdns.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export SMARTDNS_CUSTOM_VERSION="${SMARTDNS_VERSION}-ZHIJIE-${SMARTDNS_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/SMARTDNS" \
    && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/smartdns/*.patch \
    && sed -i 's/VER="`date +"1.%Y.%m.%d-%H%M"`"/VER=""/g' "${WORKDIR}/BUILDTMP/SMARTDNS/package/build-pkg.sh" \
    && sed -i "s/VER=\"\"/VER=\"${SMARTDNS_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/SMARTDNS/package/build-pkg.sh"

FROM ghcr.io/hezhijie0327/module:openssl AS build_openssl

FROM gcc:${GCC_VERSION} AS build_smartdns

WORKDIR /smartdns

COPY --from=get_info /tmp/BUILDTMP/SMARTDNS /smartdns

COPY --from=build_openssl / /BUILDLIB/

RUN \
    export CFLAGS="-I ${PREFIX}/include" \
    && export LDFLAGS="-L ${PREFIX}/lib64 -L ${PREFIX}/lib -lm" \
    && ldconfig --verbose \
    && sh "./package/build-pkg.sh" --platform linux --arch $(dpkg --print-architecture) --static \
    && cd "./package" \
    && tar -xvf *.tar.gz \
    && chmod a+x "./package/smartdns/usr/sbin/smartdns" \
    && strip -s "./package/smartdns/usr/sbin/smartdns"

FROM scratch AS rebased_smartdns

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_smartdns /smartdns/package/smartdns/usr/sbin/smartdns /smartdns

FROM scratch

COPY --from=rebased_smartdns / /

EXPOSE 443/tcp 443/udp 53/tcp 53/udp 853/tcp 853/udp

ENTRYPOINT ["/smartdns"]
