# Current Version: 1.0.6

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".module.gperftools" > "${WORKDIR}/gperftools.json" && cat "${WORKDIR}/gperftools.json" | jq -Sr ".version" && cat "${WORKDIR}/gperftools.json" | jq -Sr ".source" > "${WORKDIR}/gperftools.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_GPERFTOOLS

WORKDIR /tmp

COPY --from=GET_INFO /tmp/gperftools.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/GPERFTOOLS" && cd "${WORKDIR}/BUILDTMP/GPERFTOOLS" && curl -Ls -o - $(cat "${WORKDIR}/gperftools.autobuild") | tar zxvf - --strip-components=1 && ./configure --enable-static --prefix="${PREFIX}/GPERFTOOLS" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_GPERFTOOLS /tmp/BUILDLIB/GPERFTOOLS /
