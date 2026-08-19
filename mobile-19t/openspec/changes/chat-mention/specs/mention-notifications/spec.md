## mention-notifications

Mention-aware push notifications that override mute for mentioned users. Custom notification titles. @all support for group-wide notifications.

### Requirements

1. **Extract mentioned user IDs in ChatService**
   - In `ChatService.enqueueOfflinePush()`, parse `message.metadata` to extract mention user IDs
   - Handle: `metadata` is null, `metadata.mentions` is null/empty, malformed JSON
   - Build `Set<string>` of mentioned user IDs
   - Check for `user_id: "all"` — set a boolean `isMentionAll`
   - Pass `mentionedUserIds` and `isMentionAll` to the push enqueue logic

2. **Override mute for mentioned users**
   - Current logic in `enqueueOfflinePush()`:
     ```typescript
     if (member.is_muted) continue; // skips muted members
     ```
   - New logic:
     ```typescript
     const isMentioned = mentionedUserIds.has(member.user_id) || isMentionAll;
     if (member.is_muted && !isMentioned) continue; // skip muted UNLESS mentioned
     ```
   - Mentioned users receive push even when muted
   - Non-mentioned muted users still skipped (no change)

3. **Update NotificationJobService job data**
   - Add `isMentioned: boolean` field to push job data
   - Current fields: `recipientUserId, messageId, convId, senderId, content, type`
   - New field: `isMentioned` — true if recipient is in mentionedUserIds or isMentionAll

4. **Update PushNotificationProcessor**
   - Read `isMentioned` from `job.data`
   - Override mute check: if `isMentioned`, skip the `is_muted` return
     ```typescript
     if (membership?.is_muted && !job.data.isMentioned) return;
     ```
   - Custom notification title when mentioned:
     - `isMentioned && !isMentionAll`: `"${senderName} đã nhắc đến bạn"`
     - `isMentionAll`: `"${senderName} đã nhắc đến mọi người"`
     - Normal (not mentioned): `senderName` (existing behavior)
   - Body remains: `content` preview (existing behavior)

5. **@all notification fan-out**
   - When `isMentionAll` is true in `enqueueOfflinePush()`:
     - Skip `is_muted` check for ALL members (everyone gets notified)
     - Still skip sender (`member.user_id === senderId`)
     - Still skip online users (`connectionManager.isOnline()`)
   - Each job gets `isMentioned: true` so processor uses mention title

6. **FCM data payload**
   - Add `is_mention: "true"` to FCM data payload when `isMentioned`
   - This allows Flutter client to handle mention notifications differently if needed (e.g., different sound, badge update)
   - Current data: `{conv_id, message_id, type: 'chat_message'}`
   - New data: `{conv_id, message_id, type: 'chat_message', is_mention: 'true'}` (when mentioned)

### Technical Details

**Updated enqueueOfflinePush in ChatService:**
```typescript
private async enqueueOfflinePush(
  convId: string,
  senderId: string,
  message: Message,
): Promise<void> {
  const members = await this.memberRepo.find({
    where: { conv_id: convId },
    select: ['user_id', 'is_muted'],
  });

  // Extract mentioned user IDs from metadata
  const mentionedUserIds = new Set<string>();
  let isMentionAll = false;
  if (message.metadata) {
    const meta = typeof message.metadata === 'string'
      ? JSON.parse(message.metadata)
      : message.metadata;
    const mentions = meta?.mentions as Array<{user_id: string}> | undefined;
    if (mentions) {
      for (const m of mentions) {
        if (m.user_id === 'all') {
          isMentionAll = true;
        } else {
          mentionedUserIds.add(m.user_id);
        }
      }
    }
  }

  for (const member of members) {
    if (member.user_id === senderId) continue;
    const isMentioned = mentionedUserIds.has(member.user_id) || isMentionAll;
    if (member.is_muted && !isMentioned) continue;
    if (this.connectionManager.isOnline(member.user_id)) continue;

    await this.notificationJob.enqueuePush(member.user_id, message, isMentioned);
  }
}
```

**Updated enqueuePush in NotificationJobService:**
```typescript
async enqueuePush(recipientUserId: string, message: Message, isMentioned = false): Promise<void> {
  await this.pushQueue.add('send-push', {
    recipientUserId,
    messageId: message.id,
    convId: message.conv_id,
    senderId: message.sender_id,
    content: message.content?.substring(0, 100),
    type: message.type,
    isMentioned,
  }, {
    attempts: 3,
    backoff: { type: 'exponential', delay: 2000 },
  });
}
```

**Updated PushNotificationProcessor.process():**
```typescript
async process(job: Job): Promise<void> {
  if (!this.firebaseService.isEnabled()) return;

  const { recipientUserId, senderId, convId, content, type, isMentioned } = job.data;

  // Check mute — but allow if mentioned
  const membership = await this.memberRepo.findOne({
    where: { conv_id: convId, user_id: recipientUserId },
  });
  if (membership?.is_muted && !isMentioned) return;

  const sender = await this.userRepo.findOne({
    where: { id: senderId },
    select: ['name'],
  });

  // Build title based on mention status
  let title: string;
  if (isMentioned) {
    title = `${sender?.name || 'Someone'} đã nhắc đến bạn`;
  } else {
    title = sender?.name || 'New message';
  }
  const body = type === 'text' ? content || '' : `Sent a ${type}`;

  const data: Record<string, string> = {
    conv_id: convId,
    message_id: job.data.messageId,
    type: 'chat_message',
  };
  if (isMentioned) data.is_mention = 'true';

  // Send to all sessions...
}
```

### Integration Points

- `ChatService.enqueueOfflinePush()` — mention extraction, mute override logic
- `NotificationJobService.enqueuePush()` — add `isMentioned` parameter and job field
- `PushNotificationProcessor.process()` — mute override, custom title, FCM data
- `FirebaseService.sendPush()` — no changes needed (already accepts data map)

### Acceptance Criteria

- User mentioned in group → receives push notification even if group is muted
- User NOT mentioned in muted group → no push notification (existing behavior preserved)
- @all mention → ALL offline members receive push, including muted members
- Notification title for mention: "SenderName đã nhắc đến bạn"
- Notification title for @all: "SenderName đã nhắc đến mọi người"
- Notification title for normal message: "SenderName" (no change)
- FCM data includes `is_mention: "true"` for mention notifications
- Sender never receives their own mention notification
- Online users don't receive push (existing behavior preserved)
- Malformed metadata doesn't crash — graceful fallback to normal push behavior

