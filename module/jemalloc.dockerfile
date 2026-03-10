ARG GCC_VERSION="15"

FROM ghcr.io/hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.jemalloc" > "${WORKDIR}/jemalloc.json" \
    && cat "${WORKDIR}/jemalloc.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/jemalloc.json" | jq -Sr ".source" > "${WORKDIR}/jemalloc.autobuild" \
    && mkdir -p "${WORKDIR}/BUILDTMP/JEMALLOC" \
    && cd "${WORKDIR}/BUILDTMP/JEMALLOC" \
    && curl -Ls -o - $(cat "${WORKDIR}/jemalloc.autobuild") | tar jxvf - --strip-components=1

FROM gcc:${GCC_VERSION} AS build_jemalloc

WORKDIR /jemalloc

COPY --from=get_info /tmp/BUILDTMP/JEMALLOC /jemalloc

RUN \
    PREFIX="/BUILDLIB" \
    && export CPPFLAGS="-I$PREFIX/include" \
    && export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib -s -static --static" \
    && export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH" \
    && export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" \
    && export PATH="$PREFIX/bin:$PATH" \
    && ldconfig --verbose \
    && ./configure --disable-shared --enable-static --prefix="${PREFIX}/JEMALLOC" \
    && make -j $(nproc) \
    && make install

FROM scratch

COPY --from=build_jemalloc /BUILDLIB/JEMALLOC /
