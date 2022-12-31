# Current Version: 1.0.0

FROM hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM hezhijie0327/base:ubuntu AS BUILD_JELLYFIN_WEB

WORKDIR /tmp

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone https://github.com/jellyfin/jellyfin-web --depth=1 && cd "${WORKDIR}/BUILDTMP/jellyfin-web" && npm ci --no-audit --unsafe-perm && mv dist "${WORKDIR}/BUILDKIT/jellyfin-web"

FROM scratch

COPY --from=BUILD_JELLYFIN_WEB /tmp/BUILDKIT /
