## api-reply-data

Enhance getMessages API to eager-load reply_to message data (sender name, content, type) for messages with reply_to_id. Include reply snapshot in WebSocket new_message events.

### Requirements

1. **ChatService.getMessages() — batch load reply data**
   - After fetching messages, collect all non-null `reply_to_id` values
   - If any exist: batch query `SELECT m.id, m.sender_id, m.content, m.type, u.name as sender_name FROM messages m LEFT JOIN users u ON u.id = m.sender_id WHERE m.id IN (:...ids)`
   - Map results into a lookup: `Map<string, ReplyData>`
   - Attach `reply_to` object to each message in the response:
     ```json
     {
       "id": "uuid",
       "conv_id": "uuid",
       "sender_id": "uuid",
       "content": "hello",
       "reply_to_id": "uuid",
       "reply_to": {
         "id": "uuid",
         "sender_id": "uuid",
         "sender_name": "Nguyen Van A",
         "content": "original message text",
         "type": "text"
       }
     }
     ```
   - If the replied-to message is deleted or not found: `reply_to` is `null` (reply_to_id still present)
   - For image/album replies: include `type` so client can show "📷 Ảnh" instead of null content

2. **ChatService.sendMessage() — attach reply snapshot to broadcast**
   - When a message has `reply_to_id`:
     - After saving, look up the replied-to message: `SELECT m.id, m.sender_id, m.content, m.type, u.name as sender_name FROM messages m LEFT JOIN users u ON u.id = m.sender_id WHERE m.id = :replyToId`
     - Attach as `reply_to` in the Redis pub/sub broadcast payload
   - This ensures receiving clients get the reply snapshot in the `new_message` WS event without extra lookups

3. **Flutter: Store reply snapshot in local message metadata**
   - In `ChatNotifier._onNewMessage()`: if WS data contains `reply_to` object, merge it into the message's metadata JSON before saving to SQLite
   - In `ChatNotifier._refreshFromApi()`: if API response contains `reply_to` object, merge it into metadata before saving
   - Metadata structure: `{ ...existing_metadata, "reply_to": { "id": "...", "sender_id": "...", "sender_name": "...", "content": "...", "type": "..." } }`
   - This ensures reply data is persisted locally and available offline

4. **Flutter: ChatNotifier.sendMessage() — include reply_to_id**
   - Add optional `String? replyToId` parameter to `sendMessage()`
   - Include in WS payload: `'reply_to_id': replyToId`
   - Include in local message insert: `replyToId: Value(replyToId)`
   - When sending with reply: also store reply snapshot in metadata (from `_replyingTo` message data)
   - Same for `sendImageMessage()` — add `replyToId` parameter

### Integration Points

- `ChatService` (API) — `getMessages()` batch loads reply data, `sendMessage()` attaches snapshot to broadcast
- `ChatNotifier` (Flutter) — `sendMessage()` / `sendImageMessage()` accept replyToId, store reply snapshot
- `ChatNotifier._onNewMessage()` — merges reply_to into metadata on save
- `ChatNotifier._refreshFromApi()` — merges reply_to into metadata on save

### Acceptance Criteria

- `GET /conversations/:id/messages` returns `reply_to` object for messages with `reply_to_id`
- `reply_to` contains: id, sender_id, sender_name, content, type
- Deleted original message → `reply_to` is null, `reply_to_id` still present
- WS `new_message` event includes `reply_to` snapshot when applicable
- Flutter saves reply snapshot in local metadata for offline access
- `sendMessage("text", replyToId: "uuid")` sends reply_to_id via WS
- Sent message appears locally with reply data in metadata
