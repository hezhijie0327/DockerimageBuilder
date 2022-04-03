# Current Version: 1.0.2

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/Patch/main/package.json" | jq -Sr ".module.c_ares" > "${WORKDIR}/c_ares.json" && cat "${WORKDIR}/c_ares.json" | jq -Sr ".version" && cat "${WORKDIR}/c_ares.json" | jq -Sr ".source" > "${WORKDIR}/c_ares.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_C_ARES

WORKDIR /tmp

COPY --from=GET_INFO /tmp/c_ares.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/C_ARES" && cd "${WORKDIR}/BUILDTMP/C_ARES" && curl -Ls -o - $(cat "${WORKDIR}/c_ares.autobuild") | tar zxvf - --strip-components=1 && ./configure --disable-tests --enable-static --prefix="${PREFIX}" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_C_ARES /tmp/BUILDLIB /
