#!/bin/bash

# Script tạo và quản lý test schema
# Sử dụng: ./scripts/test-schema.sh [create|drop|reset]

set -e

# Load test environment
export $(cat .env.test | grep -v '^#' | xargs)

SCHEMA_NAME="${DB_SCHEMA:-test_schema}"

case "$1" in
  create)
    echo "🔧 Creating test schema: $SCHEMA_NAME..."
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME <<EOF
CREATE SCHEMA IF NOT EXISTS $SCHEMA_NAME;
GRANT ALL ON SCHEMA $SCHEMA_NAME TO $DB_USER;
ALTER DATABASE $DB_NAME SET search_path TO $SCHEMA_NAME,public;
EOF
    echo "✅ Test schema created!"
    ;;

  drop)
    echo "🗑️  Dropping test schema: $SCHEMA_NAME..."
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME <<EOF
DROP SCHEMA IF EXISTS $SCHEMA_NAME CASCADE;
EOF
    echo "✅ Test schema dropped!"
    ;;

  reset)
    echo "🔄 Resetting test schema..."
    ./scripts/test-schema.sh drop
    ./scripts/test-schema.sh create
    echo ""
    echo "📋 Running migrations..."
    export $(cat .env.test | grep -v '^#' | xargs)
    npm run migration:run
    echo ""
    echo "✅ Test schema reset complete!"
    ;;

  *)
    echo "Usage: $0 {create|drop|reset}"
    echo ""
    echo "Commands:"
    echo "  create - Create test schema"
    echo "  drop   - Drop test schema and all data"
    echo "  reset  - Drop, recreate and run migrations"
    exit 1
    ;;
esac
