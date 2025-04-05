# Current Version: 1.0.1

ARG GCC_VERSION="14"

FROM hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.icu" > "${WORKDIR}/icu.json" \
    && cat "${WORKDIR}/icu.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/icu.json" | jq -Sr ".source" > "${WORKDIR}/icu.autobuild" \
    && mkdir -p "${WORKDIR}/BUILDTMP/ICU" \
    && cd "${WORKDIR}/BUILDTMP/ICU" \
    && curl -Ls -o - $(cat "${WORKDIR}/icu.autobuild") | tar zxvf - --strip-components=1

FROM gcc:${GCC_VERSION} AS build_icu

WORKDIR /icu

COPY --from=get_info /tmp/BUILDTMP/ICU /icu

RUN \
    PREFIX="/BUILDLIB" \
    && export CPPFLAGS="-I$PREFIX/include" \
    && export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib" \
    && export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH" \
    && export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" \
    && export PATH="$PREFIX/bin:$PATH" \
    && ldconfig --verbose \
    && cd source \
    && ./runConfigureICU Linux --disable-shared --enable-static --prefix="$PREFIX/ICU" \
    && make -j $(nproc) \
    && make install

FROM scratch

COPY --from=build_icu /BUILDLIB/ICU /
