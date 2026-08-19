# Bot Creation API Documentation

## Overview

The Bot Creation API allows administrators to create and manage multiple bots that can send messages to conversations and users without being members of those conversations. This is ideal for webhook integrations, notification bots, and chatbot services from external systems.

## Key Features

- **Multiple Bots**: Create and manage multiple bot accounts
- **No Membership Required**: Bots can send messages without being conversation members
- **Direct Messages**: Bots can send DMs to users (auto-creates conversation)
- **Public External API**: No authentication required for sending messages (rate-limited)
- **Admin Management**: Full CRUD operations for bot management (admin-only)

## Architecture

### Database Schema

Bot functionality is implemented by extending the `users` table with bot-specific fields:

- `is_bot` (boolean, indexed): Identifies bot users
- `bot_description` (text): Bot description
- `bot_webhook_url` (varchar): Future webhook URL
- `bot_created_by` (uuid): Admin who created the bot

### Bot ID Strategy

- System bot: `odoo_uid = 0`
- Custom bots: `odoo_uid = -1, -2, -3, ...` (negative numbers)

## API Endpoints

### Admin APIs (Internal - Requires JWT + Admin Role)

#### 1. Create Bot

```http
POST /api/v1/bots
Authorization: Bearer <admin-jwt>
Content-Type: application/json

{
  "name": "Notification Bot",
  "email": "bot-notifications@system.local",
  "description": "Sends notifications from external systems",
  "avatar_url": "https://example.com/bot-avatar.png"
}
```

**Email Pattern**: Must match `bot-[a-z0-9-]+@system.local`

**Response**:
```json
{
  "id": "uuid",
  "odoo_uid": -1,
  "email": "bot-notifications@system.local",
  "name": "Notification Bot",
  "is_bot": true,
  "bot_description": "Sends notifications from external systems",
  "bot_created_by": "admin-user-id",
  "is_active": true,
  "created_at": "2024-05-26T10:30:00Z"
}
```

#### 2. List Bots

```http
GET /api/v1/bots?include_inactive=false
Authorization: Bearer <admin-jwt>
```

**Response**:
```json
{
  "bots": [
    {
      "id": "uuid",
      "name": "Notification Bot",
      "email": "bot-notifications@system.local",
      "is_active": true,
      ...
    }
  ]
}
```

#### 3. Get Bot Details

```http
GET /api/v1/bots/:id
Authorization: Bearer <admin-jwt>
```

#### 4. Update Bot

```http
PATCH /api/v1/bots/:id
Authorization: Bearer <admin-jwt>
Content-Type: application/json

{
  "name": "Updated Bot Name",
  "description": "Updated description",
  "avatar_url": "https://example.com/new-avatar.png"
}
```

**Note**: System bot (`00000000-0000-0000-0000-000000000001`) cannot be updated.

#### 5. Deactivate Bot

```http
DELETE /api/v1/bots/:id
Authorization: Bearer <admin-jwt>
```

**Response**: 204 No Content

**Note**: System bot cannot be deactivated.

---

### External API (Public - No Authentication)

#### Send Bot Message

```http
POST /api/v1/bot/messages
Content-Type: application/json

{
  "bot_id": "uuid",
  "conversation_id": "uuid",  // OR user_id (not both)
  "content": "Message text",
  "external_message_id": "uuid",  // Optional, for idempotency
  "metadata": {}  // Optional
}
```

**Rate Limit**: 100 requests per minute

**Send to Group Conversation**:
```json
{
  "bot_id": "12345678-1234-1234-1234-123456789012",
  "conversation_id": "87654321-4321-4321-4321-210987654321",
  "content": "Hello from bot!"
}
```

**Send Direct Message to User**:
```json
{
  "bot_id": "12345678-1234-1234-1234-123456789012",
  "user_id": "11111111-1111-1111-1111-111111111111",
  "content": "Direct message from bot!"
}
```

**Response**:
```json
{
  "success": true,
  "conversation_id": "uuid",
  "message_id": "uuid",
  "created_at": "2024-05-26T10:30:00Z",
  "sender": {
    "id": "bot-uuid",
    "email": "bot-notifications@system.local",
    "name": "Notification Bot"
  }
}
```

**Idempotency**: Use `external_message_id` to prevent duplicate messages. Sending the same `external_message_id` multiple times will return the same message.

## Error Responses

### 400 Bad Request

```json
{
  "statusCode": 400,
  "message": "Must provide either conversation_id or user_id",
  "error": "Bad Request"
}
```

**Common causes**:
- Missing both `conversation_id` and `user_id`
- Providing both `conversation_id` and `user_id`
- Invalid email pattern when creating bot
- Attempting to update/delete system bot

