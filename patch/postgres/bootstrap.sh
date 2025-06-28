#!/bin/bash

# Perform all actions as $POSTGRES_USER
export PGUSER="$POSTGRES_USER"

# Exit on subcommand errors
set -Eeuo pipefail

# Creating extensions in template1 ensures that they are available in all new databases.
for DB in template1 "$POSTGRES_DB"; do
  echo "Loading extensions into $DB"
  psql -d "$DB" <<-'EOSQL'
    # https://github.com/paradedb/paradedb
    CREATE EXTENSION IF NOT EXISTS pg_search;
    # https://github.com/pgvector/pgvector
    CREATE EXTENSION IF NOT EXISTS vector;
EOSQL
done

# Add the `paradedb` schema to both template1 and $POSTGRES_DB
for DB in template1 "$POSTGRES_DB"; do
  echo "Adding 'paradedb' search_path to $DB"
  psql -d "$DB" -c "ALTER DATABASE \"$DB\" SET search_path TO public,paradedb;"
done

echo "PostgreSQL bootstrap completed!"
