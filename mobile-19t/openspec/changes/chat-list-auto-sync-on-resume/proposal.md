## Why

The chat list can remain stale after the app resumes or is reopened, even though new messages already exist on the server. This creates a confusing split where users see the new message only after opening the conversation, instead of having the list update automatically.

## What Changes

- Make the chat list refresh automatically when the app returns to the foreground so new conversation previews appear without manual reload.
- Tighten chat-list synchronization when `new_message` websocket previews are not sufficient to fully reflect the latest server state.
- Add verification coverage for automatic chat-list refresh behavior tied to app resume and incoming message updates.

## Capabilities

### New Capabilities
- `chat-list-auto-sync`: Automatic chat-list synchronization on app resume and inbound chat activity so conversation previews stay current without manual refresh.

### Modified Capabilities
<!-- No existing capability requirements are being modified. -->

## Impact

- **Flutter app lifecycle handling**: `apps/mobile/lib/app.dart`
- **Chat list synchronization logic**: `apps/mobile/lib/features/chat/providers/chat_providers.dart`
- **Chat list UI freshness**: `apps/mobile/lib/features/chat/screens/chat_list_screen.dart`
- **Verification**: mobile tests for resume-driven and inbound-message-driven chat list refresh behavior