### 403 Forbidden

```json
{
  "statusCode": 403,
  "message": "Bot is not active",
  "error": "Forbidden"
}
```

**Cause**: Attempting to send message with deactivated bot.

### 404 Not Found

```json
{
  "statusCode": 404,
  "message": "Bot not found",
  "error": "Not Found"
}
```

**Causes**:
- Invalid `bot_id`
- `bot_id` is not a bot user
- Target user not found (for DMs)

### 429 Too Many Requests

```json
{
  "statusCode": 429,
  "message": "ThrottlerException: Too Many Requests"
}
```

**Cause**: Exceeded rate limit (100 requests per minute).

## Usage Examples

### Example 1: Webhook Integration

```javascript
// Webhook endpoint receives notification from external system
app.post('/webhook/notifications', async (req, res) => {
  const { message, userId } = req.body;

  // Send notification via bot
  await fetch('http://your-backend:3002/api/v1/bot/messages', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      bot_id: process.env.NOTIFICATION_BOT_ID,
      user_id: userId,
      content: message,
      metadata: { source: 'external-webhook' }
    })
  });

  res.json({ success: true });
});
```

### Example 2: Group Announcements

```javascript
// Send announcement to multiple groups
const groups = ['group-id-1', 'group-id-2', 'group-id-3'];

for (const groupId of groups) {
  await fetch('http://your-backend:3002/api/v1/bot/messages', {
    method: 'POST',
    headers: { 'Content-Type': application/json' },
    body: JSON.stringify({
      bot_id: process.env.ANNOUNCEMENT_BOT_ID,
      conversation_id: groupId,
      content: 'System maintenance scheduled for tonight at 10 PM'
    })
  });
}
```

### Example 3: Create Bot via Admin API

```bash
# Get admin JWT token (login as admin user)
ADMIN_TOKEN=$(curl -X POST http://localhost:3002/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@company.com","password":"password"}' \
  | jq -r '.access_token')

# Create new bot
BOT_RESPONSE=$(curl -X POST http://localhost:3002/api/v1/bots \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sales Bot",
    "email": "bot-sales@system.local",
    "description": "Sends sales notifications"
  }')

BOT_ID=$(echo $BOT_RESPONSE | jq -r '.id')
echo "Created bot with ID: $BOT_ID"
```

## Security Considerations

⚠️ **Important**: The external API (`POST /api/v1/bot/messages`) is a **public endpoint** with no authentication required. This means anyone with access to your backend URL can send messages as your bots.

**Security measures in place**:
- Rate limiting (100 requests/minute) to prevent abuse
- Bot must exist and be active
- Conversation/user must exist

**Recommendations**:
1. Keep bot IDs confidential
2. Monitor bot message logs for suspicious activity
3. Consider implementing IP whitelisting at the infrastructure level
4. Use audit logging to track all bot operations
5. Consider adding custom authentication layer if needed

## Backward Compatibility

- System bot (`00000000-0000-0000-0000-000000000001`) continues to work as before
- Migration automatically sets `is_bot = true` for system bot
- Existing bot message functionality remains unchanged

## Testing

Use the provided test script:

```bash
# Set admin token (optional)
export ADMIN_TOKEN="your-admin-jwt-token"

# Run tests
./test-bot-api.sh
```

## Migration

The migration `1716730000000-AddBotFieldsToUser.ts` adds:
- New columns to `users` table
- Index on `is_bot` for performance
- Foreign key constraint for `bot_created_by`
- Updates system bot to set `is_bot = true`

To run:
```bash
npm run migration:run
```

To revert:
```bash
npm run migration:revert
```

## Implementation Files

**Modified**:
- `src/modules/auth/entities/user.entity.ts` - Added bot fields
- `src/modules/bot/bot.service.ts` - Added bot CRUD and messaging logic
- `src/modules/bot/bot.controller.ts` - Updated to remove API key auth
- `src/modules/bot/dto/bot.dto.ts` - Added new DTOs
- `src/modules/chat/services/chat.service.ts` - Added bypass membership check
- `src/modules/bot/bot.module.ts` - Added new dependencies

**Created**:
- `src/migrations/1716730000000-AddBotFieldsToUser.ts` - Database migration
- `src/modules/bot/bots-admin.controller.ts` - Admin API controller
- `test-bot-api.sh` - Test script

## Future Enhancements

- [ ] Webhook support (`bot_webhook_url` field prepared)
- [ ] Bot analytics and message tracking
- [ ] Bot permissions and scoping
- [ ] Custom authentication for external API
- [ ] Bot command handlers
- [ ] Interactive bot responses
