# Bot API Quick Reference

## 🚀 Quick Start

### 1. Admin: Create a Bot
```bash
curl -X POST http://localhost:3002/api/v1/bots \
  -H "Authorization: Bearer <ADMIN_JWT>" \
  -H "Content-Type: application/json" \
  -d '{"name":"My Bot","email":"bot-mybot@system.local"}'
```

### 2. Public: Send Message
```bash
# To conversation
curl -X POST http://localhost:3002/api/v1/bot/messages \
  -H "Content-Type: application/json" \
  -d '{"bot_id":"<BOT_ID>","conversation_id":"<CONV_ID>","content":"Hello!"}'

# To user (DM)
curl -X POST http://localhost:3002/api/v1/bot/messages \
  -H "Content-Type: application/json" \
  -d '{"bot_id":"<BOT_ID>","user_id":"<USER_ID>","content":"Hi there!"}'
```

## 📋 Endpoints Summary

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | /api/v1/bots | Admin | Create bot |
| GET | /api/v1/bots | Admin | List bots |
| GET | /api/v1/bots/:id | Admin | Get bot |
| PATCH | /api/v1/bots/:id | Admin | Update bot |
| DELETE | /api/v1/bots/:id | Admin | Deactivate bot |
| POST | /api/v1/bot/messages | Public | Send message (100/min) |

## 🔑 Key Points

- ✅ Public API: No auth required for sending messages
- ⚡ Rate limit: 100 requests/minute
- 🤖 Email pattern: `bot-*@system.local`
- 🔒 System bot ID: `00000000-0000-0000-0000-000000000001` (protected)
- 💬 DM support: Auto-creates conversation
- 🎯 Bot IDs: Use negative `odoo_uid` (-1, -2, -3...)

## 📝 Request Examples

### Create Bot
```json
{
  "name": "Notification Bot",
  "email": "bot-notifications@system.local",
  "description": "Sends system notifications",
  "avatar_url": "https://example.com/avatar.png"
}
```

### Send Message
```json
{
  "bot_id": "uuid",
  "conversation_id": "uuid",  // OR user_id
  "content": "Your message",
  "external_message_id": "uuid",  // Optional for idempotency
  "metadata": {}  // Optional
}
```

## ⚠️ Error Codes

- **400**: Missing/invalid parameters, system bot modification
- **403**: Inactive bot
- **404**: Bot/user not found
- **429**: Rate limit exceeded

## 🧪 Testing

```bash
# Run test script
./test-bot-api.sh

# With admin token
ADMIN_TOKEN="your-jwt" ./test-bot-api.sh
```

## 📚 Full Documentation

See `BOT_API_DOCUMENTATION.md` for complete API reference.
