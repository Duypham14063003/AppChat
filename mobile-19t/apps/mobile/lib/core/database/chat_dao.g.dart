// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_dao.dart';

// ignore_for_file: type=lint
mixin _$ChatDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalConversationsTable get localConversations =>
      attachedDatabase.localConversations;
  $LocalMessagesTable get localMessages => attachedDatabase.localMessages;
  $PendingUploadsTable get pendingUploads => attachedDatabase.pendingUploads;
  $LocalMessageReactionsTable get localMessageReactions =>
      attachedDatabase.localMessageReactions;
  $LocalPinnedMessagesTable get localPinnedMessages =>
      attachedDatabase.localPinnedMessages;
  $LocalBookmarkedMessagesTable get localBookmarkedMessages =>
      attachedDatabase.localBookmarkedMessages;
}
