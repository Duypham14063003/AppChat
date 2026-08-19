#!/bin/bash

# Script để chạy tests với test database
# Tự động load .env.test và chạy tests

set -e

echo "🧪 Running tests with test database..."
echo ""

# Load test environment
if [ -f .env.test ]; then
  export $(cat .env.test | grep -v '^#' | xargs)
  echo "✅ Loaded .env.test"
else
  echo "❌ .env.test not found!"
  exit 1
fi

# Check if test database is running
if ! docker ps | grep -q "19t-postgres-test"; then
  echo "⚠️  Test database is not running. Starting it now..."
  ./scripts/test-db.sh start
  sleep 3
fi

echo ""
echo "🏃 Running tests..."
echo ""

# Run tests with the loaded environment
npm run test:e2e "$@"
