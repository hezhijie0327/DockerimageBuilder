ARG GCC_VERSION="15"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.lua" > "${WORKDIR}/lua.json" \
    && cat "${WORKDIR}/lua.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/lua.json" | jq -Sr ".source" > "${WORKDIR}/lua.autobuild" \
    && mkdir -p "${WORKDIR}/BUILDTMP/LUA" \
    && cd "${WORKDIR}/BUILDTMP/LUA" \
    && curl -Ls -o - $(cat "${WORKDIR}/lua.autobuild") | tar zxvf - --strip-components=1

FROM gcc:${GCC_VERSION} AS build_lua

WORKDIR /tmp

COPY --from=get_info /tmp/lua.autobuild /tmp/

RUN \
    PREFIX="/BUILDLIB" \
    && export CPPFLAGS="-I$PREFIX/include" \
    && export LDFLAGS="-L$PREFIX/lib64 -L$PREFIX/lib -s -static --static" \
    && export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH" \
    && export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" \
    && export PATH="$PREFIX/bin:$PATH" \
    && ldconfig --verbose \
    && make -j $(nproc) CFLAGS="-O3 -march=native -fPIE -fstack-protector-all -D_FORTIFY_SOURCE=2" LDFLAGS="-Wl,-z,now -Wl,-z,relro -ltermcap" linux \
    && make install INSTALL_TOP="${PREFIX}/LUA" INSTALL_LIB="${PREFIX}/LUA/lib"

FROM scratch

COPY --from=build_lua /tmp/BUILDLIB/LUA /
