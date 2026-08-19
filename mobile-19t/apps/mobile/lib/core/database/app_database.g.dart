// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalConversationsTable extends LocalConversations
    with TableInfo<$LocalConversationsTable, LocalConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('DIRECT'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastMessageAtMeta = const VerificationMeta(
    'lastMessageAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastMessageAt =
      GeneratedColumn<DateTime>(
        'last_message_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastMessageContentMeta =
      const VerificationMeta('lastMessageContent');
  @override
  late final GeneratedColumn<String> lastMessageContent =
      GeneratedColumn<String>(
        'last_message_content',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastMessageSenderIdMeta =
      const VerificationMeta('lastMessageSenderId');
  @override
  late final GeneratedColumn<String> lastMessageSenderId =
      GeneratedColumn<String>(
        'last_message_sender_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _unreadMentionCountMeta =
      const VerificationMeta('unreadMentionCount');
  @override
  late final GeneratedColumn<int> unreadMentionCount = GeneratedColumn<int>(
    'unread_mention_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _otherMemberNameMeta = const VerificationMeta(
    'otherMemberName',
  );
  @override
  late final GeneratedColumn<String> otherMemberName = GeneratedColumn<String>(
    'other_member_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _otherMemberAvatarMeta = const VerificationMeta(
    'otherMemberAvatar',
  );
  @override
  late final GeneratedColumn<String> otherMemberAvatar =
      GeneratedColumn<String>(
        'other_member_avatar',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _otherMemberLastSeenAtMeta =
      const VerificationMeta('otherMemberLastSeenAt');
  @override
  late final GeneratedColumn<DateTime> otherMemberLastSeenAt =
      GeneratedColumn<DateTime>(
        'other_member_last_seen_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastViewedAtMeta = const VerificationMeta(
    'lastViewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastViewedAt = GeneratedColumn<DateTime>(
    'last_viewed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    name,
    avatarUrl,
    createdBy,
    lastMessageAt,
    createdAt,
    lastMessageContent,
    lastMessageSenderId,
    unreadCount,
    unreadMentionCount,
    otherMemberName,
    otherMemberAvatar,
    otherMemberLastSeenAt,
    lastViewedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalConversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('last_message_at')) {
      context.handle(
        _lastMessageAtMeta,
        lastMessageAt.isAcceptableOrUnknown(
          data['last_message_at']!,
          _lastMessageAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_message_content')) {
      context.handle(
        _lastMessageContentMeta,
        lastMessageContent.isAcceptableOrUnknown(
          data['last_message_content']!,
          _lastMessageContentMeta,
        ),
      );
    }
    if (data.containsKey('last_message_sender_id')) {
      context.handle(
        _lastMessageSenderIdMeta,
        lastMessageSenderId.isAcceptableOrUnknown(
          data['last_message_sender_id']!,
          _lastMessageSenderIdMeta,
        ),
      );
    }
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    if (data.containsKey('unread_mention_count')) {
      context.handle(
        _unreadMentionCountMeta,
        unreadMentionCount.isAcceptableOrUnknown(
          data['unread_mention_count']!,
          _unreadMentionCountMeta,
        ),
      );
    }
    if (data.containsKey('other_member_name')) {
      context.handle(
        _otherMemberNameMeta,
        otherMemberName.isAcceptableOrUnknown(
          data['other_member_name']!,
          _otherMemberNameMeta,
        ),
      );
    }
    if (data.containsKey('other_member_avatar')) {
      context.handle(
        _otherMemberAvatarMeta,
        otherMemberAvatar.isAcceptableOrUnknown(
          data['other_member_avatar']!,
          _otherMemberAvatarMeta,
        ),
      );
    }
    if (data.containsKey('other_member_last_seen_at')) {
      context.handle(
        _otherMemberLastSeenAtMeta,
        otherMemberLastSeenAt.isAcceptableOrUnknown(
          data['other_member_last_seen_at']!,
          _otherMemberLastSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('last_viewed_at')) {
      context.handle(
        _lastViewedAtMeta,
        lastViewedAt.isAcceptableOrUnknown(
          data['last_viewed_at']!,
          _lastViewedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalConversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalConversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      lastMessageAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_message_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastMessageContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_content'],
      ),
      lastMessageSenderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_sender_id'],
      ),
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      unreadMentionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_mention_count'],
      )!,
      otherMemberName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_member_name'],
      ),
      otherMemberAvatar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_member_avatar'],
      ),
      otherMemberLastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}other_member_last_seen_at'],
      ),
      lastViewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_viewed_at'],
      ),
    );
  }

  @override
  $LocalConversationsTable createAlias(String alias) {
    return $LocalConversationsTable(attachedDatabase, alias);
  }
}

class LocalConversation extends DataClass
    implements Insertable<LocalConversation> {
  final String id;
  final String type;
  final String? name;
  final String? avatarUrl;
  final String createdBy;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final String? lastMessageContent;
  final String? lastMessageSenderId;
  final int unreadCount;
  final int unreadMentionCount;
  final String? otherMemberName;
  final String? otherMemberAvatar;
  final DateTime? otherMemberLastSeenAt;
  final DateTime? lastViewedAt;
  const LocalConversation({
    required this.id,
    required this.type,
    this.name,
    this.avatarUrl,
    required this.createdBy,
    this.lastMessageAt,
    required this.createdAt,
    this.lastMessageContent,
    this.lastMessageSenderId,
    required this.unreadCount,
    required this.unreadMentionCount,
    this.otherMemberName,
    this.otherMemberAvatar,
    this.otherMemberLastSeenAt,
    this.lastViewedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    map['created_by'] = Variable<String>(createdBy);
    if (!nullToAbsent || lastMessageAt != null) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastMessageContent != null) {
      map['last_message_content'] = Variable<String>(lastMessageContent);
    }
    if (!nullToAbsent || lastMessageSenderId != null) {
      map['last_message_sender_id'] = Variable<String>(lastMessageSenderId);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    map['unread_mention_count'] = Variable<int>(unreadMentionCount);
    if (!nullToAbsent || otherMemberName != null) {
      map['other_member_name'] = Variable<String>(otherMemberName);
    }
    if (!nullToAbsent || otherMemberAvatar != null) {
      map['other_member_avatar'] = Variable<String>(otherMemberAvatar);
    }
    if (!nullToAbsent || otherMemberLastSeenAt != null) {
      map['other_member_last_seen_at'] = Variable<DateTime>(
        otherMemberLastSeenAt,
      );
    }
    if (!nullToAbsent || lastViewedAt != null) {
      map['last_viewed_at'] = Variable<DateTime>(lastViewedAt);
    }
    return map;
  }

  LocalConversationsCompanion toCompanion(bool nullToAbsent) {
    return LocalConversationsCompanion(
      id: Value(id),
      type: Value(type),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      createdBy: Value(createdBy),
      lastMessageAt: lastMessageAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageAt),
      createdAt: Value(createdAt),
      lastMessageContent: lastMessageContent == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageContent),
      lastMessageSenderId: lastMessageSenderId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageSenderId),
      unreadCount: Value(unreadCount),
      unreadMentionCount: Value(unreadMentionCount),
      otherMemberName: otherMemberName == null && nullToAbsent
          ? const Value.absent()
          : Value(otherMemberName),
      otherMemberAvatar: otherMemberAvatar == null && nullToAbsent
          ? const Value.absent()
          : Value(otherMemberAvatar),
      otherMemberLastSeenAt: otherMemberLastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(otherMemberLastSeenAt),
      lastViewedAt: lastViewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastViewedAt),
    );
  }

  factory LocalConversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalConversation(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      name: serializer.fromJson<String?>(json['name']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      lastMessageAt: serializer.fromJson<DateTime?>(json['lastMessageAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastMessageContent: serializer.fromJson<String?>(
        json['lastMessageContent'],
      ),
      lastMessageSenderId: serializer.fromJson<String?>(
        json['lastMessageSenderId'],
      ),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      unreadMentionCount: serializer.fromJson<int>(json['unreadMentionCount']),
      otherMemberName: serializer.fromJson<String?>(json['otherMemberName']),
      otherMemberAvatar: serializer.fromJson<String?>(
        json['otherMemberAvatar'],
      ),
      otherMemberLastSeenAt: serializer.fromJson<DateTime?>(
        json['otherMemberLastSeenAt'],
      ),
      lastViewedAt: serializer.fromJson<DateTime?>(json['lastViewedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'name': serializer.toJson<String?>(name),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'createdBy': serializer.toJson<String>(createdBy),
      'lastMessageAt': serializer.toJson<DateTime?>(lastMessageAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastMessageContent': serializer.toJson<String?>(lastMessageContent),
      'lastMessageSenderId': serializer.toJson<String?>(lastMessageSenderId),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'unreadMentionCount': serializer.toJson<int>(unreadMentionCount),
      'otherMemberName': serializer.toJson<String?>(otherMemberName),
      'otherMemberAvatar': serializer.toJson<String?>(otherMemberAvatar),
      'otherMemberLastSeenAt': serializer.toJson<DateTime?>(
        otherMemberLastSeenAt,
      ),
      'lastViewedAt': serializer.toJson<DateTime?>(lastViewedAt),
    };
  }

  LocalConversation copyWith({
    String? id,
    String? type,
    Value<String?> name = const Value.absent(),
    Value<String?> avatarUrl = const Value.absent(),
    String? createdBy,
    Value<DateTime?> lastMessageAt = const Value.absent(),
    DateTime? createdAt,
    Value<String?> lastMessageContent = const Value.absent(),
    Value<String?> lastMessageSenderId = const Value.absent(),
    int? unreadCount,
    int? unreadMentionCount,
    Value<String?> otherMemberName = const Value.absent(),
    Value<String?> otherMemberAvatar = const Value.absent(),
    Value<DateTime?> otherMemberLastSeenAt = const Value.absent(),
    Value<DateTime?> lastViewedAt = const Value.absent(),
  }) => LocalConversation(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name.present ? name.value : this.name,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
    createdBy: createdBy ?? this.createdBy,
    lastMessageAt: lastMessageAt.present
        ? lastMessageAt.value
        : this.lastMessageAt,
    createdAt: createdAt ?? this.createdAt,
    lastMessageContent: lastMessageContent.present
        ? lastMessageContent.value
        : this.lastMessageContent,
    lastMessageSenderId: lastMessageSenderId.present
        ? lastMessageSenderId.value
        : this.lastMessageSenderId,
    unreadCount: unreadCount ?? this.unreadCount,
    unreadMentionCount: unreadMentionCount ?? this.unreadMentionCount,
    otherMemberName: otherMemberName.present
        ? otherMemberName.value
        : this.otherMemberName,
    otherMemberAvatar: otherMemberAvatar.present
        ? otherMemberAvatar.value
        : this.otherMemberAvatar,
    otherMemberLastSeenAt: otherMemberLastSeenAt.present
        ? otherMemberLastSeenAt.value
        : this.otherMemberLastSeenAt,
    lastViewedAt: lastViewedAt.present ? lastViewedAt.value : this.lastViewedAt,
  );
  LocalConversation copyWithCompanion(LocalConversationsCompanion data) {
    return LocalConversation(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      lastMessageAt: data.lastMessageAt.present
          ? data.lastMessageAt.value
          : this.lastMessageAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastMessageContent: data.lastMessageContent.present
          ? data.lastMessageContent.value
          : this.lastMessageContent,
      lastMessageSenderId: data.lastMessageSenderId.present
          ? data.lastMessageSenderId.value
          : this.lastMessageSenderId,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      unreadMentionCount: data.unreadMentionCount.present
          ? data.unreadMentionCount.value
          : this.unreadMentionCount,
      otherMemberName: data.otherMemberName.present
          ? data.otherMemberName.value
          : this.otherMemberName,
      otherMemberAvatar: data.otherMemberAvatar.present
          ? data.otherMemberAvatar.value
          : this.otherMemberAvatar,
      otherMemberLastSeenAt: data.otherMemberLastSeenAt.present
          ? data.otherMemberLastSeenAt.value
          : this.otherMemberLastSeenAt,
      lastViewedAt: data.lastViewedAt.present
          ? data.lastViewedAt.value
          : this.lastViewedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalConversation(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('createdBy: $createdBy, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastMessageContent: $lastMessageContent, ')
          ..write('lastMessageSenderId: $lastMessageSenderId, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('unreadMentionCount: $unreadMentionCount, ')
          ..write('otherMemberName: $otherMemberName, ')
          ..write('otherMemberAvatar: $otherMemberAvatar, ')
          ..write('otherMemberLastSeenAt: $otherMemberLastSeenAt, ')
          ..write('lastViewedAt: $lastViewedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    name,
    avatarUrl,
    createdBy,
    lastMessageAt,
    createdAt,
    lastMessageContent,
    lastMessageSenderId,
    unreadCount,
    unreadMentionCount,
    otherMemberName,
    otherMemberAvatar,
    otherMemberLastSeenAt,
    lastViewedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalConversation &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.avatarUrl == this.avatarUrl &&
          other.createdBy == this.createdBy &&
          other.lastMessageAt == this.lastMessageAt &&
          other.createdAt == this.createdAt &&
          other.lastMessageContent == this.lastMessageContent &&
          other.lastMessageSenderId == this.lastMessageSenderId &&
          other.unreadCount == this.unreadCount &&
          other.unreadMentionCount == this.unreadMentionCount &&
          other.otherMemberName == this.otherMemberName &&
          other.otherMemberAvatar == this.otherMemberAvatar &&
          other.otherMemberLastSeenAt == this.otherMemberLastSeenAt &&
          other.lastViewedAt == this.lastViewedAt);
}

class LocalConversationsCompanion extends UpdateCompanion<LocalConversation> {
  final Value<String> id;
  final Value<String> type;
  final Value<String?> name;
  final Value<String?> avatarUrl;
  final Value<String> createdBy;
  final Value<DateTime?> lastMessageAt;
  final Value<DateTime> createdAt;
  final Value<String?> lastMessageContent;
  final Value<String?> lastMessageSenderId;
  final Value<int> unreadCount;
  final Value<int> unreadMentionCount;
  final Value<String?> otherMemberName;
  final Value<String?> otherMemberAvatar;
  final Value<DateTime?> otherMemberLastSeenAt;
  final Value<DateTime?> lastViewedAt;
  final Value<int> rowid;
  const LocalConversationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastMessageContent = const Value.absent(),
    this.lastMessageSenderId = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.unreadMentionCount = const Value.absent(),
    this.otherMemberName = const Value.absent(),
    this.otherMemberAvatar = const Value.absent(),
    this.otherMemberLastSeenAt = const Value.absent(),
    this.lastViewedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalConversationsCompanion.insert({
    required String id,
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    required String createdBy,
    this.lastMessageAt = const Value.absent(),
    required DateTime createdAt,
    this.lastMessageContent = const Value.absent(),
    this.lastMessageSenderId = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.unreadMentionCount = const Value.absent(),
    this.otherMemberName = const Value.absent(),
    this.otherMemberAvatar = const Value.absent(),
    this.otherMemberLastSeenAt = const Value.absent(),
    this.lastViewedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdBy = Value(createdBy),
       createdAt = Value(createdAt);
  static Insertable<LocalConversation> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? name,
    Expression<String>? avatarUrl,
    Expression<String>? createdBy,
    Expression<DateTime>? lastMessageAt,
    Expression<DateTime>? createdAt,
    Expression<String>? lastMessageContent,
    Expression<String>? lastMessageSenderId,
    Expression<int>? unreadCount,
    Expression<int>? unreadMentionCount,
    Expression<String>? otherMemberName,
    Expression<String>? otherMemberAvatar,
    Expression<DateTime>? otherMemberLastSeenAt,
    Expression<DateTime>? lastViewedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (createdBy != null) 'created_by': createdBy,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt,
      if (createdAt != null) 'created_at': createdAt,
      if (lastMessageContent != null)
        'last_message_content': lastMessageContent,
      if (lastMessageSenderId != null)
        'last_message_sender_id': lastMessageSenderId,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (unreadMentionCount != null)
        'unread_mention_count': unreadMentionCount,
      if (otherMemberName != null) 'other_member_name': otherMemberName,
      if (otherMemberAvatar != null) 'other_member_avatar': otherMemberAvatar,
      if (otherMemberLastSeenAt != null)
        'other_member_last_seen_at': otherMemberLastSeenAt,
      if (lastViewedAt != null) 'last_viewed_at': lastViewedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String?>? name,
    Value<String?>? avatarUrl,
    Value<String>? createdBy,
    Value<DateTime?>? lastMessageAt,
    Value<DateTime>? createdAt,
    Value<String?>? lastMessageContent,
    Value<String?>? lastMessageSenderId,
    Value<int>? unreadCount,
    Value<int>? unreadMentionCount,
    Value<String?>? otherMemberName,
    Value<String?>? otherMemberAvatar,
    Value<DateTime?>? otherMemberLastSeenAt,
    Value<DateTime?>? lastViewedAt,
    Value<int>? rowid,
  }) {
    return LocalConversationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdBy: createdBy ?? this.createdBy,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      unreadMentionCount: unreadMentionCount ?? this.unreadMentionCount,
      otherMemberName: otherMemberName ?? this.otherMemberName,
      otherMemberAvatar: otherMemberAvatar ?? this.otherMemberAvatar,
      otherMemberLastSeenAt:
          otherMemberLastSeenAt ?? this.otherMemberLastSeenAt,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (lastMessageAt.present) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastMessageContent.present) {
      map['last_message_content'] = Variable<String>(lastMessageContent.value);
    }
    if (lastMessageSenderId.present) {
      map['last_message_sender_id'] = Variable<String>(
        lastMessageSenderId.value,
      );
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (unreadMentionCount.present) {
      map['unread_mention_count'] = Variable<int>(unreadMentionCount.value);
    }
    if (otherMemberName.present) {
      map['other_member_name'] = Variable<String>(otherMemberName.value);
    }
    if (otherMemberAvatar.present) {
      map['other_member_avatar'] = Variable<String>(otherMemberAvatar.value);
    }
    if (otherMemberLastSeenAt.present) {
      map['other_member_last_seen_at'] = Variable<DateTime>(
        otherMemberLastSeenAt.value,
      );
    }
    if (lastViewedAt.present) {
      map['last_viewed_at'] = Variable<DateTime>(lastViewedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalConversationsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('createdBy: $createdBy, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastMessageContent: $lastMessageContent, ')
          ..write('lastMessageSenderId: $lastMessageSenderId, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('unreadMentionCount: $unreadMentionCount, ')
          ..write('otherMemberName: $otherMemberName, ')
          ..write('otherMemberAvatar: $otherMemberAvatar, ')
          ..write('otherMemberLastSeenAt: $otherMemberLastSeenAt, ')
          ..write('lastViewedAt: $lastViewedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalMessagesTable extends LocalMessages
    with TableInfo<$LocalMessagesTable, LocalMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _convIdMeta = const VerificationMeta('convId');
  @override
  late final GeneratedColumn<String> convId = GeneratedColumn<String>(
    'conv_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToIdMeta = const VerificationMeta(
    'replyToId',
  );
  @override
  late final GeneratedColumn<String> replyToId = GeneratedColumn<String>(
    'reply_to_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editedAtMeta = const VerificationMeta(
    'editedAt',
  );
  @override
  late final GeneratedColumn<DateTime> editedAt = GeneratedColumn<DateTime>(
    'edited_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('sent'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _forwardedFromIdMeta = const VerificationMeta(
    'forwardedFromId',
  );
  @override
  late final GeneratedColumn<String> forwardedFromId = GeneratedColumn<String>(
    'forwarded_from_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _forwardedFromSenderMeta =
      const VerificationMeta('forwardedFromSender');
  @override
  late final GeneratedColumn<String> forwardedFromSender =
      GeneratedColumn<String>(
        'forwarded_from_sender',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    convId,
    senderId,
    type,
    content,
    replyToId,
    metadata,
    createdAt,
    editedAt,
    deletedAt,
    status,
    retryCount,
    forwardedFromId,
    forwardedFromSender,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conv_id')) {
      context.handle(
        _convIdMeta,
        convId.isAcceptableOrUnknown(data['conv_id']!, _convIdMeta),
      );
    } else if (isInserting) {
      context.missing(_convIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
        _replyToIdMeta,
        replyToId.isAcceptableOrUnknown(data['reply_to_id']!, _replyToIdMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('edited_at')) {
      context.handle(
        _editedAtMeta,
        editedAt.isAcceptableOrUnknown(data['edited_at']!, _editedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('forwarded_from_id')) {
      context.handle(
        _forwardedFromIdMeta,
        forwardedFromId.isAcceptableOrUnknown(
          data['forwarded_from_id']!,
          _forwardedFromIdMeta,
        ),
      );
    }
    if (data.containsKey('forwarded_from_sender')) {
      context.handle(
        _forwardedFromSenderMeta,
        forwardedFromSender.isAcceptableOrUnknown(
          data['forwarded_from_sender']!,
          _forwardedFromSenderMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      convId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conv_id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      replyToId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_id'],
      ),
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      editedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}edited_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      forwardedFromId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}forwarded_from_id'],
      ),
      forwardedFromSender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}forwarded_from_sender'],
      ),
    );
  }

  @override
  $LocalMessagesTable createAlias(String alias) {
    return $LocalMessagesTable(attachedDatabase, alias);
  }
}

class LocalMessage extends DataClass implements Insertable<LocalMessage> {
  final String id;
  final String convId;
  final String senderId;
  final String type;
  final String? content;
  final String? replyToId;
  final String? metadata;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String status;
  final int retryCount;
  final String? forwardedFromId;
  final String? forwardedFromSender;
  const LocalMessage({
    required this.id,
    required this.convId,
    required this.senderId,
    required this.type,
    this.content,
    this.replyToId,
    this.metadata,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    required this.status,
    required this.retryCount,
    this.forwardedFromId,
    this.forwardedFromSender,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conv_id'] = Variable<String>(convId);
    map['sender_id'] = Variable<String>(senderId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<String>(replyToId);
    }
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || editedAt != null) {
      map['edited_at'] = Variable<DateTime>(editedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || forwardedFromId != null) {
      map['forwarded_from_id'] = Variable<String>(forwardedFromId);
    }
    if (!nullToAbsent || forwardedFromSender != null) {
      map['forwarded_from_sender'] = Variable<String>(forwardedFromSender);
    }
    return map;
  }

  LocalMessagesCompanion toCompanion(bool nullToAbsent) {
    return LocalMessagesCompanion(
      id: Value(id),
      convId: Value(convId),
      senderId: Value(senderId),
      type: Value(type),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      createdAt: Value(createdAt),
      editedAt: editedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(editedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      status: Value(status),
      retryCount: Value(retryCount),
      forwardedFromId: forwardedFromId == null && nullToAbsent
          ? const Value.absent()
          : Value(forwardedFromId),
      forwardedFromSender: forwardedFromSender == null && nullToAbsent
          ? const Value.absent()
          : Value(forwardedFromSender),
    );
  }

  factory LocalMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMessage(
      id: serializer.fromJson<String>(json['id']),
      convId: serializer.fromJson<String>(json['convId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      type: serializer.fromJson<String>(json['type']),
      content: serializer.fromJson<String?>(json['content']),
      replyToId: serializer.fromJson<String?>(json['replyToId']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      editedAt: serializer.fromJson<DateTime?>(json['editedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      forwardedFromId: serializer.fromJson<String?>(json['forwardedFromId']),
      forwardedFromSender: serializer.fromJson<String?>(
        json['forwardedFromSender'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'convId': serializer.toJson<String>(convId),
      'senderId': serializer.toJson<String>(senderId),
      'type': serializer.toJson<String>(type),
      'content': serializer.toJson<String?>(content),
      'replyToId': serializer.toJson<String?>(replyToId),
      'metadata': serializer.toJson<String?>(metadata),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'editedAt': serializer.toJson<DateTime?>(editedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'forwardedFromId': serializer.toJson<String?>(forwardedFromId),
      'forwardedFromSender': serializer.toJson<String?>(forwardedFromSender),
    };
  }

  LocalMessage copyWith({
    String? id,
    String? convId,
    String? senderId,
    String? type,
    Value<String?> content = const Value.absent(),
    Value<String?> replyToId = const Value.absent(),
    Value<String?> metadata = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> editedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    String? status,
    int? retryCount,
    Value<String?> forwardedFromId = const Value.absent(),
    Value<String?> forwardedFromSender = const Value.absent(),
  }) => LocalMessage(
    id: id ?? this.id,
    convId: convId ?? this.convId,
    senderId: senderId ?? this.senderId,
    type: type ?? this.type,
    content: content.present ? content.value : this.content,
    replyToId: replyToId.present ? replyToId.value : this.replyToId,
    metadata: metadata.present ? metadata.value : this.metadata,
    createdAt: createdAt ?? this.createdAt,
    editedAt: editedAt.present ? editedAt.value : this.editedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    forwardedFromId: forwardedFromId.present
        ? forwardedFromId.value
        : this.forwardedFromId,
    forwardedFromSender: forwardedFromSender.present
        ? forwardedFromSender.value
        : this.forwardedFromSender,
  );
  LocalMessage copyWithCompanion(LocalMessagesCompanion data) {
    return LocalMessage(
      id: data.id.present ? data.id.value : this.id,
      convId: data.convId.present ? data.convId.value : this.convId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      type: data.type.present ? data.type.value : this.type,
      content: data.content.present ? data.content.value : this.content,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      editedAt: data.editedAt.present ? data.editedAt.value : this.editedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      forwardedFromId: data.forwardedFromId.present
          ? data.forwardedFromId.value
          : this.forwardedFromId,
      forwardedFromSender: data.forwardedFromSender.present
          ? data.forwardedFromSender.value
          : this.forwardedFromSender,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessage(')
          ..write('id: $id, ')
          ..write('convId: $convId, ')
          ..write('senderId: $senderId, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('replyToId: $replyToId, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt, ')
          ..write('editedAt: $editedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('forwardedFromId: $forwardedFromId, ')
          ..write('forwardedFromSender: $forwardedFromSender')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    convId,
    senderId,
    type,
    content,
    replyToId,
    metadata,
    createdAt,
    editedAt,
    deletedAt,
    status,
    retryCount,
    forwardedFromId,
    forwardedFromSender,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMessage &&
          other.id == this.id &&
          other.convId == this.convId &&
          other.senderId == this.senderId &&
          other.type == this.type &&
          other.content == this.content &&
          other.replyToId == this.replyToId &&
          other.metadata == this.metadata &&
          other.createdAt == this.createdAt &&
          other.editedAt == this.editedAt &&
          other.deletedAt == this.deletedAt &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.forwardedFromId == this.forwardedFromId &&
          other.forwardedFromSender == this.forwardedFromSender);
}

class LocalMessagesCompanion extends UpdateCompanion<LocalMessage> {
  final Value<String> id;
  final Value<String> convId;
  final Value<String> senderId;
  final Value<String> type;
  final Value<String?> content;
  final Value<String?> replyToId;
  final Value<String?> metadata;
  final Value<DateTime> createdAt;
  final Value<DateTime?> editedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<String?> forwardedFromId;
  final Value<String?> forwardedFromSender;
  final Value<int> rowid;
  const LocalMessagesCompanion({
    this.id = const Value.absent(),
    this.convId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.type = const Value.absent(),
    this.content = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.metadata = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.editedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.forwardedFromId = const Value.absent(),
    this.forwardedFromSender = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMessagesCompanion.insert({
    required String id,
    required String convId,
    required String senderId,
    this.type = const Value.absent(),
    this.content = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.metadata = const Value.absent(),
    required DateTime createdAt,
    this.editedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.forwardedFromId = const Value.absent(),
    this.forwardedFromSender = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       convId = Value(convId),
       senderId = Value(senderId),
       createdAt = Value(createdAt);
  static Insertable<LocalMessage> custom({
    Expression<String>? id,
    Expression<String>? convId,
    Expression<String>? senderId,
    Expression<String>? type,
    Expression<String>? content,
    Expression<String>? replyToId,
    Expression<String>? metadata,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? editedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<String>? forwardedFromId,
    Expression<String>? forwardedFromSender,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (convId != null) 'conv_id': convId,
      if (senderId != null) 'sender_id': senderId,
      if (type != null) 'type': type,
      if (content != null) 'content': content,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (metadata != null) 'metadata': metadata,
      if (createdAt != null) 'created_at': createdAt,
      if (editedAt != null) 'edited_at': editedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (forwardedFromId != null) 'forwarded_from_id': forwardedFromId,
      if (forwardedFromSender != null)
        'forwarded_from_sender': forwardedFromSender,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? convId,
    Value<String>? senderId,
    Value<String>? type,
    Value<String?>? content,
    Value<String?>? replyToId,
    Value<String?>? metadata,
    Value<DateTime>? createdAt,
    Value<DateTime?>? editedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? status,
    Value<int>? retryCount,
    Value<String?>? forwardedFromId,
    Value<String?>? forwardedFromSender,
    Value<int>? rowid,
  }) {
    return LocalMessagesCompanion(
      id: id ?? this.id,
      convId: convId ?? this.convId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      content: content ?? this.content,
      replyToId: replyToId ?? this.replyToId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      forwardedFromId: forwardedFromId ?? this.forwardedFromId,
      forwardedFromSender: forwardedFromSender ?? this.forwardedFromSender,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (convId.present) {
      map['conv_id'] = Variable<String>(convId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<String>(replyToId.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (editedAt.present) {
      map['edited_at'] = Variable<DateTime>(editedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (forwardedFromId.present) {
      map['forwarded_from_id'] = Variable<String>(forwardedFromId.value);
    }
    if (forwardedFromSender.present) {
      map['forwarded_from_sender'] = Variable<String>(
        forwardedFromSender.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessagesCompanion(')
          ..write('id: $id, ')
          ..write('convId: $convId, ')
          ..write('senderId: $senderId, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('replyToId: $replyToId, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt, ')
          ..write('editedAt: $editedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('forwardedFromId: $forwardedFromId, ')
          ..write('forwardedFromSender: $forwardedFromSender, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingUploadsTable extends PendingUploads
    with TableInfo<$PendingUploadsTable, PendingUpload> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingUploadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _convIdMeta = const VerificationMeta('convId');
  @override
  late final GeneratedColumn<String> convId = GeneratedColumn<String>(
    'conv_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathsMeta = const VerificationMeta(
    'localPaths',
  );
  @override
  late final GeneratedColumn<String> localPaths = GeneratedColumn<String>(
    'local_paths',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    convId,
    localPaths,
    caption,
    status,
    retryCount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_uploads';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingUpload> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conv_id')) {
      context.handle(
        _convIdMeta,
        convId.isAcceptableOrUnknown(data['conv_id']!, _convIdMeta),
      );
    } else if (isInserting) {
      context.missing(_convIdMeta);
    }
    if (data.containsKey('local_paths')) {
      context.handle(
        _localPathsMeta,
        localPaths.isAcceptableOrUnknown(data['local_paths']!, _localPathsMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathsMeta);
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingUpload map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingUpload(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      convId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conv_id'],
      )!,
      localPaths: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_paths'],
      )!,
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingUploadsTable createAlias(String alias) {
    return $PendingUploadsTable(attachedDatabase, alias);
  }
}

class PendingUpload extends DataClass implements Insertable<PendingUpload> {
  final String id;
  final String convId;
  final String localPaths;
  final String? caption;
  final String status;
  final int retryCount;
  final DateTime createdAt;
  const PendingUpload({
    required this.id,
    required this.convId,
    required this.localPaths,
    this.caption,
    required this.status,
    required this.retryCount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conv_id'] = Variable<String>(convId);
    map['local_paths'] = Variable<String>(localPaths);
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingUploadsCompanion toCompanion(bool nullToAbsent) {
    return PendingUploadsCompanion(
      id: Value(id),
      convId: Value(convId),
      localPaths: Value(localPaths),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      status: Value(status),
      retryCount: Value(retryCount),
      createdAt: Value(createdAt),
    );
  }

  factory PendingUpload.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingUpload(
      id: serializer.fromJson<String>(json['id']),
      convId: serializer.fromJson<String>(json['convId']),
      localPaths: serializer.fromJson<String>(json['localPaths']),
      caption: serializer.fromJson<String?>(json['caption']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'convId': serializer.toJson<String>(convId),
      'localPaths': serializer.toJson<String>(localPaths),
      'caption': serializer.toJson<String?>(caption),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingUpload copyWith({
    String? id,
    String? convId,
    String? localPaths,
    Value<String?> caption = const Value.absent(),
    String? status,
    int? retryCount,
    DateTime? createdAt,
  }) => PendingUpload(
    id: id ?? this.id,
    convId: convId ?? this.convId,
    localPaths: localPaths ?? this.localPaths,
    caption: caption.present ? caption.value : this.caption,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingUpload copyWithCompanion(PendingUploadsCompanion data) {
    return PendingUpload(
      id: data.id.present ? data.id.value : this.id,
      convId: data.convId.present ? data.convId.value : this.convId,
      localPaths: data.localPaths.present
          ? data.localPaths.value
          : this.localPaths,
      caption: data.caption.present ? data.caption.value : this.caption,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingUpload(')
          ..write('id: $id, ')
          ..write('convId: $convId, ')
          ..write('localPaths: $localPaths, ')
          ..write('caption: $caption, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    convId,
    localPaths,
    caption,
    status,
    retryCount,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingUpload &&
          other.id == this.id &&
          other.convId == this.convId &&
          other.localPaths == this.localPaths &&
          other.caption == this.caption &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.createdAt == this.createdAt);
}

class PendingUploadsCompanion extends UpdateCompanion<PendingUpload> {
  final Value<String> id;
  final Value<String> convId;
  final Value<String> localPaths;
  final Value<String?> caption;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PendingUploadsCompanion({
    this.id = const Value.absent(),
    this.convId = const Value.absent(),
    this.localPaths = const Value.absent(),
    this.caption = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingUploadsCompanion.insert({
    required String id,
    required String convId,
    required String localPaths,
    this.caption = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       convId = Value(convId),
       localPaths = Value(localPaths),
       createdAt = Value(createdAt);
  static Insertable<PendingUpload> custom({
    Expression<String>? id,
    Expression<String>? convId,
    Expression<String>? localPaths,
    Expression<String>? caption,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (convId != null) 'conv_id': convId,
      if (localPaths != null) 'local_paths': localPaths,
      if (caption != null) 'caption': caption,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingUploadsCompanion copyWith({
    Value<String>? id,
    Value<String>? convId,
    Value<String>? localPaths,
    Value<String?>? caption,
    Value<String>? status,
    Value<int>? retryCount,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PendingUploadsCompanion(
      id: id ?? this.id,
      convId: convId ?? this.convId,
      localPaths: localPaths ?? this.localPaths,
      caption: caption ?? this.caption,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (convId.present) {
      map['conv_id'] = Variable<String>(convId.value);
    }
    if (localPaths.present) {
      map['local_paths'] = Variable<String>(localPaths.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingUploadsCompanion(')
          ..write('id: $id, ')
          ..write('convId: $convId, ')
          ..write('localPaths: $localPaths, ')
          ..write('caption: $caption, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalMessageReactionsTable extends LocalMessageReactions
    with TableInfo<$LocalMessageReactionsTable, LocalMessageReaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMessageReactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userNameMeta = const VerificationMeta(
    'userName',
  );
  @override
  late final GeneratedColumn<String> userName = GeneratedColumn<String>(
    'user_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    userId,
    emoji,
    userName,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_message_reactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMessageReaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('user_name')) {
      context.handle(
        _userNameMeta,
        userName.isAcceptableOrUnknown(data['user_name']!, _userNameMeta),
      );
    } else if (isInserting) {
      context.missing(_userNameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, userId, emoji};
  @override
  LocalMessageReaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMessageReaction(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      userName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalMessageReactionsTable createAlias(String alias) {
    return $LocalMessageReactionsTable(attachedDatabase, alias);
  }
}

class LocalMessageReaction extends DataClass
    implements Insertable<LocalMessageReaction> {
  final String messageId;
  final String userId;
  final String emoji;
  final String userName;
  final DateTime createdAt;
  const LocalMessageReaction({
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.userName,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['user_id'] = Variable<String>(userId);
    map['emoji'] = Variable<String>(emoji);
    map['user_name'] = Variable<String>(userName);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalMessageReactionsCompanion toCompanion(bool nullToAbsent) {
    return LocalMessageReactionsCompanion(
      messageId: Value(messageId),
      userId: Value(userId),
      emoji: Value(emoji),
      userName: Value(userName),
      createdAt: Value(createdAt),
    );
  }

  factory LocalMessageReaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMessageReaction(
      messageId: serializer.fromJson<String>(json['messageId']),
      userId: serializer.fromJson<String>(json['userId']),
      emoji: serializer.fromJson<String>(json['emoji']),
      userName: serializer.fromJson<String>(json['userName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'userId': serializer.toJson<String>(userId),
      'emoji': serializer.toJson<String>(emoji),
      'userName': serializer.toJson<String>(userName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalMessageReaction copyWith({
    String? messageId,
    String? userId,
    String? emoji,
    String? userName,
    DateTime? createdAt,
  }) => LocalMessageReaction(
    messageId: messageId ?? this.messageId,
    userId: userId ?? this.userId,
    emoji: emoji ?? this.emoji,
    userName: userName ?? this.userName,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalMessageReaction copyWithCompanion(LocalMessageReactionsCompanion data) {
    return LocalMessageReaction(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      userId: data.userId.present ? data.userId.value : this.userId,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      userName: data.userName.present ? data.userName.value : this.userName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessageReaction(')
          ..write('messageId: $messageId, ')
          ..write('userId: $userId, ')
          ..write('emoji: $emoji, ')
          ..write('userName: $userName, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(messageId, userId, emoji, userName, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMessageReaction &&
          other.messageId == this.messageId &&
          other.userId == this.userId &&
          other.emoji == this.emoji &&
          other.userName == this.userName &&
          other.createdAt == this.createdAt);
}

class LocalMessageReactionsCompanion
    extends UpdateCompanion<LocalMessageReaction> {
  final Value<String> messageId;
  final Value<String> userId;
  final Value<String> emoji;
  final Value<String> userName;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalMessageReactionsCompanion({
    this.messageId = const Value.absent(),
    this.userId = const Value.absent(),
    this.emoji = const Value.absent(),
    this.userName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMessageReactionsCompanion.insert({
    required String messageId,
    required String userId,
    required String emoji,
    required String userName,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       userId = Value(userId),
       emoji = Value(emoji),
       userName = Value(userName),
       createdAt = Value(createdAt);
  static Insertable<LocalMessageReaction> custom({
    Expression<String>? messageId,
    Expression<String>? userId,
    Expression<String>? emoji,
    Expression<String>? userName,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (userId != null) 'user_id': userId,
      if (emoji != null) 'emoji': emoji,
      if (userName != null) 'user_name': userName,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMessageReactionsCompanion copyWith({
    Value<String>? messageId,
    Value<String>? userId,
    Value<String>? emoji,
    Value<String>? userName,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalMessageReactionsCompanion(
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      emoji: emoji ?? this.emoji,
      userName: userName ?? this.userName,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (userName.present) {
      map['user_name'] = Variable<String>(userName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessageReactionsCompanion(')
          ..write('messageId: $messageId, ')
          ..write('userId: $userId, ')
          ..write('emoji: $emoji, ')
          ..write('userName: $userName, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalPinnedMessagesTable extends LocalPinnedMessages
    with TableInfo<$LocalPinnedMessagesTable, LocalPinnedMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPinnedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _convIdMeta = const VerificationMeta('convId');
  @override
  late final GeneratedColumn<String> convId = GeneratedColumn<String>(
    'conv_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedByMeta = const VerificationMeta(
    'pinnedBy',
  );
  @override
  late final GeneratedColumn<String> pinnedBy = GeneratedColumn<String>(
    'pinned_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedAtMeta = const VerificationMeta(
    'pinnedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pinnedAt = GeneratedColumn<DateTime>(
    'pinned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [convId, messageId, pinnedBy, pinnedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_pinned_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPinnedMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('conv_id')) {
      context.handle(
        _convIdMeta,
        convId.isAcceptableOrUnknown(data['conv_id']!, _convIdMeta),
      );
    } else if (isInserting) {
      context.missing(_convIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('pinned_by')) {
      context.handle(
        _pinnedByMeta,
        pinnedBy.isAcceptableOrUnknown(data['pinned_by']!, _pinnedByMeta),
      );
    } else if (isInserting) {
      context.missing(_pinnedByMeta);
    }
    if (data.containsKey('pinned_at')) {
      context.handle(
        _pinnedAtMeta,
        pinnedAt.isAcceptableOrUnknown(data['pinned_at']!, _pinnedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_pinnedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {convId, messageId};
  @override
  LocalPinnedMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPinnedMessage(
      convId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conv_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      pinnedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pinned_by'],
      )!,
      pinnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}pinned_at'],
      )!,
    );
  }

  @override
  $LocalPinnedMessagesTable createAlias(String alias) {
    return $LocalPinnedMessagesTable(attachedDatabase, alias);
  }
}

class LocalPinnedMessage extends DataClass
    implements Insertable<LocalPinnedMessage> {
  final String convId;
  final String messageId;
  final String pinnedBy;
  final DateTime pinnedAt;
  const LocalPinnedMessage({
    required this.convId,
    required this.messageId,
    required this.pinnedBy,
    required this.pinnedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conv_id'] = Variable<String>(convId);
    map['message_id'] = Variable<String>(messageId);
    map['pinned_by'] = Variable<String>(pinnedBy);
    map['pinned_at'] = Variable<DateTime>(pinnedAt);
    return map;
  }

  LocalPinnedMessagesCompanion toCompanion(bool nullToAbsent) {
    return LocalPinnedMessagesCompanion(
      convId: Value(convId),
      messageId: Value(messageId),
      pinnedBy: Value(pinnedBy),
      pinnedAt: Value(pinnedAt),
    );
  }

  factory LocalPinnedMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPinnedMessage(
      convId: serializer.fromJson<String>(json['convId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      pinnedBy: serializer.fromJson<String>(json['pinnedBy']),
      pinnedAt: serializer.fromJson<DateTime>(json['pinnedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'convId': serializer.toJson<String>(convId),
      'messageId': serializer.toJson<String>(messageId),
      'pinnedBy': serializer.toJson<String>(pinnedBy),
      'pinnedAt': serializer.toJson<DateTime>(pinnedAt),
    };
  }

  LocalPinnedMessage copyWith({
    String? convId,
    String? messageId,
    String? pinnedBy,
    DateTime? pinnedAt,
  }) => LocalPinnedMessage(
    convId: convId ?? this.convId,
    messageId: messageId ?? this.messageId,
    pinnedBy: pinnedBy ?? this.pinnedBy,
    pinnedAt: pinnedAt ?? this.pinnedAt,
  );
  LocalPinnedMessage copyWithCompanion(LocalPinnedMessagesCompanion data) {
    return LocalPinnedMessage(
      convId: data.convId.present ? data.convId.value : this.convId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      pinnedBy: data.pinnedBy.present ? data.pinnedBy.value : this.pinnedBy,
      pinnedAt: data.pinnedAt.present ? data.pinnedAt.value : this.pinnedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPinnedMessage(')
          ..write('convId: $convId, ')
          ..write('messageId: $messageId, ')
          ..write('pinnedBy: $pinnedBy, ')
          ..write('pinnedAt: $pinnedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(convId, messageId, pinnedBy, pinnedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPinnedMessage &&
          other.convId == this.convId &&
          other.messageId == this.messageId &&
          other.pinnedBy == this.pinnedBy &&
          other.pinnedAt == this.pinnedAt);
}

class LocalPinnedMessagesCompanion extends UpdateCompanion<LocalPinnedMessage> {
  final Value<String> convId;
  final Value<String> messageId;
  final Value<String> pinnedBy;
  final Value<DateTime> pinnedAt;
  final Value<int> rowid;
  const LocalPinnedMessagesCompanion({
    this.convId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.pinnedBy = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPinnedMessagesCompanion.insert({
    required String convId,
    required String messageId,
    required String pinnedBy,
    required DateTime pinnedAt,
    this.rowid = const Value.absent(),
  }) : convId = Value(convId),
       messageId = Value(messageId),
       pinnedBy = Value(pinnedBy),
       pinnedAt = Value(pinnedAt);
  static Insertable<LocalPinnedMessage> custom({
    Expression<String>? convId,
    Expression<String>? messageId,
    Expression<String>? pinnedBy,
    Expression<DateTime>? pinnedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (convId != null) 'conv_id': convId,
      if (messageId != null) 'message_id': messageId,
      if (pinnedBy != null) 'pinned_by': pinnedBy,
      if (pinnedAt != null) 'pinned_at': pinnedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPinnedMessagesCompanion copyWith({
    Value<String>? convId,
    Value<String>? messageId,
    Value<String>? pinnedBy,
    Value<DateTime>? pinnedAt,
    Value<int>? rowid,
  }) {
    return LocalPinnedMessagesCompanion(
      convId: convId ?? this.convId,
      messageId: messageId ?? this.messageId,
      pinnedBy: pinnedBy ?? this.pinnedBy,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (convId.present) {
      map['conv_id'] = Variable<String>(convId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (pinnedBy.present) {
      map['pinned_by'] = Variable<String>(pinnedBy.value);
    }
    if (pinnedAt.present) {
      map['pinned_at'] = Variable<DateTime>(pinnedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPinnedMessagesCompanion(')
          ..write('convId: $convId, ')
          ..write('messageId: $messageId, ')
          ..write('pinnedBy: $pinnedBy, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalBookmarkedMessagesTable extends LocalBookmarkedMessages
    with TableInfo<$LocalBookmarkedMessagesTable, LocalBookmarkedMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBookmarkedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _convIdMeta = const VerificationMeta('convId');
  @override
  late final GeneratedColumn<String> convId = GeneratedColumn<String>(
    'conv_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markedAtMeta = const VerificationMeta(
    'markedAt',
  );
  @override
  late final GeneratedColumn<DateTime> markedAt = GeneratedColumn<DateTime>(
    'marked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageContentMeta = const VerificationMeta(
    'messageContent',
  );
  @override
  late final GeneratedColumn<String> messageContent = GeneratedColumn<String>(
    'message_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _messageTypeMeta = const VerificationMeta(
    'messageType',
  );
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
    'message_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderNameMeta = const VerificationMeta(
    'senderName',
  );
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
    'sender_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _messageCreatedAtMeta = const VerificationMeta(
    'messageCreatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> messageCreatedAt =
      GeneratedColumn<DateTime>(
        'message_created_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    convId,
    messageId,
    userId,
    markedAt,
    messageContent,
    messageType,
    senderId,
    senderName,
    messageCreatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_bookmarked_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalBookmarkedMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('conv_id')) {
      context.handle(
        _convIdMeta,
        convId.isAcceptableOrUnknown(data['conv_id']!, _convIdMeta),
      );
    } else if (isInserting) {
      context.missing(_convIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('marked_at')) {
      context.handle(
        _markedAtMeta,
        markedAt.isAcceptableOrUnknown(data['marked_at']!, _markedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_markedAtMeta);
    }
    if (data.containsKey('message_content')) {
      context.handle(
        _messageContentMeta,
        messageContent.isAcceptableOrUnknown(
          data['message_content']!,
          _messageContentMeta,
        ),
      );
    }
    if (data.containsKey('message_type')) {
      context.handle(
        _messageTypeMeta,
        messageType.isAcceptableOrUnknown(
          data['message_type']!,
          _messageTypeMeta,
        ),
      );
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    }
    if (data.containsKey('sender_name')) {
      context.handle(
        _senderNameMeta,
        senderName.isAcceptableOrUnknown(data['sender_name']!, _senderNameMeta),
      );
    }
    if (data.containsKey('message_created_at')) {
      context.handle(
        _messageCreatedAtMeta,
        messageCreatedAt.isAcceptableOrUnknown(
          data['message_created_at']!,
          _messageCreatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {convId, messageId};
  @override
  LocalBookmarkedMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBookmarkedMessage(
      convId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conv_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      markedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}marked_at'],
      )!,
      messageContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_content'],
      ),
      messageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_type'],
      ),
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      ),
      senderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_name'],
      ),
      messageCreatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}message_created_at'],
      ),
    );
  }

  @override
  $LocalBookmarkedMessagesTable createAlias(String alias) {
    return $LocalBookmarkedMessagesTable(attachedDatabase, alias);
  }
}

class LocalBookmarkedMessage extends DataClass
    implements Insertable<LocalBookmarkedMessage> {
  final String convId;
  final String messageId;
  final String userId;
  final DateTime markedAt;
  final String? messageContent;
  final String? messageType;
  final String? senderId;
  final String? senderName;
  final DateTime? messageCreatedAt;
  const LocalBookmarkedMessage({
    required this.convId,
    required this.messageId,
    required this.userId,
    required this.markedAt,
    this.messageContent,
    this.messageType,
    this.senderId,
    this.senderName,
    this.messageCreatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conv_id'] = Variable<String>(convId);
    map['message_id'] = Variable<String>(messageId);
    map['user_id'] = Variable<String>(userId);
    map['marked_at'] = Variable<DateTime>(markedAt);
    if (!nullToAbsent || messageContent != null) {
      map['message_content'] = Variable<String>(messageContent);
    }
    if (!nullToAbsent || messageType != null) {
      map['message_type'] = Variable<String>(messageType);
    }
    if (!nullToAbsent || senderId != null) {
      map['sender_id'] = Variable<String>(senderId);
    }
    if (!nullToAbsent || senderName != null) {
      map['sender_name'] = Variable<String>(senderName);
    }
    if (!nullToAbsent || messageCreatedAt != null) {
      map['message_created_at'] = Variable<DateTime>(messageCreatedAt);
    }
    return map;
  }

  LocalBookmarkedMessagesCompanion toCompanion(bool nullToAbsent) {
    return LocalBookmarkedMessagesCompanion(
      convId: Value(convId),
      messageId: Value(messageId),
      userId: Value(userId),
      markedAt: Value(markedAt),
      messageContent: messageContent == null && nullToAbsent
          ? const Value.absent()
          : Value(messageContent),
      messageType: messageType == null && nullToAbsent
          ? const Value.absent()
          : Value(messageType),
      senderId: senderId == null && nullToAbsent
          ? const Value.absent()
          : Value(senderId),
      senderName: senderName == null && nullToAbsent
          ? const Value.absent()
          : Value(senderName),
      messageCreatedAt: messageCreatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(messageCreatedAt),
    );
  }

  factory LocalBookmarkedMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBookmarkedMessage(
      convId: serializer.fromJson<String>(json['convId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      userId: serializer.fromJson<String>(json['userId']),
      markedAt: serializer.fromJson<DateTime>(json['markedAt']),
      messageContent: serializer.fromJson<String?>(json['messageContent']),
      messageType: serializer.fromJson<String?>(json['messageType']),
      senderId: serializer.fromJson<String?>(json['senderId']),
      senderName: serializer.fromJson<String?>(json['senderName']),
      messageCreatedAt: serializer.fromJson<DateTime?>(
        json['messageCreatedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'convId': serializer.toJson<String>(convId),
      'messageId': serializer.toJson<String>(messageId),
      'userId': serializer.toJson<String>(userId),
      'markedAt': serializer.toJson<DateTime>(markedAt),
      'messageContent': serializer.toJson<String?>(messageContent),
      'messageType': serializer.toJson<String?>(messageType),
      'senderId': serializer.toJson<String?>(senderId),
      'senderName': serializer.toJson<String?>(senderName),
      'messageCreatedAt': serializer.toJson<DateTime?>(messageCreatedAt),
    };
  }

  LocalBookmarkedMessage copyWith({
    String? convId,
    String? messageId,
    String? userId,
    DateTime? markedAt,
    Value<String?> messageContent = const Value.absent(),
    Value<String?> messageType = const Value.absent(),
    Value<String?> senderId = const Value.absent(),
    Value<String?> senderName = const Value.absent(),
    Value<DateTime?> messageCreatedAt = const Value.absent(),
  }) => LocalBookmarkedMessage(
    convId: convId ?? this.convId,
    messageId: messageId ?? this.messageId,
    userId: userId ?? this.userId,
    markedAt: markedAt ?? this.markedAt,
    messageContent: messageContent.present
        ? messageContent.value
        : this.messageContent,
    messageType: messageType.present ? messageType.value : this.messageType,
    senderId: senderId.present ? senderId.value : this.senderId,
    senderName: senderName.present ? senderName.value : this.senderName,
    messageCreatedAt: messageCreatedAt.present
        ? messageCreatedAt.value
        : this.messageCreatedAt,
  );
  LocalBookmarkedMessage copyWithCompanion(
    LocalBookmarkedMessagesCompanion data,
  ) {
    return LocalBookmarkedMessage(
      convId: data.convId.present ? data.convId.value : this.convId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      userId: data.userId.present ? data.userId.value : this.userId,
      markedAt: data.markedAt.present ? data.markedAt.value : this.markedAt,
      messageContent: data.messageContent.present
          ? data.messageContent.value
          : this.messageContent,
      messageType: data.messageType.present
          ? data.messageType.value
          : this.messageType,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      senderName: data.senderName.present
          ? data.senderName.value
          : this.senderName,
      messageCreatedAt: data.messageCreatedAt.present
          ? data.messageCreatedAt.value
          : this.messageCreatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBookmarkedMessage(')
          ..write('convId: $convId, ')
          ..write('messageId: $messageId, ')
          ..write('userId: $userId, ')
          ..write('markedAt: $markedAt, ')
          ..write('messageContent: $messageContent, ')
          ..write('messageType: $messageType, ')
          ..write('senderId: $senderId, ')
          ..write('senderName: $senderName, ')
          ..write('messageCreatedAt: $messageCreatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    convId,
    messageId,
    userId,
    markedAt,
    messageContent,
    messageType,
    senderId,
    senderName,
    messageCreatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBookmarkedMessage &&
          other.convId == this.convId &&
          other.messageId == this.messageId &&
          other.userId == this.userId &&
          other.markedAt == this.markedAt &&
          other.messageContent == this.messageContent &&
          other.messageType == this.messageType &&
          other.senderId == this.senderId &&
          other.senderName == this.senderName &&
          other.messageCreatedAt == this.messageCreatedAt);
}

class LocalBookmarkedMessagesCompanion
    extends UpdateCompanion<LocalBookmarkedMessage> {
  final Value<String> convId;
  final Value<String> messageId;
  final Value<String> userId;
  final Value<DateTime> markedAt;
  final Value<String?> messageContent;
  final Value<String?> messageType;
  final Value<String?> senderId;
  final Value<String?> senderName;
  final Value<DateTime?> messageCreatedAt;
  final Value<int> rowid;
  const LocalBookmarkedMessagesCompanion({
    this.convId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.userId = const Value.absent(),
    this.markedAt = const Value.absent(),
    this.messageContent = const Value.absent(),
    this.messageType = const Value.absent(),
    this.senderId = const Value.absent(),
    this.senderName = const Value.absent(),
    this.messageCreatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalBookmarkedMessagesCompanion.insert({
    required String convId,
    required String messageId,
    required String userId,
    required DateTime markedAt,
    this.messageContent = const Value.absent(),
    this.messageType = const Value.absent(),
    this.senderId = const Value.absent(),
    this.senderName = const Value.absent(),
    this.messageCreatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : convId = Value(convId),
       messageId = Value(messageId),
       userId = Value(userId),
       markedAt = Value(markedAt);
  static Insertable<LocalBookmarkedMessage> custom({
    Expression<String>? convId,
    Expression<String>? messageId,
    Expression<String>? userId,
    Expression<DateTime>? markedAt,
    Expression<String>? messageContent,
    Expression<String>? messageType,
    Expression<String>? senderId,
    Expression<String>? senderName,
    Expression<DateTime>? messageCreatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (convId != null) 'conv_id': convId,
      if (messageId != null) 'message_id': messageId,
      if (userId != null) 'user_id': userId,
      if (markedAt != null) 'marked_at': markedAt,
      if (messageContent != null) 'message_content': messageContent,
      if (messageType != null) 'message_type': messageType,
      if (senderId != null) 'sender_id': senderId,
      if (senderName != null) 'sender_name': senderName,
      if (messageCreatedAt != null) 'message_created_at': messageCreatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalBookmarkedMessagesCompanion copyWith({
    Value<String>? convId,
    Value<String>? messageId,
    Value<String>? userId,
    Value<DateTime>? markedAt,
    Value<String?>? messageContent,
    Value<String?>? messageType,
    Value<String?>? senderId,
    Value<String?>? senderName,
    Value<DateTime?>? messageCreatedAt,
    Value<int>? rowid,
  }) {
    return LocalBookmarkedMessagesCompanion(
      convId: convId ?? this.convId,
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      markedAt: markedAt ?? this.markedAt,
      messageContent: messageContent ?? this.messageContent,
      messageType: messageType ?? this.messageType,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      messageCreatedAt: messageCreatedAt ?? this.messageCreatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (convId.present) {
      map['conv_id'] = Variable<String>(convId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (markedAt.present) {
      map['marked_at'] = Variable<DateTime>(markedAt.value);
    }
    if (messageContent.present) {
      map['message_content'] = Variable<String>(messageContent.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
    }
    if (messageCreatedAt.present) {
      map['message_created_at'] = Variable<DateTime>(messageCreatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBookmarkedMessagesCompanion(')
          ..write('convId: $convId, ')
          ..write('messageId: $messageId, ')
          ..write('userId: $userId, ')
          ..write('markedAt: $markedAt, ')
          ..write('messageContent: $messageContent, ')
          ..write('messageType: $messageType, ')
          ..write('senderId: $senderId, ')
          ..write('senderName: $senderName, ')
          ..write('messageCreatedAt: $messageCreatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAttendanceTable extends LocalAttendance
    with TableInfo<$LocalAttendanceTable, LocalAttendanceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAttendanceTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkinAtMeta = const VerificationMeta(
    'checkinAt',
  );
  @override
  late final GeneratedColumn<DateTime> checkinAt = GeneratedColumn<DateTime>(
    'checkin_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkoutAtMeta = const VerificationMeta(
    'checkoutAt',
  );
  @override
  late final GeneratedColumn<DateTime> checkoutAt = GeneratedColumn<DateTime>(
    'checkout_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkinLatMeta = const VerificationMeta(
    'checkinLat',
  );
  @override
  late final GeneratedColumn<double> checkinLat = GeneratedColumn<double>(
    'checkin_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkinLngMeta = const VerificationMeta(
    'checkinLng',
  );
  @override
  late final GeneratedColumn<double> checkinLng = GeneratedColumn<double>(
    'checkin_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalHoursMeta = const VerificationMeta(
    'totalHours',
  );
  @override
  late final GeneratedColumn<double> totalHours = GeneratedColumn<double>(
    'total_hours',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _otHoursMeta = const VerificationMeta(
    'otHours',
  );
  @override
  late final GeneratedColumn<double> otHours = GeneratedColumn<double>(
    'ot_hours',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending_sync'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    checkinAt,
    checkoutAt,
    checkinLat,
    checkinLng,
    totalHours,
    otHours,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_attendance';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAttendanceData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('checkin_at')) {
      context.handle(
        _checkinAtMeta,
        checkinAt.isAcceptableOrUnknown(data['checkin_at']!, _checkinAtMeta),
      );
    } else if (isInserting) {
      context.missing(_checkinAtMeta);
    }
    if (data.containsKey('checkout_at')) {
      context.handle(
        _checkoutAtMeta,
        checkoutAt.isAcceptableOrUnknown(data['checkout_at']!, _checkoutAtMeta),
      );
    }
    if (data.containsKey('checkin_lat')) {
      context.handle(
        _checkinLatMeta,
        checkinLat.isAcceptableOrUnknown(data['checkin_lat']!, _checkinLatMeta),
      );
    }
    if (data.containsKey('checkin_lng')) {
      context.handle(
        _checkinLngMeta,
        checkinLng.isAcceptableOrUnknown(data['checkin_lng']!, _checkinLngMeta),
      );
    }
    if (data.containsKey('total_hours')) {
      context.handle(
        _totalHoursMeta,
        totalHours.isAcceptableOrUnknown(data['total_hours']!, _totalHoursMeta),
      );
    }
    if (data.containsKey('ot_hours')) {
      context.handle(
        _otHoursMeta,
        otHours.isAcceptableOrUnknown(data['ot_hours']!, _otHoursMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAttendanceData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAttendanceData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      checkinAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checkin_at'],
      )!,
      checkoutAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checkout_at'],
      ),
      checkinLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}checkin_lat'],
      ),
      checkinLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}checkin_lng'],
      ),
      totalHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_hours'],
      ),
      otHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ot_hours'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $LocalAttendanceTable createAlias(String alias) {
    return $LocalAttendanceTable(attachedDatabase, alias);
  }
}

class LocalAttendanceData extends DataClass
    implements Insertable<LocalAttendanceData> {
  final String id;
  final String userId;
  final DateTime checkinAt;
  final DateTime? checkoutAt;
  final double? checkinLat;
  final double? checkinLng;
  final double? totalHours;
  final double? otHours;
  final String syncStatus;
  const LocalAttendanceData({
    required this.id,
    required this.userId,
    required this.checkinAt,
    this.checkoutAt,
    this.checkinLat,
    this.checkinLng,
    this.totalHours,
    this.otHours,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['checkin_at'] = Variable<DateTime>(checkinAt);
    if (!nullToAbsent || checkoutAt != null) {
      map['checkout_at'] = Variable<DateTime>(checkoutAt);
    }
    if (!nullToAbsent || checkinLat != null) {
      map['checkin_lat'] = Variable<double>(checkinLat);
    }
    if (!nullToAbsent || checkinLng != null) {
      map['checkin_lng'] = Variable<double>(checkinLng);
    }
    if (!nullToAbsent || totalHours != null) {
      map['total_hours'] = Variable<double>(totalHours);
    }
    if (!nullToAbsent || otHours != null) {
      map['ot_hours'] = Variable<double>(otHours);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  LocalAttendanceCompanion toCompanion(bool nullToAbsent) {
    return LocalAttendanceCompanion(
      id: Value(id),
      userId: Value(userId),
      checkinAt: Value(checkinAt),
      checkoutAt: checkoutAt == null && nullToAbsent
          ? const Value.absent()
          : Value(checkoutAt),
      checkinLat: checkinLat == null && nullToAbsent
          ? const Value.absent()
          : Value(checkinLat),
      checkinLng: checkinLng == null && nullToAbsent
          ? const Value.absent()
          : Value(checkinLng),
      totalHours: totalHours == null && nullToAbsent
          ? const Value.absent()
          : Value(totalHours),
      otHours: otHours == null && nullToAbsent
          ? const Value.absent()
          : Value(otHours),
      syncStatus: Value(syncStatus),
    );
  }

  factory LocalAttendanceData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAttendanceData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      checkinAt: serializer.fromJson<DateTime>(json['checkinAt']),
      checkoutAt: serializer.fromJson<DateTime?>(json['checkoutAt']),
      checkinLat: serializer.fromJson<double?>(json['checkinLat']),
      checkinLng: serializer.fromJson<double?>(json['checkinLng']),
      totalHours: serializer.fromJson<double?>(json['totalHours']),
      otHours: serializer.fromJson<double?>(json['otHours']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'checkinAt': serializer.toJson<DateTime>(checkinAt),
      'checkoutAt': serializer.toJson<DateTime?>(checkoutAt),
      'checkinLat': serializer.toJson<double?>(checkinLat),
      'checkinLng': serializer.toJson<double?>(checkinLng),
      'totalHours': serializer.toJson<double?>(totalHours),
      'otHours': serializer.toJson<double?>(otHours),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  LocalAttendanceData copyWith({
    String? id,
    String? userId,
    DateTime? checkinAt,
    Value<DateTime?> checkoutAt = const Value.absent(),
    Value<double?> checkinLat = const Value.absent(),
    Value<double?> checkinLng = const Value.absent(),
    Value<double?> totalHours = const Value.absent(),
    Value<double?> otHours = const Value.absent(),
    String? syncStatus,
  }) => LocalAttendanceData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    checkinAt: checkinAt ?? this.checkinAt,
    checkoutAt: checkoutAt.present ? checkoutAt.value : this.checkoutAt,
    checkinLat: checkinLat.present ? checkinLat.value : this.checkinLat,
    checkinLng: checkinLng.present ? checkinLng.value : this.checkinLng,
    totalHours: totalHours.present ? totalHours.value : this.totalHours,
    otHours: otHours.present ? otHours.value : this.otHours,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  LocalAttendanceData copyWithCompanion(LocalAttendanceCompanion data) {
    return LocalAttendanceData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      checkinAt: data.checkinAt.present ? data.checkinAt.value : this.checkinAt,
      checkoutAt: data.checkoutAt.present
          ? data.checkoutAt.value
          : this.checkoutAt,
      checkinLat: data.checkinLat.present
          ? data.checkinLat.value
          : this.checkinLat,
      checkinLng: data.checkinLng.present
          ? data.checkinLng.value
          : this.checkinLng,
      totalHours: data.totalHours.present
          ? data.totalHours.value
          : this.totalHours,
      otHours: data.otHours.present ? data.otHours.value : this.otHours,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttendanceData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('checkinAt: $checkinAt, ')
          ..write('checkoutAt: $checkoutAt, ')
          ..write('checkinLat: $checkinLat, ')
          ..write('checkinLng: $checkinLng, ')
          ..write('totalHours: $totalHours, ')
          ..write('otHours: $otHours, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    checkinAt,
    checkoutAt,
    checkinLat,
    checkinLng,
    totalHours,
    otHours,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAttendanceData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.checkinAt == this.checkinAt &&
          other.checkoutAt == this.checkoutAt &&
          other.checkinLat == this.checkinLat &&
          other.checkinLng == this.checkinLng &&
          other.totalHours == this.totalHours &&
          other.otHours == this.otHours &&
          other.syncStatus == this.syncStatus);
}

class LocalAttendanceCompanion extends UpdateCompanion<LocalAttendanceData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<DateTime> checkinAt;
  final Value<DateTime?> checkoutAt;
  final Value<double?> checkinLat;
  final Value<double?> checkinLng;
  final Value<double?> totalHours;
  final Value<double?> otHours;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const LocalAttendanceCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.checkinAt = const Value.absent(),
    this.checkoutAt = const Value.absent(),
    this.checkinLat = const Value.absent(),
    this.checkinLng = const Value.absent(),
    this.totalHours = const Value.absent(),
    this.otHours = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAttendanceCompanion.insert({
    required String id,
    required String userId,
    required DateTime checkinAt,
    this.checkoutAt = const Value.absent(),
    this.checkinLat = const Value.absent(),
    this.checkinLng = const Value.absent(),
    this.totalHours = const Value.absent(),
    this.otHours = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       checkinAt = Value(checkinAt);
  static Insertable<LocalAttendanceData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<DateTime>? checkinAt,
    Expression<DateTime>? checkoutAt,
    Expression<double>? checkinLat,
    Expression<double>? checkinLng,
    Expression<double>? totalHours,
    Expression<double>? otHours,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (checkinAt != null) 'checkin_at': checkinAt,
      if (checkoutAt != null) 'checkout_at': checkoutAt,
      if (checkinLat != null) 'checkin_lat': checkinLat,
      if (checkinLng != null) 'checkin_lng': checkinLng,
      if (totalHours != null) 'total_hours': totalHours,
      if (otHours != null) 'ot_hours': otHours,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAttendanceCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<DateTime>? checkinAt,
    Value<DateTime?>? checkoutAt,
    Value<double?>? checkinLat,
    Value<double?>? checkinLng,
    Value<double?>? totalHours,
    Value<double?>? otHours,
    Value<String>? syncStatus,
    Value<int>? rowid,
  }) {
    return LocalAttendanceCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      checkinAt: checkinAt ?? this.checkinAt,
      checkoutAt: checkoutAt ?? this.checkoutAt,
      checkinLat: checkinLat ?? this.checkinLat,
      checkinLng: checkinLng ?? this.checkinLng,
      totalHours: totalHours ?? this.totalHours,
      otHours: otHours ?? this.otHours,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (checkinAt.present) {
      map['checkin_at'] = Variable<DateTime>(checkinAt.value);
    }
    if (checkoutAt.present) {
      map['checkout_at'] = Variable<DateTime>(checkoutAt.value);
    }
    if (checkinLat.present) {
      map['checkin_lat'] = Variable<double>(checkinLat.value);
    }
    if (checkinLng.present) {
      map['checkin_lng'] = Variable<double>(checkinLng.value);
    }
    if (totalHours.present) {
      map['total_hours'] = Variable<double>(totalHours.value);
    }
    if (otHours.present) {
      map['ot_hours'] = Variable<double>(otHours.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttendanceCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('checkinAt: $checkinAt, ')
          ..write('checkoutAt: $checkoutAt, ')
          ..write('checkinLat: $checkinLat, ')
          ..write('checkinLng: $checkinLng, ')
          ..write('totalHours: $totalHours, ')
          ..write('otHours: $otHours, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalConversationsTable localConversations =
      $LocalConversationsTable(this);
  late final $LocalMessagesTable localMessages = $LocalMessagesTable(this);
  late final $PendingUploadsTable pendingUploads = $PendingUploadsTable(this);
  late final $LocalMessageReactionsTable localMessageReactions =
      $LocalMessageReactionsTable(this);
  late final $LocalPinnedMessagesTable localPinnedMessages =
      $LocalPinnedMessagesTable(this);
  late final $LocalBookmarkedMessagesTable localBookmarkedMessages =
      $LocalBookmarkedMessagesTable(this);
  late final $LocalAttendanceTable localAttendance = $LocalAttendanceTable(
    this,
  );
  late final ChatDao chatDao = ChatDao(this as AppDatabase);
  late final HrDao hrDao = HrDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localConversations,
    localMessages,
    pendingUploads,
    localMessageReactions,
    localPinnedMessages,
    localBookmarkedMessages,
    localAttendance,
  ];
}

typedef $$LocalConversationsTableCreateCompanionBuilder =
    LocalConversationsCompanion Function({
      required String id,
      Value<String> type,
      Value<String?> name,
      Value<String?> avatarUrl,
      required String createdBy,
      Value<DateTime?> lastMessageAt,
      required DateTime createdAt,
      Value<String?> lastMessageContent,
      Value<String?> lastMessageSenderId,
      Value<int> unreadCount,
      Value<int> unreadMentionCount,
      Value<String?> otherMemberName,
      Value<String?> otherMemberAvatar,
      Value<DateTime?> otherMemberLastSeenAt,
      Value<DateTime?> lastViewedAt,
      Value<int> rowid,
    });
typedef $$LocalConversationsTableUpdateCompanionBuilder =
    LocalConversationsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String?> name,
      Value<String?> avatarUrl,
      Value<String> createdBy,
      Value<DateTime?> lastMessageAt,
      Value<DateTime> createdAt,
      Value<String?> lastMessageContent,
      Value<String?> lastMessageSenderId,
      Value<int> unreadCount,
      Value<int> unreadMentionCount,
      Value<String?> otherMemberName,
      Value<String?> otherMemberAvatar,
      Value<DateTime?> otherMemberLastSeenAt,
      Value<DateTime?> lastViewedAt,
      Value<int> rowid,
    });

class $$LocalConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageContent => $composableBuilder(
    column: $table.lastMessageContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageSenderId => $composableBuilder(
    column: $table.lastMessageSenderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadMentionCount => $composableBuilder(
    column: $table.unreadMentionCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherMemberName => $composableBuilder(
    column: $table.otherMemberName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherMemberAvatar => $composableBuilder(
    column: $table.otherMemberAvatar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get otherMemberLastSeenAt => $composableBuilder(
    column: $table.otherMemberLastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastViewedAt => $composableBuilder(
    column: $table.lastViewedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageContent => $composableBuilder(
    column: $table.lastMessageContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageSenderId => $composableBuilder(
    column: $table.lastMessageSenderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadMentionCount => $composableBuilder(
    column: $table.unreadMentionCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherMemberName => $composableBuilder(
    column: $table.otherMemberName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherMemberAvatar => $composableBuilder(
    column: $table.otherMemberAvatar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get otherMemberLastSeenAt => $composableBuilder(
    column: $table.otherMemberLastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastViewedAt => $composableBuilder(
    column: $table.lastViewedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get lastMessageContent => $composableBuilder(
    column: $table.lastMessageContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageSenderId => $composableBuilder(
    column: $table.lastMessageSenderId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unreadMentionCount => $composableBuilder(
    column: $table.unreadMentionCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get otherMemberName => $composableBuilder(
    column: $table.otherMemberName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get otherMemberAvatar => $composableBuilder(
    column: $table.otherMemberAvatar,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get otherMemberLastSeenAt => $composableBuilder(
    column: $table.otherMemberLastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastViewedAt => $composableBuilder(
    column: $table.lastViewedAt,
    builder: (column) => column,
  );
}

class $$LocalConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalConversationsTable,
          LocalConversation,
          $$LocalConversationsTableFilterComposer,
          $$LocalConversationsTableOrderingComposer,
          $$LocalConversationsTableAnnotationComposer,
          $$LocalConversationsTableCreateCompanionBuilder,
          $$LocalConversationsTableUpdateCompanionBuilder,
          (
            LocalConversation,
            BaseReferences<
              _$AppDatabase,
              $LocalConversationsTable,
              LocalConversation
            >,
          ),
          LocalConversation,
          PrefetchHooks Function()
        > {
  $$LocalConversationsTableTableManager(
    _$AppDatabase db,
    $LocalConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalConversationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<DateTime?> lastMessageAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> lastMessageContent = const Value.absent(),
                Value<String?> lastMessageSenderId = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<int> unreadMentionCount = const Value.absent(),
                Value<String?> otherMemberName = const Value.absent(),
                Value<String?> otherMemberAvatar = const Value.absent(),
                Value<DateTime?> otherMemberLastSeenAt = const Value.absent(),
                Value<DateTime?> lastViewedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalConversationsCompanion(
                id: id,
                type: type,
                name: name,
                avatarUrl: avatarUrl,
                createdBy: createdBy,
                lastMessageAt: lastMessageAt,
                createdAt: createdAt,
                lastMessageContent: lastMessageContent,
                lastMessageSenderId: lastMessageSenderId,
                unreadCount: unreadCount,
                unreadMentionCount: unreadMentionCount,
                otherMemberName: otherMemberName,
                otherMemberAvatar: otherMemberAvatar,
                otherMemberLastSeenAt: otherMemberLastSeenAt,
                lastViewedAt: lastViewedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> type = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                required String createdBy,
                Value<DateTime?> lastMessageAt = const Value.absent(),
                required DateTime createdAt,
                Value<String?> lastMessageContent = const Value.absent(),
                Value<String?> lastMessageSenderId = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<int> unreadMentionCount = const Value.absent(),
                Value<String?> otherMemberName = const Value.absent(),
                Value<String?> otherMemberAvatar = const Value.absent(),
                Value<DateTime?> otherMemberLastSeenAt = const Value.absent(),
                Value<DateTime?> lastViewedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalConversationsCompanion.insert(
                id: id,
                type: type,
                name: name,
                avatarUrl: avatarUrl,
                createdBy: createdBy,
                lastMessageAt: lastMessageAt,
                createdAt: createdAt,
                lastMessageContent: lastMessageContent,
                lastMessageSenderId: lastMessageSenderId,
                unreadCount: unreadCount,
                unreadMentionCount: unreadMentionCount,
                otherMemberName: otherMemberName,
                otherMemberAvatar: otherMemberAvatar,
                otherMemberLastSeenAt: otherMemberLastSeenAt,
                lastViewedAt: lastViewedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalConversationsTable,
      LocalConversation,
      $$LocalConversationsTableFilterComposer,
      $$LocalConversationsTableOrderingComposer,
      $$LocalConversationsTableAnnotationComposer,
      $$LocalConversationsTableCreateCompanionBuilder,
      $$LocalConversationsTableUpdateCompanionBuilder,
      (
        LocalConversation,
        BaseReferences<
          _$AppDatabase,
          $LocalConversationsTable,
          LocalConversation
        >,
      ),
      LocalConversation,
      PrefetchHooks Function()
    >;
typedef $$LocalMessagesTableCreateCompanionBuilder =
    LocalMessagesCompanion Function({
      required String id,
      required String convId,
      required String senderId,
      Value<String> type,
      Value<String?> content,
      Value<String?> replyToId,
      Value<String?> metadata,
      required DateTime createdAt,
      Value<DateTime?> editedAt,
      Value<DateTime?> deletedAt,
      Value<String> status,
      Value<int> retryCount,
      Value<String?> forwardedFromId,
      Value<String?> forwardedFromSender,
      Value<int> rowid,
    });
typedef $$LocalMessagesTableUpdateCompanionBuilder =
    LocalMessagesCompanion Function({
      Value<String> id,
      Value<String> convId,
      Value<String> senderId,
      Value<String> type,
      Value<String?> content,
      Value<String?> replyToId,
      Value<String?> metadata,
      Value<DateTime> createdAt,
      Value<DateTime?> editedAt,
      Value<DateTime?> deletedAt,
      Value<String> status,
      Value<int> retryCount,
      Value<String?> forwardedFromId,
      Value<String?> forwardedFromSender,
      Value<int> rowid,
    });

class $$LocalMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get convId => $composableBuilder(
    column: $table.convId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get editedAt => $composableBuilder(
    column: $table.editedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get forwardedFromId => $composableBuilder(
    column: $table.forwardedFromId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get forwardedFromSender => $composableBuilder(
    column: $table.forwardedFromSender,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get convId => $composableBuilder(
    column: $table.convId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get editedAt => $composableBuilder(
    column: $table.editedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get forwardedFromId => $composableBuilder(
    column: $table.forwardedFromId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get forwardedFromSender => $composableBuilder(
    column: $table.forwardedFromSender,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get convId =>
      $composableBuilder(column: $table.convId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get editedAt =>
      $composableBuilder(column: $table.editedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get forwardedFromId => $composableBuilder(
    column: $table.forwardedFromId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get forwardedFromSender => $composableBuilder(
    column: $table.forwardedFromSender,
    builder: (column) => column,
  );
}

class $$LocalMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMessagesTable,
          LocalMessage,
          $$LocalMessagesTableFilterComposer,
          $$LocalMessagesTableOrderingComposer,
          $$LocalMessagesTableAnnotationComposer,
          $$LocalMessagesTableCreateCompanionBuilder,
          $$LocalMessagesTableUpdateCompanionBuilder,
          (
            LocalMessage,
            BaseReferences<_$AppDatabase, $LocalMessagesTable, LocalMessage>,
          ),
          LocalMessage,
          PrefetchHooks Function()
        > {
  $$LocalMessagesTableTableManager(_$AppDatabase db, $LocalMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> convId = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> editedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> forwardedFromId = const Value.absent(),
                Value<String?> forwardedFromSender = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMessagesCompanion(
                id: id,
                convId: convId,
                senderId: senderId,
                type: type,
                content: content,
                replyToId: replyToId,
                metadata: metadata,
                createdAt: createdAt,
                editedAt: editedAt,
                deletedAt: deletedAt,
                status: status,
                retryCount: retryCount,
                forwardedFromId: forwardedFromId,
                forwardedFromSender: forwardedFromSender,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String convId,
                required String senderId,
                Value<String> type = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> editedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> forwardedFromId = const Value.absent(),
                Value<String?> forwardedFromSender = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMessagesCompanion.insert(
                id: id,
                convId: convId,
                senderId: senderId,
                type: type,
                content: content,
                replyToId: replyToId,
                metadata: metadata,
                createdAt: createdAt,
                editedAt: editedAt,
                deletedAt: deletedAt,
                status: status,
                retryCount: retryCount,
                forwardedFromId: forwardedFromId,
                forwardedFromSender: forwardedFromSender,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMessagesTable,
      LocalMessage,
      $$LocalMessagesTableFilterComposer,
      $$LocalMessagesTableOrderingComposer,
      $$LocalMessagesTableAnnotationComposer,
      $$LocalMessagesTableCreateCompanionBuilder,
      $$LocalMessagesTableUpdateCompanionBuilder,
      (
        LocalMessage,
        BaseReferences<_$AppDatabase, $LocalMessagesTable, LocalMessage>,
      ),
      LocalMessage,
      PrefetchHooks Function()
    >;
typedef $$PendingUploadsTableCreateCompanionBuilder =
    PendingUploadsCompanion Function({
      required String id,
      required String convId,
      required String localPaths,
      Value<String?> caption,
      Value<String> status,
      Value<int> retryCount,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PendingUploadsTableUpdateCompanionBuilder =
    PendingUploadsCompanion Function({
      Value<String> id,
      Value<String> convId,
      Value<String> localPaths,
      Value<String?> caption,
      Value<String> status,
      Value<int> retryCount,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$PendingUploadsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingUploadsTable> {
  $$PendingUploadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get convId => $composableBuilder(
    column: $table.convId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPaths => $composableBuilder(
    column: $table.localPaths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingUploadsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingUploadsTable> {
  $$PendingUploadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get convId => $composableBuilder(
    column: $table.convId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPaths => $composableBuilder(
    column: $table.localPaths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingUploadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingUploadsTable> {
  $$PendingUploadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get convId =>
      $composableBuilder(column: $table.convId, builder: (column) => column);

  GeneratedColumn<String> get localPaths => $composableBuilder(
    column: $table.localPaths,
    builder: (column) => column,
  );

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingUploadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingUploadsTable,
          PendingUpload,
          $$PendingUploadsTableFilterComposer,
          $$PendingUploadsTableOrderingComposer,
          $$PendingUploadsTableAnnotationComposer,
          $$PendingUploadsTableCreateCompanionBuilder,
          $$PendingUploadsTableUpdateCompanionBuilder,
          (
            PendingUpload,
            BaseReferences<_$AppDatabase, $PendingUploadsTable, PendingUpload>,
          ),
          PendingUpload,
          PrefetchHooks Function()
        > {
  $$PendingUploadsTableTableManager(
    _$AppDatabase db,
    $PendingUploadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingUploadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingUploadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingUploadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> convId = const Value.absent(),
                Value<String> localPaths = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingUploadsCompanion(
                id: id,
                convId: convId,
                localPaths: localPaths,
                caption: caption,
                status: status,
                retryCount: retryCount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String convId,
                required String localPaths,
                Value<String?> caption = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingUploadsCompanion.insert(
                id: id,
                convId: convId,
                localPaths: localPaths,
                caption: caption,
                status: status,
                retryCount: retryCount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingUploadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingUploadsTable,
      PendingUpload,
      $$PendingUploadsTableFilterComposer,
      $$PendingUploadsTableOrderingComposer,
      $$PendingUploadsTableAnnotationComposer,
      $$PendingUploadsTableCreateCompanionBuilder,
      $$PendingUploadsTableUpdateCompanionBuilder,
      (
        PendingUpload,
        BaseReferences<_$AppDatabase, $PendingUploadsTable, PendingUpload>,
      ),
      PendingUpload,
      PrefetchHooks Function()
    >;
typedef $$LocalMessageReactionsTableCreateCompanionBuilder =
    LocalMessageReactionsCompanion Function({
      required String messageId,
      required String userId,
      required String emoji,
      required String userName,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LocalMessageReactionsTableUpdateCompanionBuilder =
    LocalMessageReactionsCompanion Function({
      Value<String> messageId,
      Value<String> userId,
      Value<String> emoji,
      Value<String> userName,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalMessageReactionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMessageReactionsTable> {
  $$LocalMessageReactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userName => $composableBuilder(
    column: $table.userName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMessageReactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMessageReactionsTable> {
  $$LocalMessageReactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userName => $composableBuilder(
    column: $table.userName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMessageReactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMessageReactionsTable> {
  $$LocalMessageReactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<String> get userName =>
      $composableBuilder(column: $table.userName, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalMessageReactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMessageReactionsTable,
          LocalMessageReaction,
          $$LocalMessageReactionsTableFilterComposer,
          $$LocalMessageReactionsTableOrderingComposer,
          $$LocalMessageReactionsTableAnnotationComposer,
          $$LocalMessageReactionsTableCreateCompanionBuilder,
          $$LocalMessageReactionsTableUpdateCompanionBuilder,
          (
            LocalMessageReaction,
            BaseReferences<
              _$AppDatabase,
              $LocalMessageReactionsTable,
              LocalMessageReaction
            >,
          ),
          LocalMessageReaction,
          PrefetchHooks Function()
        > {
  $$LocalMessageReactionsTableTableManager(
    _$AppDatabase db,
    $LocalMessageReactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMessageReactionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalMessageReactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalMessageReactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<String> userName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMessageReactionsCompanion(
                messageId: messageId,
                userId: userId,
                emoji: emoji,
                userName: userName,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String userId,
                required String emoji,
                required String userName,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalMessageReactionsCompanion.insert(
                messageId: messageId,
                userId: userId,
                emoji: emoji,
                userName: userName,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMessageReactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMessageReactionsTable,
      LocalMessageReaction,
      $$LocalMessageReactionsTableFilterComposer,
      $$LocalMessageReactionsTableOrderingComposer,
      $$LocalMessageReactionsTableAnnotationComposer,
      $$LocalMessageReactionsTableCreateCompanionBuilder,
      $$LocalMessageReactionsTableUpdateCompanionBuilder,
      (
        LocalMessageReaction,
        BaseReferences<
          _$AppDatabase,
          $LocalMessageReactionsTable,
          LocalMessageReaction
        >,
      ),
      LocalMessageReaction,
      PrefetchHooks Function()
    >;
typedef $$LocalPinnedMessagesTableCreateCompanionBuilder =
    LocalPinnedMessagesCompanion Function({
      required String convId,
      required String messageId,
      required String pinnedBy,
      required DateTime pinnedAt,
      Value<int> rowid,
    });
typedef $$LocalPinnedMessagesTableUpdateCompanionBuilder =
    LocalPinnedMessagesCompanion Function({
      Value<String> convId,
      Value<String> messageId,
      Value<String> pinnedBy,
      Value<DateTime> pinnedAt,
      Value<int> rowid,
    });

class $$LocalPinnedMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPinnedMessagesTable> {
  $$LocalPinnedMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get convId => $composableBuilder(
    column: $table.convId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinnedBy => $composableBuilder(
    column: $table.pinnedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalPinnedMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPinnedMessagesTable> {
  $$LocalPinnedMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get convId => $composableBuilder(
    column: $table.convId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinnedBy => $composableBuilder(
    column: $table.pinnedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalPinnedMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPinnedMessagesTable> {
  $$LocalPinnedMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get convId =>
      $composableBuilder(column: $table.convId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get pinnedBy =>
      $composableBuilder(column: $table.pinnedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get pinnedAt =>
      $composableBuilder(column: $table.pinnedAt, builder: (column) => column);
}

class $$LocalPinnedMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalPinnedMessagesTable,
          LocalPinnedMessage,
          $$LocalPinnedMessagesTableFilterComposer,
          $$LocalPinnedMessagesTableOrderingComposer,
          $$LocalPinnedMessagesTableAnnotationComposer,
          $$LocalPinnedMessagesTableCreateCompanionBuilder,
          $$LocalPinnedMessagesTableUpdateCompanionBuilder,
          (
            LocalPinnedMessage,
            BaseReferences<
              _$AppDatabase,
              $LocalPinnedMessagesTable,
              LocalPinnedMessage
            >,
          ),
          LocalPinnedMessage,
          PrefetchHooks Function()
        > {
  $$LocalPinnedMessagesTableTableManager(
    _$AppDatabase db,
    $LocalPinnedMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPinnedMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPinnedMessagesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalPinnedMessagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> convId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> pinnedBy = const Value.absent(),
                Value<DateTime> pinnedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPinnedMessagesCompanion(
                convId: convId,
                messageId: messageId,
                pinnedBy: pinnedBy,
                pinnedAt: pinnedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String convId,
                required String messageId,
                required String pinnedBy,
                required DateTime pinnedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalPinnedMessagesCompanion.insert(
                convId: convId,
                messageId: messageId,
                pinnedBy: pinnedBy,
                pinnedAt: pinnedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalPinnedMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalPinnedMessagesTable,
      LocalPinnedMessage,
      $$LocalPinnedMessagesTableFilterComposer,
      $$LocalPinnedMessagesTableOrderingComposer,
      $$LocalPinnedMessagesTableAnnotationComposer,
      $$LocalPinnedMessagesTableCreateCompanionBuilder,
      $$LocalPinnedMessagesTableUpdateCompanionBuilder,
      (
        LocalPinnedMessage,
        BaseReferences<
          _$AppDatabase,
          $LocalPinnedMessagesTable,
          LocalPinnedMessage
        >,
      ),
      LocalPinnedMessage,
      PrefetchHooks Function()
    >;
typedef $$LocalBookmarkedMessagesTableCreateCompanionBuilder =
    LocalBookmarkedMessagesCompanion Function({
      required String convId,
      required String messageId,
      required String userId,
      required DateTime markedAt,
      Value<String?> messageContent,
      Value<String?> messageType,
      Value<String?> senderId,
      Value<String?> senderName,
      Value<DateTime?> messageCreatedAt,
      Value<int> rowid,
    });
typedef $$LocalBookmarkedMessagesTableUpdateCompanionBuilder =
    LocalBookmarkedMessagesCompanion Function({
      Value<String> convId,
      Value<String> messageId,
      Value<String> userId,
      Value<DateTime> markedAt,
      Value<String?> messageContent,
      Value<String?> messageType,
      Value<String?> senderId,
      Value<String?> senderName,
      Value<DateTime?> messageCreatedAt,
      Value<int> rowid,
    });

class $$LocalBookmarkedMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalBookmarkedMessagesTable> {
  $$LocalBookmarkedMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get convId => $composableBuilder(
    column: $table.convId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get markedAt => $composableBuilder(
    column: $table.markedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageContent => $composableBuilder(
    column: $table.messageContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get messageCreatedAt => $composableBuilder(
    column: $table.messageCreatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalBookmarkedMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalBookmarkedMessagesTable> {
  $$LocalBookmarkedMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get convId => $composableBuilder(
    column: $table.convId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get markedAt => $composableBuilder(
    column: $table.markedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageContent => $composableBuilder(
    column: $table.messageContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get messageCreatedAt => $composableBuilder(
    column: $table.messageCreatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalBookmarkedMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalBookmarkedMessagesTable> {
  $$LocalBookmarkedMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get convId =>
      $composableBuilder(column: $table.convId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<DateTime> get markedAt =>
      $composableBuilder(column: $table.markedAt, builder: (column) => column);

  GeneratedColumn<String> get messageContent => $composableBuilder(
    column: $table.messageContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get messageCreatedAt => $composableBuilder(
    column: $table.messageCreatedAt,
    builder: (column) => column,
  );
}

class $$LocalBookmarkedMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalBookmarkedMessagesTable,
          LocalBookmarkedMessage,
          $$LocalBookmarkedMessagesTableFilterComposer,
          $$LocalBookmarkedMessagesTableOrderingComposer,
          $$LocalBookmarkedMessagesTableAnnotationComposer,
          $$LocalBookmarkedMessagesTableCreateCompanionBuilder,
          $$LocalBookmarkedMessagesTableUpdateCompanionBuilder,
          (
            LocalBookmarkedMessage,
            BaseReferences<
              _$AppDatabase,
              $LocalBookmarkedMessagesTable,
              LocalBookmarkedMessage
            >,
          ),
          LocalBookmarkedMessage,
          PrefetchHooks Function()
        > {
  $$LocalBookmarkedMessagesTableTableManager(
    _$AppDatabase db,
    $LocalBookmarkedMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBookmarkedMessagesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalBookmarkedMessagesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalBookmarkedMessagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> convId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<DateTime> markedAt = const Value.absent(),
                Value<String?> messageContent = const Value.absent(),
                Value<String?> messageType = const Value.absent(),
                Value<String?> senderId = const Value.absent(),
                Value<String?> senderName = const Value.absent(),
                Value<DateTime?> messageCreatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalBookmarkedMessagesCompanion(
                convId: convId,
                messageId: messageId,
                userId: userId,
                markedAt: markedAt,
                messageContent: messageContent,
                messageType: messageType,
                senderId: senderId,
                senderName: senderName,
                messageCreatedAt: messageCreatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String convId,
                required String messageId,
                required String userId,
                required DateTime markedAt,
                Value<String?> messageContent = const Value.absent(),
                Value<String?> messageType = const Value.absent(),
                Value<String?> senderId = const Value.absent(),
                Value<String?> senderName = const Value.absent(),
                Value<DateTime?> messageCreatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalBookmarkedMessagesCompanion.insert(
                convId: convId,
                messageId: messageId,
                userId: userId,
                markedAt: markedAt,
                messageContent: messageContent,
                messageType: messageType,
                senderId: senderId,
                senderName: senderName,
                messageCreatedAt: messageCreatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalBookmarkedMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalBookmarkedMessagesTable,
      LocalBookmarkedMessage,
      $$LocalBookmarkedMessagesTableFilterComposer,
      $$LocalBookmarkedMessagesTableOrderingComposer,
      $$LocalBookmarkedMessagesTableAnnotationComposer,
      $$LocalBookmarkedMessagesTableCreateCompanionBuilder,
      $$LocalBookmarkedMessagesTableUpdateCompanionBuilder,
      (
        LocalBookmarkedMessage,
        BaseReferences<
          _$AppDatabase,
          $LocalBookmarkedMessagesTable,
          LocalBookmarkedMessage
        >,
      ),
      LocalBookmarkedMessage,
      PrefetchHooks Function()
    >;
typedef $$LocalAttendanceTableCreateCompanionBuilder =
    LocalAttendanceCompanion Function({
      required String id,
      required String userId,
      required DateTime checkinAt,
      Value<DateTime?> checkoutAt,
      Value<double?> checkinLat,
      Value<double?> checkinLng,
      Value<double?> totalHours,
      Value<double?> otHours,
      Value<String> syncStatus,
      Value<int> rowid,
    });
typedef $$LocalAttendanceTableUpdateCompanionBuilder =
    LocalAttendanceCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<DateTime> checkinAt,
      Value<DateTime?> checkoutAt,
      Value<double?> checkinLat,
      Value<double?> checkinLng,
      Value<double?> totalHours,
      Value<double?> otHours,
      Value<String> syncStatus,
      Value<int> rowid,
    });

class $$LocalAttendanceTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAttendanceTable> {
  $$LocalAttendanceTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkinAt => $composableBuilder(
    column: $table.checkinAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkoutAt => $composableBuilder(
    column: $table.checkoutAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get checkinLat => $composableBuilder(
    column: $table.checkinLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get checkinLng => $composableBuilder(
    column: $table.checkinLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalHours => $composableBuilder(
    column: $table.totalHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get otHours => $composableBuilder(
    column: $table.otHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAttendanceTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAttendanceTable> {
  $$LocalAttendanceTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkinAt => $composableBuilder(
    column: $table.checkinAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkoutAt => $composableBuilder(
    column: $table.checkoutAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get checkinLat => $composableBuilder(
    column: $table.checkinLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get checkinLng => $composableBuilder(
    column: $table.checkinLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalHours => $composableBuilder(
    column: $table.totalHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get otHours => $composableBuilder(
    column: $table.otHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAttendanceTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAttendanceTable> {
  $$LocalAttendanceTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<DateTime> get checkinAt =>
      $composableBuilder(column: $table.checkinAt, builder: (column) => column);

  GeneratedColumn<DateTime> get checkoutAt => $composableBuilder(
    column: $table.checkoutAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get checkinLat => $composableBuilder(
    column: $table.checkinLat,
    builder: (column) => column,
  );

  GeneratedColumn<double> get checkinLng => $composableBuilder(
    column: $table.checkinLng,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalHours => $composableBuilder(
    column: $table.totalHours,
    builder: (column) => column,
  );

  GeneratedColumn<double> get otHours =>
      $composableBuilder(column: $table.otHours, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$LocalAttendanceTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalAttendanceTable,
          LocalAttendanceData,
          $$LocalAttendanceTableFilterComposer,
          $$LocalAttendanceTableOrderingComposer,
          $$LocalAttendanceTableAnnotationComposer,
          $$LocalAttendanceTableCreateCompanionBuilder,
          $$LocalAttendanceTableUpdateCompanionBuilder,
          (
            LocalAttendanceData,
            BaseReferences<
              _$AppDatabase,
              $LocalAttendanceTable,
              LocalAttendanceData
            >,
          ),
          LocalAttendanceData,
          PrefetchHooks Function()
        > {
  $$LocalAttendanceTableTableManager(
    _$AppDatabase db,
    $LocalAttendanceTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAttendanceTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAttendanceTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAttendanceTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<DateTime> checkinAt = const Value.absent(),
                Value<DateTime?> checkoutAt = const Value.absent(),
                Value<double?> checkinLat = const Value.absent(),
                Value<double?> checkinLng = const Value.absent(),
                Value<double?> totalHours = const Value.absent(),
                Value<double?> otHours = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttendanceCompanion(
                id: id,
                userId: userId,
                checkinAt: checkinAt,
                checkoutAt: checkoutAt,
                checkinLat: checkinLat,
                checkinLng: checkinLng,
                totalHours: totalHours,
                otHours: otHours,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required DateTime checkinAt,
                Value<DateTime?> checkoutAt = const Value.absent(),
                Value<double?> checkinLat = const Value.absent(),
                Value<double?> checkinLng = const Value.absent(),
                Value<double?> totalHours = const Value.absent(),
                Value<double?> otHours = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttendanceCompanion.insert(
                id: id,
                userId: userId,
                checkinAt: checkinAt,
                checkoutAt: checkoutAt,
                checkinLat: checkinLat,
                checkinLng: checkinLng,
                totalHours: totalHours,
                otHours: otHours,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAttendanceTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalAttendanceTable,
      LocalAttendanceData,
      $$LocalAttendanceTableFilterComposer,
      $$LocalAttendanceTableOrderingComposer,
      $$LocalAttendanceTableAnnotationComposer,
      $$LocalAttendanceTableCreateCompanionBuilder,
      $$LocalAttendanceTableUpdateCompanionBuilder,
      (
        LocalAttendanceData,
        BaseReferences<
          _$AppDatabase,
          $LocalAttendanceTable,
          LocalAttendanceData
        >,
      ),
      LocalAttendanceData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalConversationsTableTableManager get localConversations =>
      $$LocalConversationsTableTableManager(_db, _db.localConversations);
  $$LocalMessagesTableTableManager get localMessages =>
      $$LocalMessagesTableTableManager(_db, _db.localMessages);
  $$PendingUploadsTableTableManager get pendingUploads =>
      $$PendingUploadsTableTableManager(_db, _db.pendingUploads);
  $$LocalMessageReactionsTableTableManager get localMessageReactions =>
      $$LocalMessageReactionsTableTableManager(_db, _db.localMessageReactions);
  $$LocalPinnedMessagesTableTableManager get localPinnedMessages =>
      $$LocalPinnedMessagesTableTableManager(_db, _db.localPinnedMessages);
  $$LocalBookmarkedMessagesTableTableManager get localBookmarkedMessages =>
      $$LocalBookmarkedMessagesTableTableManager(
        _db,
        _db.localBookmarkedMessages,
      );
  $$LocalAttendanceTableTableManager get localAttendance =>
      $$LocalAttendanceTableTableManager(_db, _db.localAttendance);
}
