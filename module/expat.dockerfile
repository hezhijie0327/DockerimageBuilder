# Current Version: 1.0.8

FROM hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.expat" > "${WORKDIR}/expat.json" \
    && cat "${WORKDIR}/expat.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/expat.json" | jq -Sr ".source" > "${WORKDIR}/expat.autobuild"

FROM hezhijie0327/base:ubuntu AS build_expat

WORKDIR /tmp

COPY --from=get_info /tmp/expat.autobuild /tmp/

RUN \
    export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDTMP/EXPAT" \
    && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" \
    && cd "${WORKDIR}/BUILDTMP/EXPAT" \
    && curl -Ls -o - $(cat "${WORKDIR}/expat.autobuild") | tar zxvf - --strip-components=1 \
    && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" \
    && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" \
    && export CPPFLAGS="-I${PREFIX}/include" \
    && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" \
    && ./configure --enable-static --prefix="${PREFIX}/EXPAT" --without-docbook --without-examples --without-tests \
    && make -j $(nproc) \
    && make install

FROM scratch

COPY --from=build_expat /tmp/BUILDLIB/EXPAT /
