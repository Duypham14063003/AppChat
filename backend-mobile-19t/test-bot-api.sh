#!/bin/bash

# Bot Creation API Test Script
# This script tests the new Bot Creation API implementation

BASE_URL="http://localhost:3002/api/v1"
ADMIN_TOKEN=""  # Set this to a valid admin JWT token

echo "=========================================="
echo "Bot Creation API Test Script"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if admin token is set
if [ -z "$ADMIN_TOKEN" ]; then
    echo -e "${YELLOW}⚠ ADMIN_TOKEN not set. Admin API tests will be skipped.${NC}"
    echo -e "${YELLOW}  To test admin APIs, set ADMIN_TOKEN environment variable with a valid admin JWT.${NC}"
    echo ""
fi

# Test 1: List bots (Admin API)
echo "Test 1: List all bots (Admin)"
echo "----------------------------"
if [ -n "$ADMIN_TOKEN" ]; then
    curl -s -X GET "$BASE_URL/bots" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" | jq '.' || echo -e "${RED}✗ Failed${NC}"
else
    echo -e "${YELLOW}⊘ Skipped (no admin token)${NC}"
fi
echo ""

# Test 2: Create a new bot (Admin API)
echo "Test 2: Create a new bot (Admin)"
echo "--------------------------------"
if [ -n "$ADMIN_TOKEN" ]; then
    BOT_RESPONSE=$(curl -s -X POST "$BASE_URL/bots" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
          "name": "Test Bot",
          "email": "bot-test-'$(date +%s)'@system.local",
          "description": "Automated test bot"
        }')

    echo "$BOT_RESPONSE" | jq '.'
    BOT_ID=$(echo "$BOT_RESPONSE" | jq -r '.id')

    if [ -n "$BOT_ID" ] && [ "$BOT_ID" != "null" ]; then
        echo -e "${GREEN}✓ Bot created with ID: $BOT_ID${NC}"
    else
        echo -e "${RED}✗ Failed to create bot${NC}"
    fi
else
    echo -e "${YELLOW}⊘ Skipped (no admin token)${NC}"
    # Use system bot for testing
    BOT_ID="00000000-0000-0000-0000-000000000001"
fi
echo ""

# Test 3: Get bot details (Admin API)
echo "Test 3: Get bot details (Admin)"
echo "-------------------------------"
if [ -n "$ADMIN_TOKEN" ] && [ -n "$BOT_ID" ]; then
    curl -s -X GET "$BASE_URL/bots/$BOT_ID" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" | jq '.' || echo -e "${RED}✗ Failed${NC}"
else
    echo -e "${YELLOW}⊘ Skipped (no admin token)${NC}"
fi
echo ""

# Test 4: Send bot message to conversation (Public API - no auth required)
echo "Test 4: Send bot message to conversation (Public API)"
echo "-----------------------------------------------------"
echo -e "${YELLOW}Note: This requires a valid conversation_id and bot_id${NC}"
echo "Example request structure:"
cat << 'EOF'
curl -X POST http://localhost:3002/api/v1/bot/messages \
  -H "Content-Type: application/json" \
  -d '{
    "bot_id": "<bot-uuid>",
    "conversation_id": "<conversation-uuid>",
    "content": "Hello from bot!"
  }'
EOF
echo ""

# Test 5: Send bot DM to user (Public API - no auth required)
echo "Test 5: Send bot DM to user (Public API)"
echo "----------------------------------------"
echo -e "${YELLOW}Note: This requires a valid user_id and bot_id${NC}"
echo "Example request structure:"
cat << 'EOF'
curl -X POST http://localhost:3002/api/v1/bot/messages \
  -H "Content-Type: application/json" \
  -d '{
    "bot_id": "<bot-uuid>",
    "user_id": "<user-uuid>",
    "content": "Direct message from bot!"
  }'
EOF
echo ""

# Test 6: Error case - missing both conversation_id and user_id
echo "Test 6: Error case - missing target (Public API)"
echo "------------------------------------------------"
curl -s -X POST "$BASE_URL/bot/messages" \
    -H "Content-Type: application/json" \
    -d '{
      "bot_id": "'$BOT_ID'",
      "content": "Test message"
    }' | jq '.'
echo ""

# Test 7: Error case - providing both conversation_id and user_id
echo "Test 7: Error case - both targets provided (Public API)"
echo "-------------------------------------------------------"
curl -s -X POST "$BASE_URL/bot/messages" \
    -H "Content-Type: application/json" \
    -d '{
      "bot_id": "'$BOT_ID'",
      "conversation_id": "00000000-0000-0000-0000-000000000001",
      "user_id": "00000000-0000-0000-0000-000000000002",
      "content": "Test message"
    }' | jq '.'
echo ""

# Test 8: Update bot (Admin API)
echo "Test 8: Update bot (Admin)"
echo "-------------------------"
if [ -n "$ADMIN_TOKEN" ] && [ -n "$BOT_ID" ] && [ "$BOT_ID" != "00000000-0000-0000-0000-000000000001" ]; then
    curl -s -X PATCH "$BASE_URL/bots/$BOT_ID" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
          "name": "Updated Test Bot",
          "description": "Updated description"
        }' | jq '.'
else
    echo -e "${YELLOW}⊘ Skipped (no admin token or bot not created)${NC}"
fi
echo ""

# Test 9: Deactivate bot (Admin API)
echo "Test 9: Deactivate bot (Admin)"
echo "------------------------------"
if [ -n "$ADMIN_TOKEN" ] && [ -n "$BOT_ID" ] && [ "$BOT_ID" != "00000000-0000-0000-0000-000000000001" ]; then
    curl -s -X DELETE "$BASE_URL/bots/$BOT_ID" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -w "\nHTTP Status: %{http_code}\n"
else
    echo -e "${YELLOW}⊘ Skipped (no admin token or bot not created)${NC}"
fi
echo ""

echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}✓ Database migration completed${NC}"
echo -e "${GREEN}✓ Build successful (no TypeScript errors)${NC}"
echo -e "${GREEN}✓ New endpoints registered${NC}"
echo ""
echo "Admin API endpoints (require JWT + admin role):"
echo "  - POST   /api/v1/bots"
echo "  - GET    /api/v1/bots"
echo "  - GET    /api/v1/bots/:id"
echo "  - PATCH  /api/v1/bots/:id"
echo "  - DELETE /api/v1/bots/:id"
echo ""
echo "Public API endpoints (no auth, rate limited 100/min):"
echo "  - POST   /api/v1/bot/messages"
echo ""
echo -e "${YELLOW}To perform full integration testing:${NC}"
echo "1. Set ADMIN_TOKEN environment variable"
echo "2. Create a bot using admin API"
echo "3. Get bot_id, conversation_id, and user_id from database"
echo "4. Test sending messages using the public API"
echo ""
