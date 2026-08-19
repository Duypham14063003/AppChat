## Context

The mobile chat stack uses optimistic local inserts with `status: pending` and relies on WebSocket `message_ack` to transition messages to `sent`. A dedicated `OfflineQueueService` already exists to flush pending messages on reconnect and on a periodic timer, and to process pending media uploads through `PendingUploads`.

However, this queue service is currently only declared as a Riverpod provider and is never instantiated in the app lifecycle. Because Riverpod providers are lazy, reconnect listeners and periodic retry logic are effectively inactive. This creates the observed bug: after connectivity returns, pending messages can remain stuck in pending state.

Enabling queue bootstrap must be paired with resend-path hardening. Text retry should be deterministic when `sendMessage` fails immediately, and reconnect replay should not accidentally send media records through the text resend path, because media payload finalization belongs to the upload queue flow.

## Goals / Non-Goals

**Goals:**
- Ensure pending text messages are retried automatically when WebSocket reconnects.
- Ensure retry logic is active in authenticated sessions without requiring chat screen-specific initialization.
- Preserve optimistic message behavior: pending until ACK, then sent.
- Keep media retry semantics correct by routing media through the pending upload pipeline only.
- Keep retry bounded and visible via existing pending/failed states.

**Non-Goals:**
- Redesign chat bubble UI for pending/failed states.
- Change backend WebSocket ACK payload shape or message persistence contracts.
- Introduce guaranteed delivery across uninstall/device reset scenarios.
- Replace existing upload queue architecture for image/album/voice/video messages.

## Decisions

### D1: Bootstrap offline queue service at authenticated app scope

**Decision:** Instantiate `offlineQueueServiceProvider` during authenticated app lifecycle, and stop queue processing when auth becomes unauthenticated.

**Why:** Queue processing must not depend on opening a specific chat screen. App-scope bootstrap ensures reconnect listeners and periodic retries are always active for a logged-in user.

**Alternatives considered:**
- Instantiate only inside chat conversation providers. Rejected because pending messages may exist while user is outside an open conversation.
- Trigger manual resend only from UI retry buttons. Rejected because it fails the requirement for automatic resend after reconnect.

### D2: Treat immediate WebSocket send failure as retryable pending state

**Decision:** Keep outgoing text messages in `pending` when `sendMessage` returns `false`, and rely on queue replay instead of dropping or prematurely failing.

**Why:** Connection state can be transient during reconnect windows. Preserving pending state avoids message loss and keeps retry behavior deterministic.

**Alternatives considered:**
- Mark message failed immediately when `sendMessage` returns `false`. Rejected because many failures are transient and recoverable after reconnect.
- Retry inline in a tight loop from send action. Rejected due to duplication with centralized queue retry/backoff logic.

### D3: Separate text resend replay from media upload replay

**Decision:** Limit queue replay to retry-safe pending messages (text-oriented payloads) and exclude media message types that require upload finalization from `PendingUploads`.

**Why:** Media optimistic metadata can contain local file paths; replaying it as final `send_message` payload can create invalid server-side content. The existing upload queue is the authoritative media retry path.

**Alternatives considered:**
- Replay all pending message types through one path. Rejected because media and text have different transport requirements.
- Move all retry flows to REST endpoints. Rejected as out of scope for this reliability fix.

### D4: Keep status transitions idempotent and message-id keyed

**Decision:** Status updates continue to use message ID as the single key for ACK and retry transitions across provider listeners and queue service handlers.

**Why:** Message ID is already generated client-side and used by backend ACK; this keeps transitions consistent under reconnect races.

**Alternatives considered:**
- Introduce a separate retry entity for text sends. Rejected because local message table already tracks `status` and `retry_count`.

## Risks / Trade-offs

- [Risk] App-scope queue bootstrap could register duplicate listeners if lifecycle wiring is incorrect. → Mitigation: ensure a single initialized provider instance per authenticated app session.
- [Risk] Retry filtering could skip a legitimate retryable message type. → Mitigation: define explicit allowed/disallowed type handling and add tests for text vs media.
- [Risk] More automatic retries can increase background traffic during unstable network periods. → Mitigation: keep bounded retry count and existing backoff behavior.
- [Risk] Multiple status writers (chat notifier + queue service) may race on the same message. → Mitigation: keep updates idempotent (`pending` → `sent`/`failed`) and keyed by message ID.

## Migration Plan

1. Wire offline queue provider bootstrap into authenticated app lifecycle.
2. Harden text send flow for immediate WebSocket send failure and queue-based retry.
3. Update queue flush logic to prevent media payload replay through text path.
4. Verify pending → sent transitions on reconnect ACK and pending → failed transitions after bounded retries.
5. Add/adjust tests and manual scenarios for disconnect/reconnect behavior.

**Rollback:** Remove app-scope queue bootstrap and revert to manual retry-only behavior if regressions appear, while preserving existing chat send path. This would restore current limitations but contain rollout risk.

## Open Questions

None. The bug scope is clear: pending messages must auto-resend after reconnect, and media replay must remain upload-queue-safe.
