FROM ghcr.io/hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".app.qstash" > "${WORKDIR}/qstash.json" \
    && cat "${WORKDIR}/qstash.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/qstash.json" | jq -Sr ".source" > "${WORKDIR}/qstash.autobuild" \
    && mkdir -p "${WORKDIR}/BUILDTMP/QSTASH" \
    && cd "${WORKDIR}/BUILDTMP/QSTASH" \
    && wget $(cat "${WORKDIR}/qstash.autobuild" | sed "s|{SYS_ARCH}|$(uname -m | sed 's/x86_64/amd64/g;s/aarch64/arm64/g')|g") \
    && tar -xzvf qstash-server_*.tar.gz \
    && rm -rf qstash-server_*.tar.gz

FROM debian:stable-slim AS rebased_qstash

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=get_info /tmp/BUILDTMP/QSTASH /app

FROM scratch

ENV \
    QSTASH_DEV_PORT="8080" QSTASH_DEV_LOG_PORT="8081" \
    QSTASH_DEV_QUOTA="pro" \
    QSTASH_CURRENT_SIGNING_KEY="" \
    QSTASH_NEXT_SIGNING_KEY="" \
    QSTASH_TOKEN=""

COPY --from=rebased_qstash / /

EXPOSE 8080/tcp 8081/tcp

ENTRYPOINT ["/app/qstash"]
