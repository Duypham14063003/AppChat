#!/bin/bash

# Script khởi động test database
# Sử dụng: ./scripts/test-db.sh [start|stop|reset|logs]

set -e

COMPOSE_FILE="docker-compose.test.yml"

case "$1" in
  start)
    echo "🚀 Starting test database..."
    docker compose -f $COMPOSE_FILE up -d
    echo "⏳ Waiting for databases to be ready..."
    sleep 5
    docker compose -f $COMPOSE_FILE ps
    echo "✅ Test database is ready!"
    echo ""
    echo "📊 Connection info:"
    echo "  PostgreSQL: postgresql://app_19t_test:test_password@localhost:5434/app_19t_test"
    echo "  Redis: redis://localhost:6380"
    ;;

  stop)
    echo "🛑 Stopping test database..."
    docker compose -f $COMPOSE_FILE down
    echo "✅ Test database stopped"
    ;;

  reset)
    echo "🔄 Resetting test database (removing all data)..."
    docker compose -f $COMPOSE_FILE down -v
    docker compose -f $COMPOSE_FILE up -d
    echo "⏳ Waiting for databases to be ready..."
    sleep 5
    echo "✅ Test database reset complete!"
    ;;

  logs)
    docker compose -f $COMPOSE_FILE logs -f
    ;;

  *)
    echo "Usage: $0 {start|stop|reset|logs}"
    echo ""
    echo "Commands:"
    echo "  start  - Start test database containers"
    echo "  stop   - Stop test database containers"
    echo "  reset  - Stop containers and remove all data"
    echo "  logs   - Show container logs"
    exit 1
    ;;
esac
