ARG POSTGRES_VERSION="18"

FROM ghcr.io/hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && git clone -b "main" --depth=1 "https://github.com/hezhijie0327/DockerimageBuilder.git" "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER"

FROM postgres:${POSTGRES_VERSION} AS build_basic

ARG \
    POSTGRES_VERSION

ENV \
    DEBIAN_FRONTEND="noninteractive" \
    PATH="/root/.cargo/bin:$PATH" \
    PGX_HOME="/var/lib/postgresql/${POSTGRES_VERSION}" \
    PG_CONFIG="/usr/bin/pg_config" \
    POSTGRES_VERSION="${POSTGRES_VERSION}"

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && mkdir -p "${WORKDIR}/BUILDTMP" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        make \
        gcc \
        clang \
        jq \
        pkg-config \
        postgresql-server-dev-all \
        libopenblas-dev \
        libclang-dev \
        llvm-dev \
        libssl-dev \
    && curl --proto '=https' --tlsv1.2 -sSf "https://sh.rustup.rs" | sh -s -- --default-toolchain "stable" -y

FROM build_basic AS build_c_plugin

ENV \
    PG_CFLAGS="-Wall -Wextra -Werror -Wno-unused-parameter -Wno-sign-compare"

WORKDIR /tmp/BUILDTMP

RUN \
    export WORKDIR=$(pwd) \
    && git clone -b "main" --depth 1 "https://github.com/citusdata/pg_cron.git" "${WORKDIR}/pg_cron" \
    && cd "${WORKDIR}/pg_cron" \
    && echo "trusted = true" >> pg_cron.control \
    && make USE_PGXS=1 -j

WORKDIR /tmp/BUILDTMP

RUN \
    export WORKDIR=$(pwd) \
    && git clone -b "main" --depth 1 "https://github.com/sraoss/pg_ivm.git" "${WORKDIR}/pg_ivm" \
    && cd "${WORKDIR}/pg_ivm" \
    && echo "trusted = true" >> pg_ivm.control \
    && make USE_PGXS=1 CFLAGS="-Wno-error=clobbered" -j

WORKDIR /tmp/BUILDTMP

RUN \
    export WORKDIR=$(pwd) \
    && git clone -b "master" --depth 1 "https://github.com/pgvector/pgvector.git" "${WORKDIR}/pgvector" \
    && cd "${WORKDIR}/pgvector" \
    && echo "trusted = true" >> vector.control \
    && make USE_PGXS=1 CFLAGS="-Wno-error=missing-field-initializers" -j

FROM build_basic AS build_rust_plugin

ENV \
    RUSTFLAGS="-C target-feature=-crt-static"

WORKDIR /tmp/BUILDTMP

RUN \
    export WORKDIR=$(pwd) \
    && git clone -b "main" --depth 1 "https://github.com/paradedb/paradedb.git" "${WORKDIR}/paradedb" \
    && cd paradedb \
    && export PGRX_VERSION=$(cargo tree --depth 1 -i pgrx -p pg_search | head -n 1 | sed -E 's/.*v([0-9]+\.[0-9]+\.[0-9]+).*/\1/') \
    && cargo install --locked cargo-pgrx --version "${PGRX_VERSION}" \
    && cargo pgrx init "--pg${POSTGRES_VERSION}=${PG_CONFIG}" \
    && cd pg_search \
    && cargo pgrx package --pg-config "${PG_CONFIG}"

WORKDIR /tmp/BUILDTMP

RUN \
    export WORKDIR=$(pwd) \
    && git clone -b "main" --depth 1 "https://github.com/timescale/pgvectorscale.git" "${WORKDIR}/pgvectorscale" \
    && cd pgvectorscale/pgvectorscale \
    && if [ "$(uname -m)" = "x86_64" ]; then \
        export RUSTFLAGS="-C target-feature=-crt-static,+avx2,+fma"; \
    fi \
    && cargo install --locked cargo-pgrx --version $(cargo metadata --format-version 1 | jq -r '.packages[] | select(.name == "pgrx") | .version') \
    && cargo pgrx init "--pg${POSTGRES_VERSION}=${PG_CONFIG}" \
    && cargo pgrx package --pg-config "${PG_CONFIG}"

