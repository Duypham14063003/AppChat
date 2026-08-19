## ADDED Requirements

### Requirement: Group notifications from same conversation within time window
The system SHALL track recent push notification count per (user_id, conv_id) in Redis with a 30-second TTL. When the count exceeds 1 within the window, the system SHALL send a grouped notification instead of individual ones. The grouped notification body SHALL be "{sender} sent {N} new messages" for DM or "{group}: {N} new messages" for group conversations.

#### Scenario: Two messages within 30 seconds
- **WHEN** user A sends 2 messages to user B within 30 seconds and user B is offline
- **THEN** user B receives 1 push notification with body "Nguyễn A sent 2 new messages" instead of 2 separate notifications

#### Scenario: Messages outside grouping window
- **WHEN** user A sends a message, then 45 seconds later sends another message
- **THEN** user B receives 2 separate push notifications (the Redis counter expired after 30s)

### Requirement: Redis counter for notification grouping
The system SHALL use Redis INCR on key `notif:group:{userId}:{convId}` with 30-second TTL to track notification count. The first message in a window SHALL be sent immediately. Subsequent messages within the window SHALL update the existing notification (if platform supports) or be suppressed until the window expires.

#### Scenario: First message sent immediately
- **WHEN** the first message arrives for a user-conversation pair with no active grouping window
- **THEN** the push notification is sent immediately and the Redis counter is set to 1 with 30s TTL

#### Scenario: Subsequent messages grouped
- **WHEN** a second message arrives within the 30s window
- **THEN** the Redis counter increments to 2 and a grouped notification replaces the previous one

### Requirement: Grouping respects Android notification tag
The system SHALL use the conversation ID as the Android notification `tag` so that grouped notifications replace previous ones from the same conversation rather than stacking.

#### Scenario: Android notification replaced
- **WHEN** 3 messages arrive from the same conversation within 30 seconds on Android
- **THEN** only 1 notification is visible in the notification shade showing "3 new messages"

