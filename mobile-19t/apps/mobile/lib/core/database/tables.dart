import 'package:drift/drift.dart';

class LocalConversations extends Table {
  TextColumn get id => text()();
  TextColumn get type => text().withDefault(const Constant('DIRECT'))();
  TextColumn get name => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get createdBy => text()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  // Denormalized fields for list display
  TextColumn get lastMessageContent => text().nullable()();
  TextColumn get lastMessageSenderId => text().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  IntColumn get unreadMentionCount =>
      integer().withDefault(const Constant(0))();
  // Other member info for DIRECT conversations
  TextColumn get otherMemberName => text().nullable()();
  TextColumn get otherMemberAvatar => text().nullable()();
  DateTimeColumn get otherMemberLastSeenAt => dateTime().nullable()();
  DateTimeColumn get lastViewedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalMessages extends Table {
  TextColumn get id => text()();
  TextColumn get convId => text()();
  TextColumn get senderId => text()();
  TextColumn get type => text().withDefault(const Constant('text'))();
  TextColumn get content => text().nullable()();
  TextColumn get replyToId => text().nullable()();
  TextColumn get metadata => text().nullable()(); // JSON string
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get editedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  // Client-side status: pending, sent, delivered, read, failed
  TextColumn get status => text().withDefault(const Constant('sent'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  // Forward fields
  TextColumn get forwardedFromId => text().nullable()();
  TextColumn get forwardedFromSender => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PendingUploads extends Table {
  TextColumn get id => text()();
  TextColumn get convId => text()();
  TextColumn get localPaths => text()(); // JSON array of local file paths
  TextColumn get caption => text().nullable()();
  TextColumn get status => text().withDefault(
    const Constant('queued'),
  )(); // queued, uploading, failed
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalMessageReactions extends Table {
  TextColumn get messageId => text()();
  TextColumn get userId => text()();
  TextColumn get emoji => text()();
  TextColumn get userName => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {messageId, userId, emoji};
}

class LocalPinnedMessages extends Table {
  TextColumn get convId => text()();
  TextColumn get messageId => text()();
  TextColumn get pinnedBy => text()();
  DateTimeColumn get pinnedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {convId, messageId};
}

class LocalBookmarkedMessages extends Table {
  TextColumn get convId => text()();
  TextColumn get messageId => text()();
  TextColumn get userId => text()();
  DateTimeColumn get markedAt => dateTime()();
  TextColumn get messageContent => text().nullable()();
  TextColumn get messageType => text().nullable()();
  TextColumn get senderId => text().nullable()();
  TextColumn get senderName => text().nullable()();
  DateTimeColumn get messageCreatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {convId, messageId};
}

class LocalAttendance extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get checkinAt => dateTime()();
  DateTimeColumn get checkoutAt => dateTime().nullable()();
  RealColumn get checkinLat => real().nullable()();
  RealColumn get checkinLng => real().nullable()();
  RealColumn get totalHours => real().nullable()();
  RealColumn get otHours => real().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending_sync'))();

  @override
  Set<Column> get primaryKey => {id};
}
