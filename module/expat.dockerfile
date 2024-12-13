# Current Version: 1.0.6

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.expat" > "${WORKDIR}/expat.json" \
    && cat "${WORKDIR}/expat.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/expat.json" | jq -Sr ".source" > "${WORKDIR}/expat.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_EXPAT

WORKDIR /tmp

COPY --from=GET_INFO /tmp/expat.autobuild /tmp/

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
    && make install \
    && ldconfig --verbose \
    && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_EXPAT /tmp/BUILDLIB/EXPAT /
