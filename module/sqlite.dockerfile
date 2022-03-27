# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".module.sqlite" > "${WORKDIR}/sqlite.json" && cat "${WORKDIR}/sqlite.json" | jq -Sr ".version" && cat "${WORKDIR}/sqlite.json" | jq -Sr ".source" > "${WORKDIR}/sqlite.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_SQLITE

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /tmp

COPY --from=GET_INFO /tmp/sqlite.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/SQLITE" && cd "${WORKDIR}/BUILDTMP/SQLITE" && curl -Ls -o - $(cat "${WORKDIR}/sqlite.autobuild") | tar zxvf - --strip-components=1 && ./configure --disable-dynamic-extensions --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_SQLITE /tmp/BUILDLIB /