FROM postgres:${POSTGRES_VERSION} AS postgres_rebase

ARG \
    POSTGRES_VERSION

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=get_info /tmp/BUILDTMP/DOCKERIMAGEBUILDER/patch/postgres/bootstrap.sh /docker-entrypoint-initdb.d/10_bootstrap_custom_patch.sh

COPY --from=build_c_plugin /tmp/BUILDTMP/pg_cron/*.so /usr/lib/postgresql/${POSTGRES_VERSION}/lib/
COPY --from=build_c_plugin /tmp/BUILDTMP/pg_cron/*.control /usr/share/postgresql/${POSTGRES_VERSION}/extension/
COPY --from=build_c_plugin /tmp/BUILDTMP/pg_cron/*.sql /usr/share/postgresql/${POSTGRES_VERSION}/extension/

COPY --from=build_c_plugin /tmp/BUILDTMP/pg_ivm/*.so /usr/lib/postgresql/${POSTGRES_VERSION}/lib/
COPY --from=build_c_plugin /tmp/BUILDTMP/pg_ivm/*.control /usr/share/postgresql/${POSTGRES_VERSION}/extension/
COPY --from=build_c_plugin /tmp/BUILDTMP/pg_ivm/*.sql /usr/share/postgresql/${POSTGRES_VERSION}/extension/

COPY --from=build_c_plugin /tmp/BUILDTMP/pgvector/*.so /usr/lib/postgresql/${POSTGRES_VERSION}/lib/
COPY --from=build_c_plugin /tmp/BUILDTMP/pgvector/*.control /usr/share/postgresql/${POSTGRES_VERSION}/extension/
COPY --from=build_c_plugin /tmp/BUILDTMP/pgvector/sql/*.sql /usr/share/postgresql/${POSTGRES_VERSION}/extension/

COPY --from=build_rust_plugin /tmp/BUILDTMP/paradedb/target/release/pg_search-pg*/usr/lib/postgresql/${POSTGRES_VERSION}/lib/* /usr/lib/postgresql/${POSTGRES_VERSION}/lib/
COPY --from=build_rust_plugin /tmp/BUILDTMP/paradedb/target/release/pg_search-pg*/usr/share/postgresql/${POSTGRES_VERSION}/extension/* /usr/share/postgresql/${POSTGRES_VERSION}/extension/

COPY --from=build_rust_plugin /tmp/BUILDTMP/pgvectorscale/target/release/vectorscale-pg*/usr/lib/postgresql/${POSTGRES_VERSION}/lib/* /usr/lib/postgresql/${POSTGRES_VERSION}/lib/
COPY --from=build_rust_plugin /tmp/BUILDTMP/pgvectorscale/target/release/vectorscale-pg*/usr/share/postgresql/${POSTGRES_VERSION}/extension/* /usr/share/postgresql/${POSTGRES_VERSION}/extension/

RUN \
    mkdir -p /data \
    && sed -i "2i export PATH=\"/usr/lib/postgresql/${POSTGRES_VERSION}/bin:\$PATH\"" "/usr/local/bin/docker-entrypoint.sh" \
    && sed -i "s/^#shared_preload_libraries = ''/shared_preload_libraries = 'pg_search,pg_cron'/" "/usr/share/postgresql/postgresql.conf.sample" \
    && echo "cron.database_name = 'postgres'" >> "/usr/share/postgresql/postgresql.conf.sample"

FROM scratch

COPY --from=postgres_rebase / /

ENV \
    DEBIAN_FRONTEND="noninteractive" \
    PGDATA="/data" PGPORT="5432" \
    POSTGRES_DB="postgres" \
    POSTGRES_USER="postgres" \
    POSTGRES_PASSWORD="postgres"

EXPOSE 5432/tcp

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["postgres"]
