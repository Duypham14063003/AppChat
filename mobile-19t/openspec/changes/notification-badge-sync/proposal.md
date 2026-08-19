## Why

The app icon badge for chat notifications is currently unreliable: pushes can keep the badge stuck at `1`, and opening or reading messages does not reliably bring the badge back to the real unread total. This breaks a basic notification contract and makes badge state feel disconnected from actual conversation unread state.

## What Changes

- Replace the hardcoded chat push badge behavior with a real unread-total badge count sourced from the server.
- Define how mobile clients receive, apply, and clear badge counts so the icon badge stays aligned with actual unread chat state.
- Keep this change focused on badge correctness for chat notifications without expanding into notification center, preferences, or broader notification UX.

## Capabilities

### New Capabilities
- `notification-badge-sync`: End-to-end unread badge synchronization between chat unread state, push payloads, and the mobile app icon badge.

### Modified Capabilities
<!-- No existing capability requirements are being modified. -->

## Impact

- **Backend push payload generation**: `apps/api/src/modules/notification/services/firebase.service.ts`, `apps/api/src/modules/notification/services/push-notification.processor.ts`
- **Chat unread source-of-truth logic**: chat unread-count query paths in `apps/api/src/modules/chat/services/chat.service.ts` and related repositories
- **Mobile notification handling**: `apps/mobile/lib/core/notifications/*.dart`
- **Mobile chat unread lifecycle**: chat providers / local unread reset flow in `apps/mobile/lib/features/chat/**` and `apps/mobile/lib/core/database/chat_dao.dart`
- **Verification**: backend/mobile tests for badge payload and badge clear/sync behavior
