# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".module.nghttp3" > "${WORKDIR}/nghttp3.json" && cat "${WORKDIR}/nghttp3.json" | jq -Sr ".version" && cat "${WORKDIR}/nghttp3.json" | jq -Sr ".source" > "${WORKDIR}/nghttp3.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_NGHTTP3

WORKDIR /tmp

COPY --from=GET_INFO /tmp/nghttp3.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB/NGHTTP3" && export PATH="${PREFIX}/bin:${PATH}" && mkdir -p "${WORKDIR}/BUILDTMP/NGHTTP3" && cd "${WORKDIR}/BUILDTMP/NGHTTP3" && curl -Ls -o - $(cat "${WORKDIR}/nghttp3.autobuild") | tar zxvf - --strip-components=1 && autoreconf -i && ./configure --disable-shared --enable-asan --enable-static --enable-year2038 --prefix=${PREFIX} && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_NGHTTP3 /tmp/BUILDLIB/NGHTTP3 /
