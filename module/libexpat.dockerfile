# Current Version: 1.1.3

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.libexpat" > "${WORKDIR}/libexpat.json" \
    && cat "${WORKDIR}/libexpat.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/libexpat.json" | jq -Sr ".source" > "${WORKDIR}/libexpat.autobuild" \
    && mkdir -p "${WORKDIR}/BUILDTMP/LIBEXPAT" \
    && cd "${WORKDIR}/BUILDTMP/LIBEXPAT" \
    && curl -Ls -o - $(cat "${WORKDIR}/libexpat.autobuild") | tar zxvf - --strip-components=1

FROM hezhijie0327/base:debian AS build_libexpat

WORKDIR /libexpat

COPY --from=get_info /tmp/BUILDTMP/LIBEXPAT /libexpat

RUN \
    PREFIX="/BUILDLIB" \
    && export CPPFLAGS="-I$PREFIX/include" \
    && export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib -s -static --static" \
    && export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH" \
    && export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" \
    && export PATH="$PREFIX/bin:$PATH" \
    && ldconfig --verbose \
    && ./configure --enable-static --prefix="$PREFIX/LIBEXPAT" --without-docbook --without-examples --without-tests \
    && make -j $(nproc) \
    && make install

FROM scratch

COPY --from=build_libexpat /BUILDLIB/LIBEXPAT /
