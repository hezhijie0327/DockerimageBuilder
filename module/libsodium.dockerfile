# Current Version: 1.0.3

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.libsodium" > "${WORKDIR}/libsodium.json" \
    && cat "${WORKDIR}/libsodium.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/libsodium.json" | jq -Sr ".source" > "${WORKDIR}/libsodium.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_LIBSODIUM

WORKDIR /tmp

COPY --from=GET_INFO /tmp/libsodium.autobuild /tmp/

RUN \
    export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDTMP/LIBSODIUM" \
    && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" \
    && cd "${WORKDIR}/BUILDTMP/LIBSODIUM" \
    && curl -Ls -o - $(cat "${WORKDIR}/libsodium.autobuild") | tar zxvf - --strip-components=1 \
    && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" \
    && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" \
    && export CPPFLAGS="-I${PREFIX}/include" \
    && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" \
    && ./configure --enable-static --prefix="${PREFIX}/LIBSODIUM" \
    && make -j $(nproc) \
    && make install

FROM scratch

COPY --from=BUILD_LIBSODIUM /tmp/BUILDLIB/LIBSODIUM /
