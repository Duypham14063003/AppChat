#!/bin/bash

# Nineteen Tech API — Deployment Script (PM2 + TypeORM)
# Repo: https://github.com/paulnguyendev/backend-mobile-19t.git
set -e

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Environment checks ---
if [ -z "$FLASHPANEL_SITE_ROOT" ]; then
    print_error "FLASHPANEL_SITE_ROOT environment variable is not set"
    exit 1
fi

if [ -z "$FLASHPANEL_CODE_BRANCH" ]; then
    FLASHPANEL_CODE_BRANCH="main"
    print_warning "FLASHPANEL_CODE_BRANCH not set, defaulting to 'main'"
fi

APP_NAME="19t-api"
PORT="${PORT:-3002}"

print_status "Starting deployment for $APP_NAME"
print_status "Site Root: $FLASHPANEL_SITE_ROOT"
print_status "Branch: $FLASHPANEL_CODE_BRANCH"

# --- Navigate to project directory ---
cd "$FLASHPANEL_SITE_ROOT" || {
    print_error "Cannot cd into $FLASHPANEL_SITE_ROOT"
    exit 1
}

# --- Git pull latest code ---
if [ ! -d ".git" ]; then
    print_error "Not a git repository"
    exit 1
fi

print_status "Fetching latest code..."
git stash push -m "Auto-stash before deploy $(date)" || true
git pull origin "$FLASHPANEL_CODE_BRANCH"

# --- Check .env file ---
if [ ! -f ".env" ]; then
    print_warning ".env file not found! Copying from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_warning "Please update .env with production values!"
    else
        print_error ".env.example not found!"
        exit 1
    fi
fi

# --- Install dependencies (full, need devDeps for build + migrations) ---
print_status "Installing dependencies..."
npm ci || npm install

# --- Build NestJS app ---
print_status "Building NestJS application..."
npm run build

# --- Run TypeORM migrations (needs tsx from devDeps) ---
print_status "Running database migrations..."
npm run migration:run

# --- Prune devDependencies ---
print_status "Pruning devDependencies..."
npm prune --omit=dev

# --- Create uploads directory if missing ---
mkdir -p uploads/chat

# --- Start/Restart PM2 process ---
print_status "Restarting PM2 process..."
if pm2 describe "$APP_NAME" > /dev/null 2>&1; then
    pm2 restart "$APP_NAME" --update-env
else
    pm2 start dist/src/main.js \
        --name "$APP_NAME" \
        --max-memory-restart 512M \
        --env production
fi

# --- Save PM2 process list ---
pm2 save
pm2 startup | tail -n 1 | bash || true

print_status "Deployment completed successfully!"
echo ""
echo "=== Deployment Summary ==="
echo "App Name:        $APP_NAME"
echo "Site Root:       $FLASHPANEL_SITE_ROOT"
echo "Branch:          $FLASHPANEL_CODE_BRANCH"
echo "Port:            $PORT"
echo "API:             http://localhost:$PORT/api/v1"
echo "Swagger Docs:    http://localhost:$PORT/api/docs"
echo "Deployment Time: $(date)"
echo "==========================="
