# Current Version: 1.0.0

ARG POSTGRES_VERSION="17"

FROM paradedb/paradedb:latest-pg${POSTGRES_VERSION} AS paradedb

FROM postgres:${POSTGRES_VERSION}-bookworm AS icu

WORKDIR /tmp
RUN \
    sed -i "s/deb.debian.org/mirrors.ustc.edu.cn/g" "/etc/apt/sources.list.d/debian.sources" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        make \
        gcc \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt" \
    && curl -L -o icu4c-76_1-src.tgz "https://github.com/unicode-org/icu/releases/download/release-76-1/icu4c-76_1-src.tgz" \
    && tar xzvf icu4c-76_1-src.tgz \
    && cd icu/source \
    && ./runConfigureICU Linux --prefix="/tmp/BUILDLIB" \
    && make -j $(nproc) \
    && make install

FROM postgres:${POSTGRES_VERSION}-bookworm AS paradedb_rebase

ARG POSTGRES_VERSION

ENV \
    POSTGRES_VERSION="${POSTGRES_VERSION}"

COPY --from=icu /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=icu /tmp/BUILDLIB/ /usr/local/

COPY --from=paradedb /usr/lib/postgresql/${POSTGRES_VERSION}/lib /usr/lib/postgresql/${POSTGRES_VERSION}/lib
COPY --from=paradedb /usr/share/postgresql/${POSTGRES_VERSION}/extension /usr/share/postgresql/${POSTGRES_VERSION}/extension

COPY --from=paradedb /usr/share/postgresql/postgresql.conf.sample /usr/share/postgresql/postgresql.conf.sample

COPY --from=paradedb /docker-entrypoint-initdb.d/10_bootstrap_paradedb.sh /docker-entrypoint-initdb.d/10_bootstrap_paradedb.sh

RUN \
    sed -i "/postgis/d" "/docker-entrypoint-initdb.d/10_bootstrap_paradedb.sh" \
    && ldconfig && ldconfig

FROM scratch

COPY --from=paradedb_rebase / /

ENV \
    PATH="$PATH:/usr/lib/postgresql/17/bin" \
    PGDATA="/var/lib/postgresql/data" \
    PGPORT="5432" POSTGRES_DB="postgres" \
    POSTGRES_USER="postgres" \
    POSTGRES_PASSWORD="postgres"

EXPOSE 5432/tcp

USER postgres

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["postgres"]
