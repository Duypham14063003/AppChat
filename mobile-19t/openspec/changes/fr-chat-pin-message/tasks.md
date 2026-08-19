## 1. Database Migration

- [x] 1.1 Create TypeORM migration file `apps/api/src/migrations/1710600000006-PinnedMessages.ts` with `pinned_messages` table: `conv_id` (uuid, NOT NULL), `message_id` (uuid, NOT NULL), `pinned_by` (uuid, NOT NULL), `pinned_at` (timestamptz, DEFAULT now()), PK `(conv_id, message_id)`, FK to `conversations(id)` ON DELETE CASCADE, FK to `users(id)` ON DELETE CASCADE, index on `(conv_id, pinned_at DESC)`
- [x] 1.2 Create `PinnedMessage` TypeORM entity at `apps/api/src/modules/chat/entities/pinned-message.entity.ts` with `@Entity('pinned_messages')`, composite PK columns, ManyToOne relations to Conversation and User
- [x] 1.3 Register `PinnedMessage` entity in `ChatModule`'s `TypeOrmModule.forFeature()` array in `apps/api/src/modules/chat/chat.module.ts`

## 2. Backend: Pin/Unpin Service Methods

- [x] 2.1 Inject `Repository<PinnedMessage>` into `ChatService` constructor
- [x] 2.2 Add `pinMessage(userId, convId, messageId)` method to `ChatService`: validate membership, check permission (any for DIRECT, admin/creator for GROUP), verify message belongs to conversation, check 5-pin limit, check not already pinned, INSERT into pinned_messages, call `insertSystemMessage` with content key "pinned_message", broadcast `pin_update` via Redis PubSub
- [x] 2.3 Add `unpinMessage(userId, convId, messageId)` method to `ChatService`: validate membership, check permission, verify pin exists, DELETE from pinned_messages, call `insertSystemMessage` with content key "unpinned_message", broadcast `pin_update`
- [x] 2.4 Add `getPinnedMessages(userId, convId)` method to `ChatService`: validate membership, SELECT from pinned_messages JOIN messages (by id) JOIN users (sender), return ordered by pinned_at DESC with message content and sender info
- [x] 2.5 Add `unpinAllMessages(userId, convId)` method to `ChatService`: validate membership, check permission (admin/creator for GROUP, any for DIRECT), DELETE all pins for conversation, call `insertSystemMessage` with content key "unpinned_all_messages", broadcast `pin_update` with action "unpinned_all"
- [x] 2.6 Add helper method `canPin(userId, convId)` to check pin permission: returns true if DIRECT conversation, or if user is admin/creator in GROUP conversation

## 3. Backend: REST Endpoints

- [x] 3.1 Add DTO classes in `apps/api/src/modules/chat/dto/chat.dto.ts`: `PinMessageDto` with `message_id` (IsUUID), no new DTO needed for unpin (path params only)
- [x] 3.2 Add `POST /:id/pins` endpoint to `ConversationController`: accepts `PinMessageDto`, calls `chatService.pinMessage()`, returns 201
- [x] 3.3 Add `DELETE /:id/pins/:messageId` endpoint to `ConversationController`: calls `chatService.unpinMessage()`, returns 200
- [x] 3.4 Add `GET /:id/pins` endpoint to `ConversationController`: calls `chatService.getPinnedMessages()`, returns 200
- [x] 3.5 Add `DELETE /:id/pins` endpoint to `ConversationController` (unpin all, distinguished from 3.3 by absence of messageId param): calls `chatService.unpinAllMessages()`, returns 200

## 4. Backend: WebSocket Event Routing

- [x] 4.1 Add `pin_update` case to `ChatGateway.handleRawMessage()` switch — no handler needed since pin uses REST, but the `_event: 'pin_update'` from Redis PubSub is already dispatched by the existing fan-out mechanism (verify this works with existing `RedisPubSubService` message handler)

## 5. Flutter: Drift Schema Migration

- [x] 5.1 Add `LocalPinnedMessages` table to `apps/mobile/lib/core/database/tables.dart`: `convId` (text), `messageId` (text), `pinnedBy` (text), `pinnedAt` (dateTime), PK `{convId, messageId}`
- [x] 5.2 Register `LocalPinnedMessages` in `@DriftDatabase` annotation in `apps/mobile/lib/core/database/app_database.dart`
- [x] 5.3 Increment `schemaVersion` from 5 to 6 in `app_database.dart`
- [x] 5.4 Add migration block `if (from < 6) { await m.createTable(localPinnedMessages); }` in `onUpgrade`
- [x] 5.5 Add `LocalPinnedMessages` to `@DriftAccessor(tables: [...])` in `chat_dao.dart`
- [x] 5.6 Add DAO methods in `chat_dao.dart`: `insertPinnedMessage()`, `deletePinnedMessage(convId, messageId)`, `deleteAllPinnedMessages(convId)`, `getPinnedMessages(convId)` (ordered by pinnedAt DESC), `watchPinnedMessages(convId)` (Stream)
- [x] 5.7 Run `dart run build_runner build --delete-conflicting-outputs` to regenerate Drift code

