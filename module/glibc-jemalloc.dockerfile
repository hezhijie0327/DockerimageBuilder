# Current Version: 1.0.1

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".module.jemalloc" > "${WORKDIR}/jemalloc.json" && cat "${WORKDIR}/jemalloc.json" | jq -Sr ".version" && cat "${WORKDIR}/jemalloc.json" | jq -Sr ".source" > "${WORKDIR}/jemalloc.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_JEMALLOC

WORKDIR /tmp

COPY --from=GET_INFO /tmp/jemalloc.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/JEMALLOC" && cd "${WORKDIR}/BUILDTMP/JEMALLOC" && curl -Ls -o - $(cat "${WORKDIR}/jemalloc.autobuild") | tar jxvf - --strip-components=1 && ./configure --disable-shared --enable-static --prefix="${PREFIX}/JEMALLOC" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_JEMALLOC /tmp/BUILDLIB/JEMALLOC /
