## 1. Backend: Update sendMessage INSERT query

- [x] 1.1 Update `ChatService.sendMessage()` INSERT query in `apps/api/src/modules/chat/services/chat.service.ts` to include `forwarded_from_id` and `forwarded_from_sender` columns
- [x] 1.2 Extract `forwarded_from_id` and `forwarded_from_sender` from `data` parameter and pass to INSERT
- [x] 1.3 Verify existing send_message flow still works (no regression)

## 2. Backend: Create forwardMessages method

- [x] 2.1 Add `forwardMessages(senderId, data)` method to `ChatService`
- [x] 2.2 Parse payload: `message_ids: string[]`, `conv_ids: string[]`, `hide_sender: boolean`
- [x] 2.3 Validate sender membership in source conversation (conversation of original messages)
- [x] 2.4 Validate sender membership in all target conversations
- [x] 2.5 Look up original messages by IDs, filter out deleted messages (`deleted_at IS NOT NULL`)
- [x] 2.6 Sort original messages by `created_at` ascending
- [x] 2.7 For each target conversation, for each message: INSERT new message with original type, content, metadata, and `forwarded_from_id` = original message ID
- [x] 2.8 Set `forwarded_from_sender` to original sender name (lookup from users table) or `null` if `hide_sender` is true
- [x] 2.9 Use incrementing timestamps (+1ms) for each forwarded message to preserve order
- [x] 2.10 Publish each forwarded message to Redis Pub/Sub for fan-out
- [x] 2.11 Enqueue push notifications for offline members
- [x] 2.12 Return `{ forwarded_count: N }` response

## 3. Backend: Add forward_message WS event handler

- [x] 3.1 Add `case 'forward_message'` to ChatGateway `handleRawMessage()` switch
- [x] 3.2 Create `handleForwardMessage(socket, userId, envelope)` method
- [x] 3.3 Call `ChatService.forwardMessages()` and send `forward_ack` response
- [x] 3.4 Handle errors and send error response

## 4. Flutter: Drift migration for forward columns

- [x] 4.1 Add `forwardedFromId` (text nullable) column to `LocalMessages` table in `apps/mobile/lib/core/database/tables.dart`
- [x] 4.2 Add `forwardedFromSender` (text nullable) column to `LocalMessages` table
- [x] 4.3 Increment `schemaVersion` from 5 to 6 in `apps/mobile/lib/core/database/app_database.dart`
- [x] 4.4 Add `onUpgrade` migration for `from < 6`: ALTER TABLE to add both columns
- [x] 4.5 Run `dart run build_runner build --delete-conflicting-outputs` to regenerate Drift code

## 5. Flutter: Forward messages provider method

- [x] 5.1 Add `forwardMessages(List<String> messageIds, List<String> convIds, bool hideSender)` method to chat providers in `apps/mobile/lib/features/chat/providers/chat_providers.dart`
- [x] 5.2 Build `forward_message` WS payload and send via `wsManager.sendMessage()`
- [x] 5.3 Handle ack response

## 6. Flutter: Long-press context menu

- [x] 6.1 Add `_showMessageActions(LocalMessage message)` method to `ChatScreen`
- [x] 6.2 Show `showModalBottomSheet` with "Chuyển tiếp" action (`Icons.forward`)
- [x] 6.3 Wrap non-system `MessageBubble` with `GestureDetector(onLongPress: ...)` in `_buildMessageItems()`
- [x] 6.4 Tapping "Chuyển tiếp" enters selection mode with the message pre-selected

## 7. Flutter: Multi-select mode in ChatScreen

- [x] 7.1 Add state variables: `_isSelectionMode` (bool), `_selectedMessageIds` (Set<String>)
- [x] 7.2 Build selection AppBar: close button [✕], "[N] đã chọn" text, forward button [➤]
- [x] 7.3 Toggle AppBar between normal and selection mode
- [x] 7.4 In selection mode: tap message toggles selection (add/remove from Set)
- [x] 7.5 Show circular checkbox left of each message in selection mode
- [x] 7.6 Hide MessageInputBar when in selection mode
- [x] 7.7 Exit selection mode when close button tapped or last message deselected
- [x] 7.8 Tap forward button [➤] navigates to ForwardChatPickerScreen with selected message IDs

## 8. Flutter: ForwardChatPickerScreen

- [x] 8.1 Create `apps/mobile/lib/features/chat/screens/forward_chat_picker_screen.dart`
- [x] 8.2 Accept `List<String> messageIds` as constructor parameter
- [x] 8.3 Display conversation list from `chatListProvider` with checkboxes
- [x] 8.4 Add search bar to filter conversations by name
- [x] 8.5 Show selected conversation chips below search bar
- [x] 8.6 Add "Ẩn nguồn" toggle switch (default off)
- [x] 8.7 Add send FAB (disabled when no conversations selected)
- [x] 8.8 On send: call `forwardMessages()` provider method, pop back, exit selection mode
- [x] 8.9 Show SnackBar: "Đã chuyển tiếp N tin nhắn đến M cuộc trò chuyện"
- [x] 8.10 Add route in `app_router.dart` for ForwardChatPickerScreen

## 9. Flutter: Forward header in MessageBubble

- [x] 9.1 In `MessageBubble._buildBubble()`, check for `forwardedFromId` on the message (parse from metadata or direct field)
- [x] 9.2 If forwarded: render "↪ Chuyển tiếp từ [Name]" header (gold, italic, 12px) above content
- [x] 9.3 If `forwardedFromSender` is null: render "↪ Tin nhắn chuyển tiếp" instead
- [x] 9.4 Add forward header for all message types (text, image, album, video, voice)
- [x] 9.5 Ensure forward header appears inside the bubble, above the content

## 10. Flutter: Handle incoming forwarded messages

- [x] 10.1 Update message parsing in `chat_providers.dart` to map `forwarded_from_id` and `forwarded_from_sender` from WS/API responses to Drift `LocalMessagesCompanion`
- [x] 10.2 Ensure `forwardedFromId` and `forwardedFromSender` are stored in local DB when receiving `new_message` events

## 11. Testing

- [ ] 11.1 Test `forwardMessages()` backend: single message to single conversation
- [ ] 11.2 Test `forwardMessages()` backend: multiple messages to multiple conversations
- [ ] 11.3 Test `forwardMessages()` backend: hide_sender flag
- [ ] 11.4 Test `forwardMessages()` backend: deleted message skipped
- [ ] 11.5 Test `forwardMessages()` backend: non-member of target conversation rejected
- [ ] 11.6 Test `forwardMessages()` backend: message order preserved
- [ ] 11.7 Test forward_message WS event handler
- [ ] 11.8 Test Flutter: selection mode enter/exit
- [ ] 11.9 Test Flutter: ForwardChatPickerScreen multi-select
- [ ] 11.10 Test Flutter: forward header rendering

