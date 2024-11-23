# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".module.quictls" > "${WORKDIR}/quictls.json" && cat "${WORKDIR}/quictls.json" | jq -Sr ".version" && cat "${WORKDIR}/quictls.json" | jq -Sr ".source" > "${WORKDIR}/quictls.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_QUICTLS

WORKDIR /tmp

COPY --from=GET_INFO /tmp/quictls.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/QUICTLS" && cd "${WORKDIR}/BUILDTMP/QUICTLS" && curl -Ls -o - $(cat "${WORKDIR}/quictls.autobuild") | tar zxvf - --strip-components=1 && ./config --prefix="${PREFIX}/QUICTLS" && make -j $(nproc) && make install_sw && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_QUICTLS /tmp/BUILDLIB/QUICTLS /
