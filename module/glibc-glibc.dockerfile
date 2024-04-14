# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".module.glibc" > "${WORKDIR}/glibc.json" && cat "${WORKDIR}/glibc.json" | jq -Sr ".version" && cat "${WORKDIR}/glibc.json" | jq -Sr ".source" > "${WORKDIR}/glibc.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_GLIBC

WORKDIR /tmp

COPY --from=GET_INFO /tmp/glibc.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/GLIBC" && cd "${WORKDIR}/BUILDTMP/GLIBC" && curl -Ls -o - $(cat "${WORKDIR}/glibc.autobuild") | tar xvf - --strip-components=1 && mkdir -p "${WORKDIR}/BUILDTMP/GLIBC/BUILDER" && cd "${WORKDIR}/BUILDTMP/GLIBC/BUILDER"  && ../configure --enable-static-nss --prefix="${PREFIX}/GLIBC" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_GLIBC /tmp/BUILDLIB/GLIBC /
