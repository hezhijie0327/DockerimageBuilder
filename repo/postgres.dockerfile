# Current Version: 1.4.0

ARG POSTGRES_VERSION="18"

FROM ghcr.io/hezhijie0327/module:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && git clone -b "main" --depth=1 "https://github.com/hezhijie0327/DockerimageBuilder.git" "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER"

FROM postgres:${POSTGRES_VERSION}-alpine AS build_basic

ENV \
    CLANG_VERSION="19" \
    PATH="/root/.cargo/bin:$PATH" \
    PGX_HOME="/var/lib/postgresql"

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && mkdir -p "${WORKDIR}/BUILDTMP" \
    && apk add --no-cache \
        build-base \
        curl \
        git \
        make \
        gcc \
        clang \
        clang${CLANG_VERSION} \
        jq \
        pkgconf \
        openblas-dev \
        postgresql-dev \
        clang-libclang \
        clang-static \
        llvm-static \
        clang${CLANG_VERSION}-libclang \
        clang${CLANG_VERSION}-static \
        llvm${CLANG_VERSION}-static \
        openssl-libs-static \
    && curl --proto '=https' --tlsv1.2 -sSf "https://sh.rustup.rs" | sh -s -- --default-toolchain "stable" -y

FROM build_basic AS build_c_plugin

ENV \
    PG_CFLAGS="-Wall -Wextra -Werror -Wno-unused-parameter -Wno-sign-compare" \
    PG_CONFIG="/usr/local/bin/pg_config"

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

ARG \
    POSTGRES_VERSION

ENV \
    POSTGRES_VERSION="${POSTGRES_VERSION}" \
    RUSTFLAGS="-C target-feature=-crt-static"

WORKDIR /tmp/BUILDTMP

RUN \
    export WORKDIR=$(pwd) \
    && git clone -b "main" --depth 1 "https://github.com/paradedb/paradedb.git" "${WORKDIR}/paradedb" \
    && cd paradedb \
    && export PGRX_VERSION=$(cargo tree --depth 1 -i pgrx -p pg_search | head -n 1 | sed -E 's/.*v([0-9]+\.[0-9]+\.[0-9]+).*/\1/') \
    && cargo install --locked cargo-pgrx --version "${PGRX_VERSION}" \
    && cargo pgrx init "--pg${POSTGRES_VERSION}=/usr/local/bin/pg_config" \
    && cd pg_search \
    && cargo pgrx package --pg-config "/usr/local/bin/pg_config"

WORKDIR /tmp/BUILDTMP

RUN \
    export WORKDIR=$(pwd) \
    && git clone -b "main" --depth 1 "https://github.com/timescale/pgvectorscale.git" "${WORKDIR}/pgvectorscale" \
    && cd pgvectorscale/pgvectorscale \
    && if [ "$(uname -m)" = "x86_64" ]; then \
        export RUSTFLAGS="-C target-feature=-crt-static,+avx2,+fma"; \
    fi \
    && cargo install --locked cargo-pgrx --version $(cargo metadata --format-version 1 | jq -r '.packages[] | select(.name == "pgrx") | .version') \
    && cargo pgrx init "--pg${POSTGRES_VERSION}=/usr/local/bin/pg_config" \
    && cargo pgrx package --pg-config "/usr/local/bin/pg_config"

FROM postgres:${POSTGRES_VERSION}-alpine AS postgres_rebase

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=get_info /tmp/BUILDTMP/DOCKERIMAGEBUILDER/patch/postgres/bootstrap.sh /docker-entrypoint-initdb.d/10_bootstrap_custom_patch.sh

COPY --from=build_c_plugin /tmp/BUILDTMP/pg_cron/*.so /usr/local/lib/postgresql/
COPY --from=build_c_plugin /tmp/BUILDTMP/pg_cron/*.control /usr/local/share/postgresql/extension/
COPY --from=build_c_plugin /tmp/BUILDTMP/pg_cron/*.sql /usr/local/share/postgresql/extension/

COPY --from=build_c_plugin /tmp/BUILDTMP/pg_ivm/*.so /usr/local/lib/postgresql/
COPY --from=build_c_plugin /tmp/BUILDTMP/pg_ivm/*.control /usr/local/share/postgresql/extension/
COPY --from=build_c_plugin /tmp/BUILDTMP/pg_ivm/*.sql /usr/local/share/postgresql/extension/

COPY --from=build_c_plugin /tmp/BUILDTMP/pgvector/*.so /usr/local/lib/postgresql/
COPY --from=build_c_plugin /tmp/BUILDTMP/pgvector/*.control /usr/local/share/postgresql/extension/
COPY --from=build_c_plugin /tmp/BUILDTMP/pgvector/sql/*.sql /usr/local/share/postgresql/extension/

COPY --from=build_rust_plugin /tmp/BUILDTMP/paradedb/target/release/pg_search-pg*/usr/local/lib/postgresql/* /usr/local/lib/postgresql/
COPY --from=build_rust_plugin /tmp/BUILDTMP/paradedb/target/release/pg_search-pg*/usr/local/share/postgresql/extension/* /usr/local/share/postgresql/extension/

COPY --from=build_rust_plugin /tmp/BUILDTMP/pgvectorscale/target/release/vectorscale-pg*/usr/local/lib/postgresql/* /usr/local/lib/postgresql/
COPY --from=build_rust_plugin /tmp/BUILDTMP/pgvectorscale/target/release/vectorscale-pg*/usr/local/share/postgresql/extension/* /usr/local/share/postgresql/extension/

RUN \
    sed -i "s/^#shared_preload_libraries = ''/shared_preload_libraries = 'pg_search,pg_cron'/" "/usr/local/share/postgresql/postgresql.conf.sample" \
    && echo "cron.database_name = 'postgres'" >> "/usr/local/share/postgresql/postgresql.conf.sample"

FROM scratch

COPY --from=postgres_rebase / /

ENV \
    PGDATA="/var/lib/postgresql" \
    PGPORT="5432" POSTGRES_DB="postgres" \
    POSTGRES_USER="postgres" \
    POSTGRES_PASSWORD="postgres"

EXPOSE 5432/tcp

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["postgres"]
