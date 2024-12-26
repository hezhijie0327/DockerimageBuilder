# Current Version: 1.0.5

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.libsodium" > "${WORKDIR}/libsodium.json" \
    && cat "${WORKDIR}/libsodium.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/libsodium.json" | jq -Sr ".source" > "${WORKDIR}/libsodium.autobuild" \
    && mkdir -p "${WORKDIR}/BUILDTMP/LIBSODIUM" \
    && cd "${WORKDIR}/BUILDTMP/LIBSODIUM" \
    && curl -Ls -o - $(cat "${WORKDIR}/libsodium.autobuild") | tar zxvf - --strip-components=1

FROM hezhijie0327/base:ubuntu AS build_libsodium

WORKDIR /libsodium

COPY --from=get_info /tmp/BUILDTMP/LIBSODIUM /libsodium

RUN \
    PREFIX="/BUILDLIB" \
    && export CPPFLAGS="-I$PREFIX/include" \
    && export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib -s -static --static" \
    && export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH" \
    && export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" \
    && export PATH="$PREFIX/bin:$PATH" \
    && ldconfig --verbose \
    && ./configure --enable-static --prefix="$PREFIX/LIBSODIUM" \
    && make -j $(nproc) \
    && make install

FROM scratch

COPY --from=build_libsodium /BUILDLIB/LIBSODIUM /
