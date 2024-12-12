# Current Version: 1.0.2

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".module.pcre2" > "${WORKDIR}/pcre2.json" && cat "${WORKDIR}/pcre2.json" | jq -Sr ".version" && cat "${WORKDIR}/pcre2.json" | jq -Sr ".source" > "${WORKDIR}/pcre2.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_PCRE2

WORKDIR /tmp

COPY --from=GET_INFO /tmp/pcre2.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/PCRE2" && cd "${WORKDIR}/BUILDTMP/PCRE2" && curl -Ls -o - $(cat "${WORKDIR}/pcre2.autobuild") | tar zxvf - --strip-components=1 && ./configure --disable-shared --enable-jit --enable-pcregrep-jit --prefix="${PREFIX}/PCRE2" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_PCRE2 /tmp/BUILDLIB/PCRE2 /
