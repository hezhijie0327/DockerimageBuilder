# Current Version: 1.0.1

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".module.libsodium" > "${WORKDIR}/libsodium.json" && cat "${WORKDIR}/libsodium.json" | jq -Sr ".version" && cat "${WORKDIR}/libsodium.json" | jq -Sr ".source" > "${WORKDIR}/libsodium.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_LIBSODIUM

WORKDIR /tmp

COPY --from=GET_INFO /tmp/libsodium.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/LIBSODIUM" && cd "${WORKDIR}/BUILDTMP/LIBSODIUM" && curl -Ls -o - $(cat "${WORKDIR}/libsodium.autobuild") | tar zxvf - --strip-components=1 && ./configure --enable-static --prefix="${PREFIX}/LIBSODIUM" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_LIBSODIUM /tmp/BUILDLIB/LIBSODIUM /
