## Why

The chat experience currently supports reactions, pinning, bookmarking, replying, forwarding, and message context actions, but it does not help users turn an important message into a timed reminder. Users need a lightweight way to long-press a message, schedule a reminder for themselves or the conversation, and see that reminder lifecycle reflected directly inside the chat timeline.

## What Changes

- Add a chat message reminder capability that can be created from the existing message long-press menu.
- Support reminder audience selection: remind only the creator or remind everyone in the conversation.
- Support reminder lifecycle actions after creation: update and cancel.
- Insert chat-visible system messages when a reminder is created, updated, cancelled, and triggered.
- Trigger scheduled reminder delivery at the chosen time and notify the intended recipients without allowing duplicate reminders at the same timestamp within the same scope.

## Capabilities

### New Capabilities
- `chat-message-reminder`: Create, manage, schedule, and surface timed reminders linked to chat messages, including audience targeting and chat timeline events.

### Modified Capabilities
<!-- None. -->

## Impact

- Mobile chat UI: message long-press context menu, reminder creation/edit/cancel flows, and system-message rendering in the timeline
- Mobile chat data handling: message metadata parsing and reminder-specific presentation
- Chat backend: reminder entity, scheduling, lifecycle APIs, and system-message creation
- Realtime delivery: websocket broadcast of reminder lifecycle messages
- Notification pipeline: scheduled push delivery for reminder recipients
