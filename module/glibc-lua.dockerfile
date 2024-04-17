# Current Version: 1.0.1

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".module.lua" > "${WORKDIR}/lua.json" && cat "${WORKDIR}/lua.json" | jq -Sr ".version" && cat "${WORKDIR}/lua.json" | jq -Sr ".source" > "${WORKDIR}/lua.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_LUA

WORKDIR /tmp

COPY --from=GET_INFO /tmp/lua.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/LUA" && cd "${WORKDIR}/BUILDTMP/LUA" && curl -Ls -o - $(cat "${WORKDIR}/lua.autobuild") | tar zxvf - --strip-components=1 && make CFLAGS="-O3 -march=core2 -fPIE -fstack-protector-all -D_FORTIFY_SOURCE=2" LDFLAGS="-Wl,-z,now -Wl,-z,relro -ltermcap" linux && make install INSTALL_TOP="${PREFIX}/LUA" INSTALL_LIB="${PREFIX}/LUA/lib" && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_LUA /tmp/BUILDLIB/LUA /
