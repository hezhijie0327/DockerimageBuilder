# Current Version: 1.0.3

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".module.pcre2" > "${WORKDIR}/pcre2.json" \
    && cat "${WORKDIR}/pcre2.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/pcre2.json" | jq -Sr ".source" > "${WORKDIR}/pcre2.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_PCRE2

WORKDIR /tmp

COPY --from=GET_INFO /tmp/pcre2.autobuild /tmp/

RUN \
    export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDTMP/PCRE2" \
    && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" \
    && cd "${WORKDIR}/BUILDTMP/PCRE2" \
    && curl -Ls -o - $(cat "${WORKDIR}/pcre2.autobuild") | tar zxvf - --strip-components=1 \
    && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" \
    && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" \
    && export CPPFLAGS="-I${PREFIX}/include" \
    && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" \
    && ./configure --disable-shared --enable-jit --enable-pcregrep-jit --prefix="${PREFIX}/PCRE2" \
    && make -j $(nproc) \
    && make install

FROM scratch

COPY --from=BUILD_PCRE2 /tmp/BUILDLIB/PCRE2 /
