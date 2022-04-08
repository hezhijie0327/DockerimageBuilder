# Current Version: 1.0.1

FROM hezhijie0327/base:alpine AS BUILD_NINJA

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDLIB" "${WORKDIR}/BUILDTMP" && cd "${WORKDIR}/BUILDLIB" && git clone --depth=1 "https://github.com/ninja-build/ninja.git" "${WORKDIR}/BUILDTMP/NINJA" && cd "${WORKDIR}/BUILDTMP/NINJA" && cmake -Wno-dev -Wno-deprecated -B build -D CMAKE_BUILD_TYPE="release" -D CMAKE_CXX_STANDARD="17" -D CMAKE_CXX_FLAGS="-std=c++17 -static -w -I${WORKDIR}/BUILDLIB/include" -D CMAKE_INSTALL_PREFIX="${WORKDIR}/BUILDLIB" && cmake --build build -j "$(nproc)" && cmake --install build && cd "${WORKDIR}" && for i in {1..10}; do find "${WORKDIR}/BUILDLIB" -type d -empty -delete; done

FROM scratch

COPY --from=BUILD_NINJA /tmp/BUILDLIB /
