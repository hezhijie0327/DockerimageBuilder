# Current Version: 1.0.5

ARG POSTGRES_VERSION="17"

FROM postgres:${POSTGRES_VERSION}-bookworm AS build_basic

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && mkdir -p "${WORKDIR}/BUILDTMP" \
    && apt update \
    && apt install -qy \
        software-properties-common \
        ca-certificates \
        build-essential \
        gnupg \
        curl \
        git \
        make \
        gcc \
        clang \
        jq \
        pkg-config \
        libopenblas-dev \
        postgresql-server-dev-all \
    && curl -s --connect-timeout 15 "https://curl.se/ca/cacert.pem" > "/etc/ssl/certs/cacert.pem" && mv "/etc/ssl/certs/cacert.pem" "/etc/ssl/certs/ca-certificates.crt"

FROM build_basic AS build_icu

ENV \
    ICU_VERSION_FIXED=""

WORKDIR /tmp/BUILDTMP

RUN \
    export WORKDIR=$(pwd) \
    && mkdir -p "${WORKDIR}/icu" \
    && cd "${WORKDIR}/icu" \
    && export ICU_VERSION=$(curl -s --connect-timeout 15 "https://api.github.com/repos/unicode-org/icu/git/matching-refs/tags" | jq -Sr ".[].ref" | grep "^refs/tags/release" | grep -v "alpha\|eclipse\|rc\|preview" | tail -n 1 | sed "s/refs\/tags\/release\-//" | tr '-' '.') \
    && curl -Ls -o - "https://github.com/unicode-org/icu/releases/download/release-$(echo ${ICU_VERSION_FIXED:-${ICU_VERSION}} | sed 's/\./-/g')/icu4c-$(echo ${ICU_VERSION_FIXED:-${ICU_VERSION}} | sed 's/\./_/g')-src.tgz" | tar zxvf - --strip-components=1 \
    && cd "${WORKDIR}/icu/source" \
    && ./runConfigureICU Linux --prefix="/icu" \
    && make -j $(nproc) \
    && make install

FROM build_basic AS build_pg_search

ARG \
    POSTGRES_VERSION

ENV \
    PATH="/usr/local/bin:/root/.cargo/bin:$PATH" \
    PGX_HOME="/usr/lib/postgresql/${POSTGRES_VERSION}" \
    POSTGRES_VERSION="${POSTGRES_VERSION}"

COPY --from=build_icu /icu/ /usr/local/

WORKDIR /tmp/BUILDTMP

RUN \
    export WORKDIR=$(pwd) \
    && curl --proto '=https' --tlsv1.2 -sSf "https://sh.rustup.rs" | sh -s -- --default-toolchain "stable" -y \
    && git clone -b dev --depth 1 "https://github.com/paradedb/paradedb" "${WORKDIR}/paradedb" \
    && cd paradedb \
    && export PGRX_VERSION=$(cargo tree --depth 1 -i pgrx -p pg_search | head -n 1 | sed -E 's/.*v([0-9]+\.[0-9]+\.[0-9]+).*/\1/') \
    && cargo install --locked cargo-pgrx --version "${PGRX_VERSION}" \
    && cargo pgrx init "--pg${POSTGRES_VERSION}=/usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_config" \
    && cd pg_search \
    && ldconfig && ldconfig \
    && cargo pgrx package --features icu --pg-config "/usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_config"

FROM build_basic AS build_pgvector

ARG \
    POSTGRES_VERSION

ENV \
    PG_CFLAGS="-Wall -Wextra -Werror -Wno-unused-parameter -Wno-sign-compare" \
    PG_CONFIG="/usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_config"

WORKDIR /tmp/BUILDTMP

RUN \
    export WORKDIR=$(pwd) \
    && git clone -b "master" --depth 1 "https://github.com/pgvector/pgvector.git" "${WORKDIR}/pgvector" \
    && cd "${WORKDIR}/pgvector" \
    && echo "trusted = true" >> vector.control \
    && make USE_PGXS=1 -j

FROM build_basic AS build_pg_cron

WORKDIR /tmp/BUILDTMP

RUN \
    export WORKDIR=$(pwd) \
    && git clone -b "main" --depth 1 "https://github.com/citusdata/pg_cron.git" "${WORKDIR}/pg_cron" \
    && cd "${WORKDIR}/pg_cron" \
    && echo "trusted = true" >> pg_cron.control \
    && make USE_PGXS=1 -j

