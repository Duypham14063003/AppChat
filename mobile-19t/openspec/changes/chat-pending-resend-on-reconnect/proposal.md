## Why

Outgoing chat messages can become stuck in `pending` status after a network drop and reconnect. The mobile app already has an `OfflineQueueService` intended to flush pending messages on reconnect, but this service is never bootstrapped in the authenticated app lifecycle, so its reconnect listeners never run. As a result, users see a clock/pending state indefinitely unless they manually retry.

The current text-send path also does not explicitly handle an immediate WebSocket send failure (`sendMessage(...) == false`), which makes retry behavior less deterministic when connection state is unstable. In addition, once reconnect resend is re-enabled, replay logic must avoid sending media payloads through the text resend path because media messages rely on the pending upload pipeline.

## What Changes

- Initialize the mobile offline resend queue service for authenticated sessions so reconnect-triggered and periodic retry logic is actually active.
- Harden text message send behavior so immediate transport failures keep messages in a retryable pending state with predictable replay.
- Constrain reconnect resend behavior to retry-safe pending messages and keep image/album/voice/video retry in the existing pending upload flow.
- Ensure message status transitions remain coherent across retry attempts, ACK success, and max-retry failure.
- Add verification coverage for disconnect/reconnect resend behavior and media-queue safety.

## Capabilities

### New Capabilities
- `chat-pending-resend-on-reconnect`: Mobile chat retries pending outgoing messages automatically after reconnect and resolves them to sent/failed state without breaking media upload semantics.

### Modified Capabilities
<!-- No existing capability requirements are being modified. -->

## Impact

- **Mobile app lifecycle wiring**: authenticated session bootstrap for offline queue processing.
- **Chat retry pipeline**: `apps/mobile/lib/features/chat/data/offline_queue_service.dart`.
- **Chat send flow**: `apps/mobile/lib/features/chat/providers/chat_providers.dart`.
- **WebSocket-driven status handling**: pending/sent/failed transitions after reconnect and ACK.
- **Verification**: mobile tests and manual reconnect scenarios for text and media message reliability.
