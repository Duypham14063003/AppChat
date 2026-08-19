## Context

The mobile chat experience already supports long-press actions such as pinning, bookmarking, replying, copying, and forwarding. The chat stack also already supports `system` messages in the timeline, websocket fan-out for new chat events, and a backend reminder pattern through BullMQ in the HR module. What is missing is a message-linked reminder flow that lets a user turn a chat message into a scheduled reminder, see that reminder lifecycle reflected in the conversation, and notify either only themselves or all conversation members when the reminder time arrives.

This feature crosses the mobile chat UI, chat backend, realtime delivery, and push notification layers. It also introduces lifecycle rules that go beyond a single fire-and-forget action: reminders can be created, updated, cancelled, and triggered; multiple reminders can point to the same source message; and duplicates at the same time must be prevented within the relevant recipient scope.

## Goals / Non-Goals

**Goals:**
- Add a new long-press message action for creating a reminder from a normal chat message.
- Support two reminder audiences: `self` and `everyone`.
- Allow the reminder creator to update or cancel an existing reminder.
- Insert chat-visible system messages for reminder creation, update, cancellation, and firing.
- Schedule reminder delivery reliably and notify the correct recipients based on the chosen audience.
- Prevent duplicate reminders at the same scheduled time within the same reminder scope rules.

**Non-Goals:**
- Redesign the entire message context menu or chat system-message styling beyond what reminder-specific rendering requires.
- Introduce calendar sync, recurring reminders, or reminders not linked to a source chat message.
- Allow editing the source message binding of a reminder after creation.
- Change unrelated HR reminder or notification behavior outside reusable infrastructure.

## Decisions

### D1: Model reminders as a dedicated backend entity instead of overloading chat messages

**Decision:** Store reminder scheduling and ownership data in a dedicated reminder table/entity, while using system chat messages only for timeline visibility.

**Why:** Reminder state includes audience, schedule, status, cancellation, and uniqueness constraints that do not belong to the core message table. A dedicated entity keeps lifecycle operations manageable while preserving system messages as the chat-facing output.

**Alternatives considered:**
- Store reminders directly in message metadata. Rejected because lifecycle queries, updates, uniqueness, and scheduling become awkward and fragile.
- Create reminder notifications only, without timeline messages. Rejected because the product goal explicitly wants reminder events to appear inside chat.

### D2: Represent reminder lifecycle in chat via `system` messages with structured metadata

**Decision:** Emit standard chat `system` messages for reminder-created, reminder-updated, reminder-cancelled, and reminder-fired events, with structured metadata that points back to the reminder and source message.

**Why:** The current mobile client already treats system messages as a separate presentation path and the websocket pipeline already distributes new messages. Reusing that path minimizes special-case transport logic.

**Alternatives considered:**
- Introduce a new websocket event type just for reminders. Rejected because the timeline still needs message-like rendering and persistence.
- Render reminder state only from separate reminder APIs. Rejected because it complicates chat history consistency and realtime sync.

### D3: Audience and duplicate rules are enforced at reminder creation/update time

**Decision:** Enforce uniqueness with scope-aware rules:
- `self`: no duplicate reminder for the same `creator_user_id + source_message_id + remind_at + scope=self`
- `everyone`: no duplicate reminder for the same `source_message_id + remind_at + scope=everyone`

**Why:** The product allows multiple reminders on the same message, but not two reminders that mean the same thing at the same time for the same audience.

**Alternatives considered:**
- Disallow multiple reminders on the same message entirely. Rejected because the product explicitly allows it.
- Deduplicate only at send time. Rejected because it leaves conflicting state in the database and confuses editing UX.

### D4: Reminder firing uses delayed jobs and idempotent state transitions

**Decision:** Use BullMQ delayed jobs for each reminder and require an idempotent transition from `pending` to `fired` before sending push notifications and creating the fired system message.

**Why:** The codebase already uses queue-based scheduling patterns, and idempotency is necessary to avoid duplicate fired messages or duplicate pushes when jobs retry.

**Alternatives considered:**
- Poll for due reminders every minute. Rejected because per-reminder scheduling is more precise and easier to reason about for update/cancel operations.
- Fire reminders entirely on the mobile client. Rejected because the feature must work even when the creator is offline and because `everyone` reminders need server-side coordination.

### D5: Reminder ownership belongs to the creator even for `everyone` reminders

**Decision:** Only the reminder creator can update or cancel a reminder after creation, regardless of whether its audience is `self` or `everyone`.

**Why:** This keeps authorization simple and avoids multi-owner editing ambiguity for a single scheduled reminder.

**Alternatives considered:**
- Let any group admin modify `everyone` reminders. Rejected for initial scope because it complicates permissions and auditability.
- Let all participants edit `everyone` reminders. Rejected because it causes ownership confusion and race conditions.

## Risks / Trade-offs

- [Risk] System-message volume may increase in active chats if reminders are frequently edited. → Mitigation: keep reminder events concise and scope future batching/de-duplication only if real usage demands it.
- [Risk] Recipient expectations may be unclear for `everyone` reminders in large groups. → Mitigation: make the audience explicit in reminder metadata and FE copy.
- [Risk] Reminder update/cancel operations may leave stale queued jobs if job identity is not stable. → Mitigation: use deterministic job IDs tied to reminder IDs and reschedule cleanly on update.
- [Risk] Existing system-message rendering may not yet support reminder cards cleanly. → Mitigation: standardize metadata shape so FE can branch on `metadata.kind`.

## Migration Plan

1. Add the reminder entity, migration, service, and queue processor on the backend.
2. Add reminder create/update/cancel APIs and connect them to system-message creation.
3. Reuse the current websocket `new_message` flow so reminder lifecycle events appear in chat.
4. Add mobile UI for context-menu action, reminder form, and reminder-specific system-message rendering.
5. Verify `self` and `everyone` reminders, including duplicate prevention, update, cancel, and firing behavior.

**Rollback:** Disable reminder creation endpoints and stop scheduling new reminder jobs while leaving historical system messages intact if production issues appear.

## Open Questions

None. The core product rules for audience, edit/cancel support, and duplicate-prevention behavior are already defined.
