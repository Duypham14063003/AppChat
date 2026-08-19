## Why

Chat message bubbles currently show only `HH:mm` for every message, even when the message was sent on a previous day. That makes older conversation history hard to read because users can no longer tell which date an individual message belongs to without relying on nearby separators.

## What Changes

- Update bubble-level timestamp formatting so old messages include date information instead of showing time only.
- Preserve compact time-only formatting for messages sent on the current day.
- Define a consistent chat timestamp format for past-day and past-year messages.
- Add verification coverage for same-day, prior-day, and prior-year timestamp presentation.

## Capabilities

### New Capabilities
- `chat-message-timestamp-format-ui`: Context-aware timestamp formatting for chat message bubbles based on the message send date.

### Modified Capabilities
<!-- No existing capability requirements are being modified. -->

## Impact

- **Flutter chat UI**: `apps/mobile/lib/features/chat/widgets/message_bubble.dart`
- **Chat message rendering**: `apps/mobile/lib/features/chat/widgets/message_item.dart`
- **Verification**: mobile tests for timestamp formatting behavior
