FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".app.qstash" > "${WORKDIR}/qstash.json" \
    && cat "${WORKDIR}/qstash.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/qstash.json" | jq -Sr ".source" > "${WORKDIR}/qstash.autobuild" \
    && mkdir -p "${WORKDIR}/BUILDTMP/QSTASH" \
    && cd "${WORKDIR}/BUILDTMP/QSTASH" \
    && wget $(cat "${WORKDIR}/qstash.autobuild") \
    && tar -xzvf qstash-server_*.tar.gz \
    && rm -rf qstash-server_*.tar.gz

FROM scratch

COPY --from=get_info /tmp/BUILDTMP/QSTASH/ /
