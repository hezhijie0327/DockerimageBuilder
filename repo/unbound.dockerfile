# Current Version: 1.5.3

ARG GCC_VERSION="14"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.unbound" > "${WORKDIR}/unbound.json" \
    && cat "${WORKDIR}/unbound.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/unbound.json" | jq -Sr ".source" > "${WORKDIR}/unbound.source.autobuild" \
    && cat "${WORKDIR}/unbound.json" | jq -Sr ".source_branch" > "${WORKDIR}/unbound.source_branch.autobuild" \
    && cat "${WORKDIR}/unbound.json" | jq -Sr ".patch" > "${WORKDIR}/unbound.patch.autobuild" \
    && cat "${WORKDIR}/unbound.json" | jq -Sr ".patch_branch" > "${WORKDIR}/unbound.patch_branch.autobuild" \
    && cat "${WORKDIR}/unbound.json" | jq -Sr ".version" > "${WORKDIR}/unbound.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/unbound.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/unbound.source.autobuild") "${WORKDIR}/BUILDTMP/UNBOUND" \
    && git clone -b $(cat "${WORKDIR}/unbound.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/unbound.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export UNBOUND_SHA=$(cd "${WORKDIR}/BUILDTMP/UNBOUND" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export UNBOUND_VERSION=$(cat "${WORKDIR}/unbound.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export UNBOUND_CUSTOM_VERSION="${UNBOUND_VERSION}-ZHIJIE-${UNBOUND_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/UNBOUND" \
    && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/unbound/*.patch \
    && sed -i "s/\(PACKAGE_STRING='unbound \)[0-9]\+\(\.[0-9]\+\)*'/\1${UNBOUND_CUSTOM_VERSION}'/;s/\(PACKAGE_VERSION='\)[0-9]\+\(\.[0-9]\+\)*'/\1${UNBOUND_CUSTOM_VERSION}'/" "${WORKDIR}/BUILDTMP/UNBOUND/configure" \
    && mkdir -p "${WORKDIR}/BUILDTMP/UNBOUND/etc/unbound" \
    && wget -O "${WORKDIR}/BUILDTMP/UNBOUND/etc/unbound/icannbundle.pem" "https://data.iana.org/root-anchors/icannbundle.pem" \
    && wget -O "${WORKDIR}/BUILDTMP/UNBOUND/etc/unbound/root.hints" "https://www.internic.net/domain/named.cache"

FROM ghcr.io/hezhijie0327/module:libexpat AS build_libexpat

FROM ghcr.io/hezhijie0327/module:libhiredis AS build_libhiredis

FROM ghcr.io/hezhijie0327/module:libmnl AS build_libmnl

FROM ghcr.io/hezhijie0327/module:libnghttp2 AS build_libnghttp2

FROM ghcr.io/hezhijie0327/module:libsodium AS build_libsodium

FROM ghcr.io/hezhijie0327/module:openssl AS build_openssl

FROM gcc:${GCC_VERSION} AS build_unbound

WORKDIR /unbound

COPY --from=get_info /tmp/BUILDTMP/UNBOUND /unbound

COPY --from=build_libexpat / /BUILDLIB/

COPY --from=build_libhiredis / /BUILDLIB/

COPY --from=build_libmnl / /BUILDLIB/

COPY --from=build_libnghttp2 / /BUILDLIB/

COPY --from=build_libsodium / /BUILDLIB/

COPY --from=build_openssl / /BUILDLIB/

RUN \
    PREFIX="/BUILDLIB" \
    && export CPPFLAGS="-I$PREFIX/include" \
    && export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib -s -static --static" \
    && export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH" \
    && export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" \
    && export PATH="$PREFIX/bin:$PATH" \
    && ldconfig --verbose \
    && apt update \
    && apt install -qy \
          bison flex \
          protobuf-c-compiler libprotobuf-c-dev \
          libbsd-dev \
          libev-libevent-dev \
    && ./configure \
          --enable-cachedb \
          --enable-dnscrypt \
          --enable-dnstap \
          --enable-fully-static \
          --enable-ipsecmod \
          --enable-ipset \
          --enable-pie \
          --enable-relro-now \
          --enable-subnet \
          --enable-tfo-client \
          --enable-tfo-server \
          --with-dynlibmodule \
          --with-libbsd \
          --with-libevent \
          --with-libexpat=$PREFIX \
          --with-libhiredis=$PREFIX \
          --with-libmnl=$PREFIX \
          --with-libnghttp2=$PREFIX \
          --with-libsodium=$PREFIX \
          --without-pthreads \
          --without-solaris-threads \
          --with-ssl=$PREFIX \
    && make -j $(nproc) \
    && make install \
    && "/usr/local/sbin/unbound-control-setup" -d "/unbound/etc/unbound" \
    && rm -rf "/usr/local/sbin/unbound-control-setup" \
    && strip -s /usr/local/sbin/unbound* \
    && /usr/local/sbin/unbound-anchor \
          -a "/unbound/etc/unbound/root.key" \
          -c "/unbound/etc/unbound/icannbundle.pem" \
          -f "/etc/resolv.conf" \
          -r "/unbound/etc/unbound/root.hints" \
          -v -R || logger "Please check root.key"

FROM scratch AS rebased_unbound

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_unbound /usr/local/sbin/unbound* /
COPY --from=build_unbound /unbound/etc/unbound /etc/unbound

FROM scratch

COPY --from=rebased_unbound / /

EXPOSE 443/tcp 53/tcp 53/udp 853/tcp

ENTRYPOINT ["/unbound"]