FROM build_basic AS build_pg_ivm

WORKDIR /tmp/BUILDTMP

RUN \
    export WORKDIR=$(pwd) \
    && git clone -b "main" --depth 1 "https://github.com/sraoss/pg_ivm.git" "${WORKDIR}/pg_ivm" \
    && cd "${WORKDIR}/pg_ivm" \
    && echo "trusted = true" >> pg_ivm.control \
    && make USE_PGXS=1 -j

FROM postgres:${POSTGRES_VERSION}-bookworm AS paradedb_rebase

ARG \
    POSTGRES_VERSION

ENV \
    POSTGRES_VERSION="${POSTGRES_VERSION}"

# SSL cert
COPY --from=build_basic /etc/ssl/certs/ca-certificates.crt /tmp/BUILDKIT/etc/ssl/certs/ca-certificates.crt

# ICU
COPY --from=build_icu /icu/ /usr/local/

# ParadeDB bootstrap
COPY --from=build_pg_search /tmp/BUILDTMP/paradedb/docker/bootstrap.sh /docker-entrypoint-initdb.d/10_bootstrap_paradedb.sh

# ParadeDB extensions
COPY --from=build_pg_search /tmp/BUILDTMP/paradedb/target/release/pg_search-pg${POSTGRES_VERSION}/usr/lib/postgresql/${POSTGRES_VERSION}/lib/* /usr/lib/postgresql/${POSTGRES_VERSION}/lib/
COPY --from=build_pg_search /tmp/BUILDTMP/paradedb/target/release/pg_search-pg${POSTGRES_VERSION}/usr/share/postgresql/${POSTGRES_VERSION}/extension/* /usr/share/postgresql/${POSTGRES_VERSION}/extension/

# 3rd party extensions
COPY --from=build_pg_cron /tmp/BUILDTMP/pg_cron/*.so /usr/lib/postgresql/${POSTGRES_VERSION}/lib/
COPY --from=build_pg_cron /tmp/BUILDTMP/pg_cron/*.control /usr/share/postgresql/${POSTGRES_VERSION}/extension/
COPY --from=build_pg_cron /tmp/BUILDTMP/pg_cron/sql/*.sql /usr/share/postgresql/${POSTGRES_VERSION}/extension/

COPY --from=build_pg_ivm /tmp/BUILDTMP/pg_ivm/*.so /usr/lib/postgresql/${POSTGRES_VERSION}/lib/
COPY --from=build_pg_ivm /tmp/BUILDTMP/pg_ivm/*.control /usr/share/postgresql/${POSTGRES_VERSION}/extension/
COPY --from=build_pg_ivm /tmp/BUILDTMP/pg_ivm/sql/*.sql /usr/share/postgresql/${POSTGRES_VERSION}/extension/

COPY --from=build_pgvector /tmp/BUILDTMP/pgvector/*.so /usr/lib/postgresql/${POSTGRES_VERSION}/lib/
COPY --from=build_pgvector /tmp/BUILDTMP/pgvector/*.control /usr/share/postgresql/${POSTGRES_VERSION}/extension/
COPY --from=build_pgvector /tmp/BUILDTMP/pgvector/sql/*.sql /usr/share/postgresql/${POSTGRES_VERSION}/extension/

RUN \
    ldconfig && ldconfig \
    && sed -i "/postgis/d" "/docker-entrypoint-initdb.d/10_bootstrap_paradedb.sh" \
    && sed -i "s/^#shared_preload_libraries = ''/shared_preload_libraries = 'pg_cron,pg_ivm,pg_search'/" "/usr/share/postgresql/postgresql.conf.sample" \
    && echo "cron.database_name = 'postgres'" >> "/usr/share/postgresql/postgresql.conf.sample"

FROM scratch

COPY --from=paradedb_rebase / /

ARG \
    POSTGRES_VERSION

ENV \
    PATH="/usr/lib/postgresql/${POSTGRES_VERSION}/bin:$PATH" \
    PGDATA="/var/lib/postgresql/data" \
    PGPORT="5432" POSTGRES_DB="postgres" \
    POSTGRES_USER="postgres" \
    POSTGRES_PASSWORD="postgres"

EXPOSE 5432/tcp

USER postgres

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["postgres"]