## 6. Flutter: ChatRepository HTTP Methods

- [x] 6.1 Add `pinMessage(String convId, String messageId)` to `ChatRepository` — `POST /conversations/$convId/pins` with `{ message_id }`
- [x] 6.2 Add `unpinMessage(String convId, String messageId)` to `ChatRepository` — `DELETE /conversations/$convId/pins/$messageId`
- [x] 6.3 Add `getPinnedMessages(String convId)` to `ChatRepository` — `GET /conversations/$convId/pins`
- [x] 6.4 Add `unpinAllMessages(String convId)` to `ChatRepository` — `DELETE /conversations/$convId/pins`

## 7. Flutter: Pinned Messages Provider

- [x] 7.1 Create `pinnedMessagesProvider(conversationId)` family AsyncNotifier in `chat_providers.dart`: build() loads from local DAO, fetches from API, caches to DAO, returns list ordered by pinnedAt DESC
- [x] 7.2 Register `pin_update` WebSocket event handler in the provider: on event, parse pinned_messages array from payload, update local DAO and state
- [x] 7.3 Add `pinMessage(messageId)` method: call `chatRepository.pinMessage()`, refresh state from API response
- [x] 7.4 Add `unpinMessage(messageId)` method: call `chatRepository.unpinMessage()`, refresh state
- [x] 7.5 Add `unpinAllMessages()` method: call `chatRepository.unpinAllMessages()`, clear local DAO, refresh state
- [x] 7.6 Add `isPinned(messageId)` helper that checks current state

## 8. Flutter: PinnedMessageBar Widget

- [x] 8.1 Create `PinnedMessageBar` widget at `apps/mobile/lib/features/chat/widgets/pinned_message_bar.dart`: StatefulWidget with `conversationId` param, watches `pinnedMessagesProvider`
- [x] 8.2 Implement bar layout: pin icon (📌), counter text ("1/3"), sender name + truncated content (1 line, ellipsis), using `AppColors.surface` background with top/bottom border
- [x] 8.3 Implement tap handler: scroll to current pin's message (via callback `onScrollToMessage(messageId)`), then advance cycle index (wrapping)
- [x] 8.4 Integrate `PinnedMessageBar` into `ChatScreen.build()` — insert between WS connection banner and `Expanded` message list in the Column children

## 9. Flutter: Pinned Messages List Screen

- [x] 9.1 Create `PinnedMessagesListScreen` at `apps/mobile/lib/features/chat/screens/pinned_messages_screen.dart`: ConsumerWidget with `conversationId` param, watches `pinnedMessagesProvider`
- [x] 9.2 Implement list UI: AppBar with "Tin nhắn đã ghim" title, ListView of pinned messages showing sender avatar, sender name, content preview, message timestamp, "Ghim bởi [name]" subtitle
- [x] 9.3 Implement tap-to-jump: on item tap, pop screen and pass back the message ID, ChatScreen receives it and scrolls to that message with highlight
- [x] 9.4 Add "Bỏ ghim tất cả" button in AppBar actions (visible only for admin/creator in GROUP, any in DIRECT)
- [x] 9.5 Add route for PinnedMessagesListScreen in GoRouter configuration
- [x] 9.6 Add pin count badge ("📌 N") to ChatScreen AppBar actions — tappable, navigates to PinnedMessagesListScreen

## 10. Flutter: Unified Context Menu (Message Long-Press)

- [x] 10.1 Create `showMessageContextMenu()` function at `apps/mobile/lib/features/chat/widgets/message_context_menu.dart`: accepts message, isMine, conversationId, conversationType, userRole, isPinned, onReaction callback, onPin/onUnpin callbacks
- [x] 10.2 Implement quick reaction row at top of bottom sheet: horizontal row of 6 emojis (😀 😂 ❤️ 👍 😢 🔥) + expand [+] button, same emojis as current ReactionPicker
- [x] 10.3 Implement pin/unpin action ListTile: "📌 Ghim tin nhắn" or "📌 Bỏ ghim" based on isPinned, visible only when user has pin permission
- [x] 10.4 Implement future action slots: "↩️ Trả lời", "📋 Sao chép", "🗑️ Xóa" as ListTile items — present but non-functional (onTap shows "Sắp ra mắt" SnackBar or hidden, based on preference)
- [x] 10.5 Replace `_showReactionPicker()` in `MessageItem` with call to `showMessageContextMenu()` — pass all required context (message, conversation type, user role, pin status from pinnedMessagesProvider)
- [x] 10.6 Preserve double-tap ❤️ reaction on `GestureDetector` in `MessageItem` (no change to onDoubleTap)

## 11. Verification

- [x] 11.1 Run `npm run lint` in `apps/api` — fix any issues
- [x] 11.2 Run `npm run build` in `apps/api` — fix any TypeScript errors
- [ ] 11.3 Run `npm test` in `apps/api` — fix any broken tests
- [x] 11.4 Run `flutter analyze` in `apps/mobile` — fix any issues
- [x] 11.5 Run `dart run build_runner build --delete-conflicting-outputs` in `apps/mobile` — verify codegen succeeds
