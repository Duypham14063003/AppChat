## Why

Text messaging, media sharing (image, album, video, voice), and link preview are all working. Users frequently want to share existing messages from one conversation to another — forwarding an important announcement to a team group, sharing a funny message with a friend, or relaying instructions across channels. Currently there is no way to do this; users must manually copy text or re-send media, losing context about the original sender.

This implements CHAT-FR-011 (Forward Message). It follows Telegram's UX pattern: long-press to select, multi-select mode for batch forwarding, chat picker for choosing destination conversations (multi-select), server-side message copy with "Forwarded from" attribution, and optional privacy toggle to hide the original sender.

## What Changes

Backend (NestJS):
- Add new `forward_message` WebSocket event handler in ChatGateway
- Add `forwardMessages()` method in ChatService — server-side copy of original message content/type/metadata into new messages with `forwarded_from_id` and `forwarded_from_sender` columns populated
- Validate sender membership in both source and target conversations
- Block forwarding of deleted messages (`deleted_at IS NOT NULL`)
- Preserve original message order (sorted by `created_at`) when forwarding multiple messages
- Support forwarding to multiple target conversations in a single request

Frontend (Flutter):
- Add long-press context menu on messages with "Chuyển tiếp" (Forward) action
- Add multi-select mode: selection AppBar with count + forward button, tap-to-toggle selection, checkboxes on messages
- Create `ForwardChatPickerScreen` — conversation list with multi-select, search, selected chips, send button
- Add "Ẩn nguồn" (Hide source) toggle in chat picker for forwarding without attribution
- Update `MessageBubble` to display "Chuyển tiếp từ [Name]" header for forwarded messages
- Add `forwardMessages()` method in chat providers
- Update Drift local DB schema to include `forwardedFromId` and `forwardedFromSender` columns on `LocalMessages`

## Capabilities

### New Capabilities
- `forward-message-backend`: Server-side forward message handling — WS event, message copy logic, validation, multi-target support
- `forward-message-selection`: Multi-select mode UI in ChatScreen — long-press trigger, selection AppBar, tap-to-toggle, checkboxes
- `forward-chat-picker`: Chat picker screen for selecting destination conversations — multi-select, search, privacy toggle
- `forward-message-display`: Forwarded message rendering in MessageBubble — "Forwarded from" header, anonymous forward support

### Modified Capabilities
- `chat-messaging`: Extend sendMessage INSERT query to include `forwarded_from_id` and `forwarded_from_sender` columns
- `flutter-chat-ui`: Update MessageBubble to render forward header; update ChatScreen for selection mode

## Impact

- **Database**: No schema changes needed — `forwarded_from_id` and `forwarded_from_sender` columns already exist in messages table (migration 1710600000003). Backend `sendMessage()` INSERT query needs to include these columns.
- **WebSocket**: New `forward_message` event type in ChatGateway event switch
- **Flutter local DB**: Drift migration (schema version 3 → 4) to add `forwardedFromId` and `forwardedFromSender` columns to `LocalMessages` table. Requires `build_runner` codegen after model change.
- **API endpoints**: No new REST endpoints — forwarding uses WebSocket only
- **Packages**: No new dependencies needed
- **Performance**: Forwarding N messages to M conversations = N×M INSERT operations. For reasonable usage (<50 employees), this is fine. Server processes sequentially per request.

