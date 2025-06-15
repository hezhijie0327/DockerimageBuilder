# Current Version: 1.0.0

ARG GCC_VERSION="14"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.libnghttp3" > "${WORKDIR}/libnghttp3.json" \  
    && cat "${WORKDIR}/libnghttp3.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/libnghttp3.json" | jq -Sr ".source" > "${WORKDIR}/libnghttp3.autobuild" \
    && mkdir -p "${WORKDIR}/BUILDTMP/LIBNGHTTP3" \
    && cd "${WORKDIR}/BUILDTMP/LIBNGHTTP3" \
    && curl -Ls -o - $(cat "${WORKDIR}/libnghttp3.autobuild") | tar zxvf - --strip-components=1

FROM gcc:${GCC_VERSION} AS build_libnghttp3

WORKDIR /libnghttp3

COPY --from=get_info /tmp/BUILDTMP/LIBNGHTTP3 /libnghttp3

RUN \
    PREFIX="/BUILDLIB" \
    && export CPPFLAGS="-I$PREFIX/include" \
    && export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib -s -static --static" \
    && export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH" \
    && export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" \
    && export PATH="$PREFIX/bin:$PATH" \
    && ldconfig --verbose \
    && ./configure --enable-static --prefix="$PREFIX/LIBNGHTTP3" \
    && make -j $(nproc) \
    && make install

FROM scratch

COPY --from=build_libnghttp3 /BUILDLIB/LIBNGHTTP3 /
