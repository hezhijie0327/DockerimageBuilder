# Current Version: 1.0.3

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".module.libmnl" > "${WORKDIR}/libmnl.json" && cat "${WORKDIR}/libmnl.json" | jq -Sr ".version" && cat "${WORKDIR}/libmnl.json" | jq -Sr ".source" > "${WORKDIR}/libmnl.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_LIBMNL

WORKDIR /tmp

COPY --from=GET_INFO /tmp/libmnl.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/LIBMNL" && cd "${WORKDIR}/BUILDTMP/LIBMNL" && curl -Ls -o - $(cat "${WORKDIR}/libmnl.autobuild") | tar jxvf - --strip-components=1 && ./configure --enable-static --prefix="${PREFIX}/LIBMNL" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_LIBMNL /tmp/BUILDLIB/LIBMNL /
