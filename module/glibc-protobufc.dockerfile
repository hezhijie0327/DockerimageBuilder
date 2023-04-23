# Current Version: 1.0.1

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".module.protobuf_c" > "${WORKDIR}/protobuf_c.json" && cat "${WORKDIR}/protobuf_c.json" | jq -Sr ".version" && cat "${WORKDIR}/protobuf_c.json" | jq -Sr ".source" > "${WORKDIR}/protobuf_c.autobuild"

FROM hezhijie0327/base:ubuntu AS BUILD_PROTOBUF_C

WORKDIR /tmp

COPY --from=GET_INFO /tmp/protobuf_c.autobuild /tmp/

RUN export WORKDIR=$(pwd) && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}" && export PKG_CONFIG_PATH="${PREFIX}/lib64/pkgconfig:${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" && export CPPFLAGS="-I${PREFIX}/include" && export LDFLAGS="-L${PREFIX}/lib64 -L${PREFIX}/lib -s -static --static" && mkdir -p "${WORKDIR}/BUILDTMP/PROTOBUF_C" && cd "${WORKDIR}/BUILDTMP/PROTOBUF_C" && curl -Ls -o - $(cat "${WORKDIR}/protobuf_c.autobuild") | tar zxvf - --strip-components=1 && ./configure --disable-protoc --enable-static --prefix="${PREFIX}/PROTOBUF_C" && make -j $(nproc) && make install && ldconfig --verbose && cd "${WORKDIR}"

FROM scratch

COPY --from=BUILD_PROTOBUF_C /tmp/BUILDLIB/PROTOBUF_C /
