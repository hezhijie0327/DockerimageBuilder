#!/bin/bash

# Exit on subcommand errors
set -Eeuo pipefail

# Perform all actions as $POSTGRES_USER
export PGUSER="$POSTGRES_USER"

# Update extensions extensions into template1, paradedb, and $POSTGRES_DB
for DB in template1 paradedb "$POSTGRES_DB"; do
  echo "Upgrading extensions in $DB"
  psql -d "$DB" <<-'EOSQL'
    CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
    ALTER EXTENSION fuzzystrmatch UPDATE;

    CREATE EXTENSION IF NOT EXISTS pg_ivm;
    ALTER EXTENSION pg_ivm UPDATE;

    CREATE EXTENSION IF NOT EXISTS pg_search;
    ALTER EXTENSION pg_search UPDATE;

    CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
    ALTER EXTENSION pg_stat_statements UPDATE;

    CREATE EXTENSION IF NOT EXISTS vector;
    ALTER EXTENSION vector UPDATE;

    CREATE EXTENSION IF NOT EXISTS vectorscale CASCADE;
    ALTER EXTENSION vectorscale UPDATE;
EOSQL
done

echo "PostgreSQL extension upgrade completed!"
