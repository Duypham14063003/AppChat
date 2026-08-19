## Context

The mobile app already initializes Firebase Messaging, handles notification taps centrally in `apps/mobile/lib/app.dart`, and can show local notifications while the app is open through `LocalNotificationService`. The router and shell also already know the current location, including which chat conversation is active through `/chat/:convId`.

However, the current chat notification behavior ignores foreground presence in two different ways. On the backend, chat push jobs are skipped for online users, so users who remain connected inside the app never receive FCM chat pushes. On the mobile side, when a foreground FCM message does arrive, `PushNotificationService` always shows a local notification and has no suppression rule for “the user is already reading this exact conversation.” The requested behavior is narrower and more conversational: suppress notifications only while the user is already inside the matching chat thread, but still surface a foreground alert when the user is on another screen or another conversation.

## Goals / Non-Goals

**Goals:**
- Suppress foreground chat notifications when the user is already viewing the same conversation identified by the incoming `conv_id`.
- Show a foreground local notification when a chat message arrives while the app is open but the user is on a different route or a different conversation.
- Reuse existing routing state and notification plumbing instead of adding a second navigation or presence system.
- Keep notification tap handling and background push behavior intact.

**Non-Goals:**
- Redesign chat push delivery for background or terminated app states.
- Change unread badge count behavior or notification payload schema beyond what is needed for suppression decisions.
- Build a full presence service shared with the backend.
- Add notification preferences such as mute-in-foreground or per-conversation overrides.

## Decisions

### D1: Foreground suppression is a mobile routing decision

**Decision:** Decide whether to show a foreground chat notification on the client by comparing the incoming notification `conv_id` against the currently active mobile route.

**Why:** The mobile app already has the exact UI context the rule depends on: whether the user is looking at `/chat/:convId`, and if so which conversation. This is simpler and more accurate than trying to teach the backend the user’s current on-screen route.

**Alternatives considered:**
- Suppress on the backend based on websocket online state alone. Rejected because “online” is not the same as “currently viewing this conversation.”
- Add a backend-managed active-conversation presence channel. Rejected because it is a larger presence system than this bug requires.

### D2: Foreground chat alerts should be shown from in-app realtime handling

**Decision:** Use app-side foreground handling to show route-aware local notifications for incoming chat messages while the app is open.

**Why:** The backend currently skips push for online users, so foreground notification behavior cannot depend solely on FCM delivery. The app already has realtime chat events and local-notification capability, making foreground-local alerts the smallest path to the requested UX.

**Alternatives considered:**
- Force backend to send FCM even for online users. Rejected for this change because it would duplicate notification sources with websocket realtime and broaden server-side scope.
- Do nothing for online users and keep notifications background-only. Rejected because it preserves the exact bug the user reported.

### D3: Suppression applies only to exact conversation match

**Decision:** Suppress only when the user is on the exact `/chat/:convId` route for the incoming message’s conversation. All other foreground app states continue to show a local notification.

**Why:** This matches user expectation precisely: if they are already in that conversation, the message is visible in context and does not need another alert. If they are elsewhere, they still need interruption.

**Alternatives considered:**
- Suppress for any `/chat/*` route. Rejected because the user explicitly wants alerts when they are chatting with someone else and another conversation replies.
- Suppress for any app foreground state. Rejected because it removes useful alerts while the user is on unrelated screens.

## Risks / Trade-offs

- [Risk] If both websocket-driven foreground alerts and FCM foreground alerts fire for the same chat event, the user could see duplicate notifications. → Mitigation: centralize chat foreground suppression in one mobile decision path and avoid double-showing for the same message id.
- [Risk] Route parsing may be inconsistent between narrow/mobile and wide/embedded chat layouts. → Mitigation: reuse the same route and conversation-id parsing already used by the shell/router instead of inventing a new matcher.
- [Risk] Online/background state transitions can race with notification arrival. → Mitigation: treat the current route at event time as the source of truth and keep the rule idempotent.

## Migration Plan

1. Add a foreground chat-notification policy that can compare incoming `conv_id` with the app’s current route or active conversation.
2. Route incoming chat events through that policy before showing a local foreground notification.
3. Preserve notification tap handling and non-chat notification behavior.
4. Add tests for same-conversation suppression and different-conversation foreground alerts.
5. Manually verify open-chat, other-chat, and non-chat foreground scenarios on mobile.

**Rollback:** If foreground-local alerting introduces duplicate or noisy notifications, disable the new foreground chat alert path while keeping the suppression helper isolated for future rework.

## Open Questions

None. The desired suppression rule is specific and the mobile app already exposes the route context needed to implement it.
