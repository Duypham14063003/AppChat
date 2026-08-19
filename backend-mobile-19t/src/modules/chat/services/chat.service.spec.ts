import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { createCipheriv } from 'node:crypto';
import { ChatService } from './chat.service';
import { Conversation } from '../entities/conversation.entity';
import { ConversationEncryptionKey } from '../entities/conversation-encryption-key.entity';
import { ConversationMember } from '../entities/conversation-member.entity';
import { MessageBlindIndex } from '../entities/message-blind-index.entity';
import { Message } from '../entities/message.entity';
import { MessageBookmark } from '../entities/message-bookmark.entity';
import { MessageReminder } from '../entities/message-reminder.entity';
import { MessageReaction } from '../entities/message-reaction.entity';
import { PinnedMessage } from '../entities/pinned-message.entity';
import { User } from '../../auth/entities/user.entity';
import { RedisPubSubService } from './redis-pubsub.service';
import { NotificationJobService } from './notification-job.service';
import { ConnectionManager } from './connection-manager.service';
import { ReminderJobService } from './reminder-job.service';

function createRepoMock() {
  return {
    findOne: jest.fn(),
    save: jest.fn(),
    create: jest.fn((value) => value),
    delete: jest.fn(),
    query: jest.fn(),
    count: jest.fn(),
    find: jest.fn(),
    update: jest.fn(),
    createQueryBuilder: jest.fn(),
  };
}

describe('ChatService bookmarks', () => {
  let service: ChatService;
  const convRepo = createRepoMock();
  const encryptionKeyRepo = createRepoMock();
  const memberRepo = createRepoMock();
  const blindIndexRepo = createRepoMock();
  const messageRepo = createRepoMock();
  const bookmarkRepo = createRepoMock();
  const reminderRepo = createRepoMock();
  const reactionRepo = createRepoMock();
  const pinnedRepo = createRepoMock();
  const userRepo = createRepoMock();
  const redisPubSub = {
    publish: jest.fn(),
    publishUserEvent: jest.fn(),
    subscribeConversation: jest.fn(),
  };
  const notificationJob = {
    enqueuePush: jest.fn(),
    enqueueGroupMembershipAdded: jest.fn(),
  };
  const connectionManager = {
    isOnline: jest.fn(),
    getConnections: jest.fn(),
  };
  const reminderJobService = {
    scheduleReminder: jest.fn(),
    removeReminder: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ChatService,
        { provide: getRepositoryToken(Conversation), useValue: convRepo },
        {
          provide: getRepositoryToken(ConversationEncryptionKey),
          useValue: encryptionKeyRepo,
        },
        {
          provide: getRepositoryToken(ConversationMember),
          useValue: memberRepo,
        },
        {
          provide: getRepositoryToken(MessageBlindIndex),
          useValue: blindIndexRepo,
        },
        { provide: getRepositoryToken(Message), useValue: messageRepo },
        {
          provide: getRepositoryToken(MessageBookmark),
          useValue: bookmarkRepo,
        },
        {
          provide: getRepositoryToken(MessageReminder),
          useValue: reminderRepo,
        },
        {
          provide: getRepositoryToken(MessageReaction),
          useValue: reactionRepo,
        },
        { provide: getRepositoryToken(PinnedMessage), useValue: pinnedRepo },
        { provide: getRepositoryToken(User), useValue: userRepo },
        {
          provide: RedisPubSubService,
          useValue: redisPubSub,
        },
        {
          provide: NotificationJobService,
          useValue: notificationJob,
        },
        {
          provide: ReminderJobService,
          useValue: reminderJobService,
        },
        {
          provide: ConnectionManager,
          useValue: connectionManager,
        },
      ],
    }).compile();

    service = module.get(ChatService);
  });

  it('creates a private bookmark for the current user', async () => {
    const saved = {
      user_id: 'user-1',
      conv_id: 'conv-1',
      message_id: 'msg-1',
      marked_at: new Date(),
    };
    memberRepo.findOne.mockResolvedValue({ user_id: 'user-1' });
    messageRepo.findOne.mockResolvedValue({ id: 'msg-1', conv_id: 'conv-1' });
    bookmarkRepo.findOne.mockResolvedValue(null);
    bookmarkRepo.save.mockResolvedValue(saved);

    const result = await service.bookmarkMessage('user-1', 'conv-1', 'msg-1');

    expect(bookmarkRepo.create).toHaveBeenCalledWith({
      user_id: 'user-1',
      conv_id: 'conv-1',
      message_id: 'msg-1',
    });
    expect(bookmarkRepo.save).toHaveBeenCalled();
    expect(result).toBe(saved);
  });

  it('rejects duplicate bookmarks for the same user and message', async () => {
    memberRepo.findOne.mockResolvedValue({ user_id: 'user-1' });
    messageRepo.findOne.mockResolvedValue({ id: 'msg-1', conv_id: 'conv-1' });
    bookmarkRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      conv_id: 'conv-1',
      message_id: 'msg-1',
    });

    await expect(
      service.bookmarkMessage('user-1', 'conv-1', 'msg-1'),
    ).rejects.toMatchObject({ code: 'ALREADY_BOOKMARKED' });
  });

  it('returns only current user bookmarks for a conversation', async () => {
    const rows = [
      {
        user_id: 'user-1',
        conv_id: 'conv-1',
        message_id: 'msg-2',
        marked_at: new Date('2026-04-21T10:00:00.000Z'),
      },
    ];
    memberRepo.findOne.mockResolvedValue({ user_id: 'user-1' });
    bookmarkRepo.query.mockResolvedValue(rows);

    const result = await service.getBookmarks('user-1', 'conv-1');

    expect(bookmarkRepo.query).toHaveBeenCalledWith(
      expect.stringContaining('FROM message_bookmarks b'),
      ['user-1', 'conv-1'],
    );
    expect(result).toEqual(rows);
  });

  it('returns sender_name instead of sender_id in conversation lastMessage', async () => {
    const qb = {
      innerJoin: jest.fn().mockReturnThis(),
      leftJoin: jest.fn().mockReturnThis(),
      addSelect: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue([
        {
          id: 'conv-1',
          last_message_at: new Date('2026-06-03T10:00:00.000Z'),
        },
      ]),
    };
    convRepo.createQueryBuilder.mockReturnValue(qb);
    messageRepo.findOne.mockResolvedValue({
      id: 'msg-1',
      content: 'hello',
      metadata: null,
      type: 'text',
      created_at: new Date('2026-06-03T10:00:00.000Z'),
      deleted_at: null,
      sender: {
        name: 'Alice',
        avatar_url: '/avatars/alice.png',
      },
    });
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
      last_read_at: null,
    });
    const unreadQb = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getCount: jest.fn().mockResolvedValue(0),
    };
    messageRepo.createQueryBuilder.mockReturnValue(unreadQb);

    const result = await service.getConversations('user-1');

    expect(messageRepo.findOne).toHaveBeenCalledWith(
      expect.objectContaining({
        relations: { sender: true },
        select: expect.objectContaining({
          sender: { name: true },
        }),
      }),
    );
    expect(result.conversations[0].lastMessage).toEqual({
      id: 'msg-1',
      content: 'hello',
      metadata: null,
      type: 'text',
      created_at: new Date('2026-06-03T10:00:00.000Z'),
      deleted_at: null,
      sender_name: 'Alice',
      sender_avatar_url: '/avatars/alice.png',
    });
    expect(result.conversations[0].lastMessage.sender_id).toBeUndefined();
  });

  it('returns seen-by members for a conversation message', async () => {
    memberRepo.findOne.mockResolvedValueOnce({
      user_id: 'user-1',
      conv_id: 'conv-1',
    });
    messageRepo.findOne.mockResolvedValueOnce({
      id: 'msg-1',
      conv_id: 'conv-1',
      created_at: new Date('2026-05-05T10:00:00.000Z'),
      deleted_at: null,
    });
    memberRepo.query.mockResolvedValue([
      {
        user_id: 'user-2',
        name: 'User 2',
        avatar_url: 'https://example.com/u2.png',
        seen_at: new Date('2026-05-05T10:02:00.000Z'),
      },
    ]);

    const result = await service.getMessageSeenBy('user-1', 'conv-1', 'msg-1');

    expect(memberRepo.query).toHaveBeenCalledWith(
      expect.stringContaining('LEFT JOIN messages last_read_msg'),
      ['conv-1', 'user-1', 'msg-1', new Date('2026-05-05T10:00:00.000Z')],
    );
    expect(result).toEqual({
      conv_id: 'conv-1',
      message_id: 'msg-1',
      seen_by: [
        {
          user_id: 'user-2',
          name: 'User 2',
          avatar_url: 'https://example.com/u2.png',
          seen_at: '2026-05-05T10:02:00.000Z',
        },
      ],
    });
  });

  it('rejects seen-by lookup when the requester is not a conversation member', async () => {
    memberRepo.findOne.mockResolvedValueOnce(null);

    await expect(
      service.getMessageSeenBy('user-1', 'conv-1', 'msg-1'),
    ).rejects.toMatchObject({
      code: 'FORBIDDEN',
    });
    expect(memberRepo.query).not.toHaveBeenCalled();
  });

  it('rejects seen-by lookup for recalled messages', async () => {
    memberRepo.findOne.mockResolvedValueOnce({
      user_id: 'user-1',
      conv_id: 'conv-1',
    });
    messageRepo.findOne.mockResolvedValueOnce({
      id: 'msg-1',
      conv_id: 'conv-1',
      created_at: new Date('2026-05-05T10:00:00.000Z'),
      deleted_at: new Date('2026-05-05T10:05:00.000Z'),
    });

    await expect(
      service.getMessageSeenBy('user-1', 'conv-1', 'msg-1'),
    ).rejects.toMatchObject({
      code: 'INVALID_MESSAGE_STATE',
    });
    expect(memberRepo.query).not.toHaveBeenCalled();
  });

  it('returns global bookmarks across accessible conversations ordered by marked_at desc', async () => {
    const rows = [
      {
        message_id: 'msg-3',
        conv_id: 'conv-2',
        conv_type: 'GROUP',
        conv_name: 'Team chat',
        conv_avatar_url: null,
        sender_id: 'user-3',
        sender_name: 'User 3',
        message_type: 'text',
        message_content: 'Newest bookmark',
        message_created_at: new Date('2026-04-24T08:00:00.000Z'),
        marked_at: new Date('2026-04-24T08:05:00.000Z'),
      },
      {
        message_id: 'msg-2',
        conv_id: 'conv-1',
        conv_type: 'DIRECT',
        conv_name: 'User 2',
        conv_avatar_url: 'https://example.com/avatar.png',
        sender_id: 'user-2',
        sender_name: 'User 2',
        message_type: 'text',
        message_content: 'Second bookmark',
        message_created_at: new Date('2026-04-24T07:30:00.000Z'),
        marked_at: new Date('2026-04-24T07:35:00.000Z'),
      },
      {
        message_id: 'msg-1',
        conv_id: 'conv-3',
        conv_type: 'GROUP',
        conv_name: 'Project room',
        conv_avatar_url: null,
        sender_id: 'user-4',
        sender_name: 'User 4',
        message_type: 'image',
        message_content: null,
        message_created_at: new Date('2026-04-23T10:00:00.000Z'),
        marked_at: new Date('2026-04-23T10:05:00.000Z'),
      },
    ];
    bookmarkRepo.query.mockResolvedValue(rows);

    const result = await service.getGlobalBookmarks('user-1', { limit: 2 });

    expect(bookmarkRepo.query).toHaveBeenCalledWith(
      expect.stringContaining('INNER JOIN conversation_members cm_self'),
      ['user-1', 3],
    );
    expect(bookmarkRepo.query).toHaveBeenCalledWith(
      expect.stringContaining('ORDER BY b.marked_at DESC, b.message_id DESC'),
      ['user-1', 3],
    );
    expect(result.items).toEqual([
      {
        ...rows[0],
        message_created_at: '2026-04-24T08:00:00.000Z',
        marked_at: '2026-04-24T08:05:00.000Z',
      },
      {
        ...rows[1],
        message_created_at: '2026-04-24T07:30:00.000Z',
        marked_at: '2026-04-24T07:35:00.000Z',
      },
    ]);
    expect(result.next_cursor).toBe('2026-04-24T07:35:00.000Z_msg-2');
  });

  it('validates membership before applying a conversation filter on global bookmarks', async () => {
    memberRepo.findOne.mockResolvedValue(null);

    await expect(
      service.getGlobalBookmarks('user-1', { conv_id: 'conv-1' }),
    ).rejects.toMatchObject({
      code: 'FORBIDDEN',
    });
    expect(bookmarkRepo.query).not.toHaveBeenCalled();
  });

  it('rejects invalid cursors for global bookmarks pagination', async () => {
    await expect(
      service.getGlobalBookmarks('user-1', { cursor: 'invalid-cursor' }),
    ).rejects.toMatchObject({
      code: 'INVALID_CURSOR',
    });
    expect(bookmarkRepo.query).not.toHaveBeenCalled();
  });

  it('rejects bookmark listing when user is not a conversation member', async () => {
    memberRepo.findOne.mockResolvedValue(null);

    await expect(
      service.getBookmarks('user-1', 'conv-1'),
    ).rejects.toMatchObject({
      code: 'FORBIDDEN',
    });
  });

  it('rejects delete when the current user bookmark does not exist', async () => {
    memberRepo.findOne.mockResolvedValue({ user_id: 'user-1' });
    bookmarkRepo.findOne.mockResolvedValue(null);

    await expect(
      service.deleteBookmark('user-1', 'conv-1', 'msg-1'),
    ).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('creates a pending self reminder and schedules its job', async () => {
    const queryBuilder = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getOne: jest.fn().mockResolvedValue(null),
    };
    const savedReminder = {
      id: 'reminder-1',
      conv_id: 'conv-1',
      message_id: 'msg-1',
      creator_user_id: 'user-1',
      scope: 'self',
      status: 'pending',
      remind_at: new Date('2026-04-22T10:00:00.000Z'),
      cancelled_at: null,
      fired_at: null,
      created_at: new Date(),
      updated_at: new Date(),
    };

    memberRepo.findOne.mockResolvedValue({ user_id: 'user-1' });
    messageRepo.findOne.mockResolvedValue({
      id: 'msg-1',
      conv_id: 'conv-1',
      sender_id: 'sender-1',
      type: 'text',
      content: 'Important note',
      deleted_at: null,
    });
    reminderRepo.createQueryBuilder.mockReturnValue(queryBuilder);
    reminderRepo.save.mockResolvedValue(savedReminder);
    userRepo.findOne
      .mockResolvedValueOnce({ id: 'user-1', name: 'Creator' })
      .mockResolvedValueOnce({ id: 'sender-1', name: 'Sender' });
    messageRepo.query.mockResolvedValue([
      { id: 'system-1', conv_id: 'conv-1', type: 'system' },
    ]);

    const result = await service.createMessageReminder('user-1', 'conv-1', {
      message_id: 'msg-1',
      scope: 'self',
      remind_at: new Date(Date.now() + 60_000).toISOString(),
    });

    expect(reminderRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({
        conv_id: 'conv-1',
        message_id: 'msg-1',
        creator_user_id: 'user-1',
        scope: 'self',
        status: 'pending',
      }),
    );
    expect(reminderJobService.scheduleReminder).toHaveBeenCalledWith(
      savedReminder,
    );
    expect(messageRepo.query).toHaveBeenCalledWith(
      expect.stringContaining(`INSERT INTO messages`),
      expect.any(Array),
    );
    expect(result).toBe(savedReminder);
  });

  it('rejects duplicate pending self reminders for the same creator, message, and time', async () => {
    const duplicate = {
      id: 'reminder-1',
      scope: 'self',
      status: 'pending',
    };
    const queryBuilder = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getOne: jest.fn().mockResolvedValue(duplicate),
    };

    memberRepo.findOne.mockResolvedValue({ user_id: 'user-1' });
    messageRepo.findOne.mockResolvedValue({
      id: 'msg-1',
      conv_id: 'conv-1',
      sender_id: 'sender-1',
      type: 'text',
      content: 'Important note',
      deleted_at: null,
    });
    reminderRepo.createQueryBuilder.mockReturnValue(queryBuilder);

    await expect(
      service.createMessageReminder('user-1', 'conv-1', {
        message_id: 'msg-1',
        scope: 'self',
        remind_at: new Date(Date.now() + 60_000).toISOString(),
      }),
    ).rejects.toMatchObject({ code: 'DUPLICATE_REMINDER' });
  });

  it('lists only own self reminders and everyone reminders for a message', async () => {
    const rows = [
      { id: 'self-1', scope: 'self', creator_user_id: 'user-1' },
      { id: 'all-1', scope: 'everyone', creator_user_id: 'user-2' },
    ];
    const queryBuilder = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue(rows),
    };

    memberRepo.findOne.mockResolvedValue({ user_id: 'user-1' });
    messageRepo.findOne.mockResolvedValue({
      id: 'msg-1',
      conv_id: 'conv-1',
    });
    reminderRepo.createQueryBuilder.mockReturnValue(queryBuilder);

    const result = await service.listMessageReminders(
      'user-1',
      'conv-1',
      'msg-1',
    );

    expect(result).toEqual(rows);
  });

  it('lists upcoming reminders for a user', async () => {
    const rows = [{ id: 'rem-1' }];
    const queryBuilder: any = {
      innerJoin: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue(rows),
    };
    reminderRepo.createQueryBuilder.mockReturnValue(queryBuilder);

    const result = await service.getUpcomingReminders('user-1');

    expect(queryBuilder.innerJoin).toHaveBeenCalledWith(
      'conversation_members',
      'member',
      expect.stringContaining('member.conv_id = reminder.conv_id'),
      { userId: 'user-1' },
    );
    expect(queryBuilder.where).toHaveBeenCalledWith(
      'reminder.status = :status',
      expect.anything(),
    );
    expect(result).toEqual(rows);
  });

  it('cancels only pending reminders owned by the creator', async () => {
    const reminder = {
      id: 'reminder-1',
      conv_id: 'conv-1',
      message_id: 'msg-1',
      creator_user_id: 'user-1',
      scope: 'everyone',
      status: 'pending',
      remind_at: new Date('2026-04-22T10:00:00.000Z'),
      cancelled_at: null,
      fired_at: null,
      updated_at: new Date('2026-04-22T09:00:00.000Z'),
    };

    memberRepo.findOne.mockResolvedValue({ user_id: 'user-1' });
    reminderRepo.findOne.mockResolvedValue(reminder);
    reminderRepo.save.mockImplementation(async (value) => value);
    messageRepo.findOne.mockResolvedValue({
      id: 'msg-1',
      conv_id: 'conv-1',
      sender_id: 'sender-1',
      type: 'text',
      content: 'Important note',
      deleted_at: null,
    });
    userRepo.findOne
      .mockResolvedValueOnce({ id: 'user-1', name: 'Creator' })
      .mockResolvedValueOnce({ id: 'sender-1', name: 'Sender' });
    messageRepo.query.mockResolvedValue([
      { id: 'system-1', conv_id: 'conv-1', type: 'system' },
    ]);

    const result = await service.cancelMessageReminder(
      'user-1',
      'conv-1',
      'reminder-1',
    );

    expect(reminderJobService.removeReminder).toHaveBeenCalledWith(
      'reminder-1',
    );
    expect(result.status).toBe('cancelled');
    expect(result.cancelled_at).toBeInstanceOf(Date);
  });

  it('notifies invited members when creating a new group conversation', async () => {
    const savedConversation = {
      id: 'conv-1',
      type: 'GROUP',
      name: 'Backend Team',
      avatar_url: null,
      created_by: 'user-1',
    };
    const systemMessage = {
      id: 'system-1',
      conv_id: 'conv-1',
      sender_id: 'user-1',
      type: 'system',
      content: 'created_group',
      created_at: new Date('2026-04-23T10:18:00.000Z'),
    };
    const hydratedConversation = {
      ...savedConversation,
      members: [],
    };

    userRepo.find.mockResolvedValue([
      { id: 'user-2', name: 'Bob' },
      { id: 'user-3', name: 'Carol' },
    ]);
    convRepo.save.mockResolvedValue(savedConversation);
    memberRepo.save.mockResolvedValue(undefined);
    connectionManager.isOnline.mockImplementation(
      (id: string) => id === 'user-1',
    );
    userRepo.findOne.mockResolvedValue({ name: 'Alice' });
    messageRepo.query.mockResolvedValue([systemMessage]);
    convRepo.findOne.mockResolvedValue(hydratedConversation);

    const result = await service.createGroupConversation(
      'user-1',
      'Backend Team',
      ['user-2', 'user-3'],
    );

    expect(redisPubSub.subscribeConversation).toHaveBeenCalledWith('conv-1');
    expect(notificationJob.enqueueGroupMembershipAdded).toHaveBeenCalledTimes(
      2,
    );
    expect(notificationJob.enqueueGroupMembershipAdded).toHaveBeenCalledWith(
      'user-2',
      'user-1',
      'Alice',
      {
        id: 'conv-1',
        type: 'GROUP',
        name: 'Backend Team',
      },
    );
    expect(redisPubSub.publishUserEvent).toHaveBeenCalledWith(
      'user-2',
      expect.objectContaining({
        _event: 'conversation_added',
        type: 'group_membership_added',
        conv_id: 'conv-1',
        actor_id: 'user-1',
        actor_name: 'Alice',
      }),
    );
    expect(result).toBe(hydratedConversation);
  });

  it('notifies only newly added members when adding users to an existing group', async () => {
    const groupConversation = {
      id: 'conv-1',
      type: 'GROUP',
      name: 'Backend Team',
      avatar_url: null,
      created_by: 'user-1',
    };
    const systemMessage = {
      id: 'system-2',
      conv_id: 'conv-1',
      sender_id: 'user-1',
      type: 'system',
      content: 'added_member',
      created_at: new Date('2026-04-23T10:19:00.000Z'),
    };

    memberRepo.findOne.mockResolvedValue({ role: 'creator' });
    convRepo.findOne.mockResolvedValue(groupConversation);
    userRepo.find.mockResolvedValue([
      { id: 'user-1', name: 'Alice' },
      { id: 'user-2', name: 'Bob' },
    ]);
    memberRepo.find.mockResolvedValue([{ user_id: 'user-1' }]);
    userRepo.findOne.mockResolvedValue({ name: 'Alice' });
    memberRepo.save.mockResolvedValue(undefined);
    messageRepo.query.mockResolvedValue([systemMessage]);

    const result = await service.addMembers('conv-1', 'user-1', [
      'user-1',
      'user-2',
    ]);

    expect(result).toEqual({ added: 1 });
    expect(notificationJob.enqueueGroupMembershipAdded).toHaveBeenCalledTimes(
      1,
    );
    expect(notificationJob.enqueueGroupMembershipAdded).toHaveBeenCalledWith(
      'user-2',
      'user-1',
      'Alice',
      {
        id: 'conv-1',
        type: 'GROUP',
        name: 'Backend Team',
      },
    );
    expect(redisPubSub.publishUserEvent).toHaveBeenCalledWith(
      'user-2',
      expect.objectContaining({
        _event: 'conversation_added',
        type: 'group_membership_added',
        conv_id: 'conv-1',
        actor_id: 'user-1',
        actor_name: 'Alice',
      }),
    );
    expect(redisPubSub.publishUserEvent).not.toHaveBeenCalledWith(
      'user-1',
      expect.anything(),
    );
  });

  it('allows a regular member to add new users to an existing group', async () => {
    const groupConversation = {
      id: 'conv-1',
      type: 'GROUP',
      name: 'Backend Team',
      avatar_url: null,
      created_by: 'user-9',
    };
    const systemMessage = {
      id: 'system-3',
      conv_id: 'conv-1',
      sender_id: 'user-1',
      type: 'system',
      content: 'added_member',
      created_at: new Date('2026-04-23T10:22:00.000Z'),
    };

    memberRepo.findOne.mockResolvedValue({ role: 'member' });
    convRepo.findOne.mockResolvedValue(groupConversation);
    userRepo.find.mockResolvedValue([{ id: 'user-2', name: 'Bob' }]);
    memberRepo.find.mockResolvedValue([{ user_id: 'user-1' }]);
    userRepo.findOne.mockResolvedValue({ name: 'Alice' });
    memberRepo.save.mockResolvedValue(undefined);
    messageRepo.query.mockResolvedValue([systemMessage]);

    const result = await service.addMembers('conv-1', 'user-1', ['user-2']);

    expect(result).toEqual({ added: 1 });
    expect(memberRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        conv_id: 'conv-1',
        user_id: 'user-2',
        role: 'member',
      }),
    );
  });

  it('allows the creator to remove another member', async () => {
    const groupConversation = {
      id: 'conv-1',
      type: 'GROUP',
      name: 'Backend Team',
    };
    const systemMessage = {
      id: 'system-4',
      conv_id: 'conv-1',
      sender_id: 'user-1',
      type: 'system',
      content: 'removed_member',
      created_at: new Date('2026-04-23T10:25:00.000Z'),
    };

    convRepo.findOne.mockResolvedValue(groupConversation);
    memberRepo.findOne
      .mockResolvedValueOnce({ conv_id: 'conv-1', user_id: 'user-2', role: 'member' })
      .mockResolvedValueOnce({ conv_id: 'conv-1', user_id: 'user-1', role: 'creator' });
    memberRepo.delete.mockResolvedValue(undefined);
    userRepo.findOne
      .mockResolvedValueOnce({ name: 'Alice' })
      .mockResolvedValueOnce({ name: 'Bob' });
    messageRepo.query.mockResolvedValue([systemMessage]);

    await service.removeMember('conv-1', 'user-1', 'user-2');

    expect(memberRepo.delete).toHaveBeenCalledWith({
      conv_id: 'conv-1',
      user_id: 'user-2',
    });
    expect(messageRepo.query).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO messages'),
      expect.arrayContaining([
        expect.any(String),
        'conv-1',
        'user-1',
        'removed_member',
      ]),
    );
  });

  it('rejects admin attempts to remove another member', async () => {
    convRepo.findOne.mockResolvedValue({
      id: 'conv-1',
      type: 'GROUP',
    });
    memberRepo.findOne
      .mockResolvedValueOnce({ conv_id: 'conv-1', user_id: 'user-2', role: 'member' })
      .mockResolvedValueOnce({ conv_id: 'conv-1', user_id: 'user-1', role: 'admin' });

    await expect(
      service.removeMember('conv-1', 'user-1', 'user-2'),
    ).rejects.toMatchObject({
      code: 'FORBIDDEN',
      message: 'Only the group creator can remove members',
    });

    expect(memberRepo.delete).not.toHaveBeenCalled();
  });

  it('rejects regular member attempts to remove another member', async () => {
    convRepo.findOne.mockResolvedValue({
      id: 'conv-1',
      type: 'GROUP',
    });
    memberRepo.findOne
      .mockResolvedValueOnce({ conv_id: 'conv-1', user_id: 'user-2', role: 'member' })
      .mockResolvedValueOnce({ conv_id: 'conv-1', user_id: 'user-1', role: 'member' });

    await expect(
      service.removeMember('conv-1', 'user-1', 'user-2'),
    ).rejects.toMatchObject({
      code: 'FORBIDDEN',
      message: 'Only the group creator can remove members',
    });

    expect(memberRepo.delete).not.toHaveBeenCalled();
  });

  it('rejects attempts to remove the group creator by another user', async () => {
    convRepo.findOne.mockResolvedValue({
      id: 'conv-1',
      type: 'GROUP',
    });
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
      role: 'creator',
    });

    await expect(
      service.removeMember('conv-1', 'user-2', 'user-1'),
    ).rejects.toMatchObject({
      code: 'FORBIDDEN',
      message: 'Cannot remove the group creator',
    });

    expect(memberRepo.delete).not.toHaveBeenCalled();
  });

  it('still allows any member to leave the group themselves', async () => {
    const groupConversation = {
      id: 'conv-1',
      type: 'GROUP',
      name: 'Backend Team',
    };
    const systemMessage = {
      id: 'system-5',
      conv_id: 'conv-1',
      sender_id: 'user-2',
      type: 'system',
      content: 'left_group',
      created_at: new Date('2026-04-23T10:27:00.000Z'),
    };

    convRepo.findOne.mockResolvedValue(groupConversation);
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-2',
      role: 'member',
    });
    memberRepo.delete.mockResolvedValue(undefined);
    userRepo.findOne
      .mockResolvedValueOnce({ name: 'Bob' })
      .mockResolvedValueOnce({ name: 'Bob' });
    messageRepo.query.mockResolvedValue([systemMessage]);

    await service.removeMember('conv-1', 'user-2', 'user-2');

    expect(memberRepo.delete).toHaveBeenCalledWith({
      conv_id: 'conv-1',
      user_id: 'user-2',
    });
    expect(messageRepo.query).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO messages'),
      expect.arrayContaining([
        expect.any(String),
        'conv-1',
        'user-2',
        'left_group',
      ]),
    );
  });

  it('allows the creator to leave the group themselves', async () => {
    const groupConversation = {
      id: 'conv-1',
      type: 'GROUP',
      name: 'Backend Team',
    };
    const systemMessage = {
      id: 'system-6',
      conv_id: 'conv-1',
      sender_id: 'user-1',
      type: 'system',
      content: 'left_group',
      created_at: new Date('2026-04-23T10:29:00.000Z'),
    };

    convRepo.findOne.mockResolvedValue(groupConversation);
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
      role: 'creator',
    });
    memberRepo.delete.mockResolvedValue(undefined);
    userRepo.findOne
      .mockResolvedValueOnce({ name: 'Alice' })
      .mockResolvedValueOnce({ name: 'Alice' });
    messageRepo.query.mockResolvedValue([systemMessage]);

    await service.removeMember('conv-1', 'user-1', 'user-1');

    expect(memberRepo.delete).toHaveBeenCalledWith({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    expect(messageRepo.query).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO messages'),
      expect.arrayContaining([
        expect.any(String),
        'conv-1',
        'user-1',
        'left_group',
      ]),
    );
  });
});

describe('ChatService encryption', () => {
  let service: ChatService;
  const convRepo = createRepoMock();
  const encryptionKeyRepo = createRepoMock();
  const memberRepo = createRepoMock();
  const blindIndexRepo = createRepoMock();
  const messageRepo = createRepoMock();
  const bookmarkRepo = createRepoMock();
  const reminderRepo = createRepoMock();
  const reactionRepo = createRepoMock();
  const pinnedRepo = createRepoMock();
  const userRepo = createRepoMock();
  const redisPubSub = {
    publish: jest.fn(),
    publishUserEvent: jest.fn(),
    subscribeConversation: jest.fn(),
  };
  const notificationJob = {
    enqueuePush: jest.fn(),
    enqueueGroupMembershipAdded: jest.fn(),
  };
  const connectionManager = {
    isOnline: jest.fn(),
    getConnections: jest.fn(),
  };
  const reminderJobService = {
    scheduleReminder: jest.fn(),
    removeReminder: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ChatService,
        { provide: getRepositoryToken(Conversation), useValue: convRepo },
        {
          provide: getRepositoryToken(ConversationEncryptionKey),
          useValue: encryptionKeyRepo,
        },
        {
          provide: getRepositoryToken(ConversationMember),
          useValue: memberRepo,
        },
        {
          provide: getRepositoryToken(MessageBlindIndex),
          useValue: blindIndexRepo,
        },
        { provide: getRepositoryToken(Message), useValue: messageRepo },
        {
          provide: getRepositoryToken(MessageBookmark),
          useValue: bookmarkRepo,
        },
        {
          provide: getRepositoryToken(MessageReminder),
          useValue: reminderRepo,
        },
        {
          provide: getRepositoryToken(MessageReaction),
          useValue: reactionRepo,
        },
        { provide: getRepositoryToken(PinnedMessage), useValue: pinnedRepo },
        { provide: getRepositoryToken(User), useValue: userRepo },
        {
          provide: RedisPubSubService,
          useValue: redisPubSub,
        },
        {
          provide: NotificationJobService,
          useValue: notificationJob,
        },
        {
          provide: ReminderJobService,
          useValue: reminderJobService,
        },
        {
          provide: ConnectionManager,
          useValue: connectionManager,
        },
      ],
    }).compile();

    service = module.get(ChatService);
  });

  it('creates and returns an active conversation encryption key for members', async () => {
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    encryptionKeyRepo.findOne.mockResolvedValueOnce(null);
    encryptionKeyRepo.save.mockImplementation(async (value) => ({
      ...value,
      created_at: new Date('2026-05-13T01:00:00.000Z'),
    }));

    const result = await service.getConversationEncryptionKey(
      'user-1',
      'conv-1',
    );

    expect(encryptionKeyRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        conv_id: 'conv-1',
        alg: 'AES-256-GCM',
        version: 1,
        is_active: true,
      }),
    );
    expect(result).toEqual({
      conv_id: 'conv-1',
      key_id: expect.any(String),
      alg: 'AES-256-GCM',
      version: 1,
      material: expect.any(String),
    });
    expect(Buffer.from(result.material, 'base64')).toHaveLength(32);
  });

  it('rejects malformed encrypted text envelopes', async () => {
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });

    await expect(
      service.sendMessage('user-1', {
        id: '92dd9c7d-fecd-46f0-8300-81b2d305aeef',
        conv_id: 'conv-1',
        type: 'text',
        encrypted_content: {
          version: 1,
          alg: 'AES-256-GCM',
          key_id: 'key-1',
          nonce: 'not-base64',
          ciphertext: Buffer.from('abc').toString('base64'),
        },
      }),
    ).rejects.toMatchObject({ code: 'INVALID_FORMAT' });

    expect(messageRepo.query).not.toHaveBeenCalled();
  });

  it('stores encrypted text envelopes with null plaintext content', async () => {
    const encryptedEnvelope = {
      version: 1,
      alg: 'AES-256-GCM',
      key_id: 'key-1',
      nonce: Buffer.from('nonce-value').toString('base64'),
      ciphertext: Buffer.from('ciphertext-value').toString('base64'),
    };
    const savedMessage = {
      id: 'msg-1',
      conv_id: 'conv-1',
      sender_id: 'user-1',
      type: 'text',
      content: null,
      metadata: {
        encrypted_content: encryptedEnvelope,
        mentions: [{ user_id: 'user-2' }],
      },
      created_at: new Date('2026-05-01T10:00:00.000Z'),
    };

    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    messageRepo.query.mockResolvedValue([savedMessage]);
    convRepo.update.mockResolvedValue(undefined);
    convRepo.findOne.mockResolvedValue({
      id: 'conv-1',
      type: 'DIRECT',
      name: null,
    });
    memberRepo.find.mockResolvedValue([
      { user_id: 'user-1', is_muted: false },
      { user_id: 'user-2', is_muted: false },
    ]);
    notificationJob.enqueuePush.mockResolvedValue(undefined);
    redisPubSub.publish.mockResolvedValue(undefined);

    await service.sendMessage('user-1', {
      id: 'msg-1',
      conv_id: 'conv-1',
      type: 'text',
      metadata: {
        mentions: [{ user_id: 'user-2' }],
      },
      encrypted_content: encryptedEnvelope,
    });

    const insertArgs = messageRepo.query.mock.calls[0][1];
    expect(messageRepo.query).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO messages'),
      expect.any(Array),
    );
    expect(insertArgs[0]).toBe('msg-1');
    expect(insertArgs[1]).toBe('conv-1');
    expect(insertArgs[2]).toBe('user-1');
    expect(insertArgs[3]).toBe('text');
    expect(insertArgs[4]).toBeNull();
    expect(JSON.parse(insertArgs[6])).toEqual({
      encrypted_content: encryptedEnvelope,
      mentions: [{ user_id: 'user-2' }],
    });
    expect(redisPubSub.publish).toHaveBeenCalledWith(
      'conv-1',
      expect.objectContaining({
        id: 'msg-1',
        content: null,
        encrypted_content: encryptedEnvelope,
        metadata: {
          mentions: [{ user_id: 'user-2' }],
        },
      }),
    );
  });

  it('stores blind index hashes for encrypted text messages without storing plaintext tokens', async () => {
    const encryptedEnvelope = {
      version: 1,
      alg: 'AES-256-GCM',
      key_id: 'key-1',
      nonce: Buffer.from('nonce-value').toString('base64'),
      ciphertext: Buffer.from('ciphertext-value-123456').toString('base64'),
    };
    const savedMessage = {
      id: 'msg-blind',
      conv_id: 'conv-1',
      sender_id: 'user-1',
      type: 'text',
      content: null,
      metadata: {
        encrypted_content: encryptedEnvelope,
      },
      created_at: new Date('2026-05-01T10:00:00.000Z'),
    };

    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    messageRepo.query.mockResolvedValue([savedMessage]);
    convRepo.update.mockResolvedValue(undefined);
    convRepo.findOne.mockResolvedValue({
      id: 'conv-1',
      type: 'DIRECT',
      name: null,
    });
    memberRepo.find.mockResolvedValue([
      { user_id: 'user-1', is_muted: false },
      { user_id: 'user-2', is_muted: false },
    ]);
    notificationJob.enqueuePush.mockResolvedValue(undefined);
    redisPubSub.publish.mockResolvedValue(undefined);
    blindIndexRepo.delete.mockResolvedValue(undefined);
    blindIndexRepo.query.mockResolvedValue(undefined);

    await service.sendMessage('user-1', {
      id: 'msg-blind',
      conv_id: 'conv-1',
      type: 'text',
      encrypted_content: encryptedEnvelope,
      blind_index_v1: {
        version: 1,
        algo: 'hmac-sha256',
        tokens: ['a'.repeat(64), 'b'.repeat(64), 'a'.repeat(64)],
      },
    });

    expect(blindIndexRepo.delete).toHaveBeenCalledWith({
      message_id: 'msg-blind',
    });
    expect(blindIndexRepo.query).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO message_blind_indexes'),
      ['msg-blind', 'conv-1', ['a'.repeat(64), 'b'.repeat(64)]],
    );
  });

  it('rejects blind indexes on plaintext messages', async () => {
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });

    await expect(
      service.sendMessage('user-1', {
        id: 'msg-plain',
        conv_id: 'conv-1',
        type: 'text',
        content: 'hello',
        blind_index_v1: {
          version: 1,
          algo: 'hmac-sha256',
          tokens: ['a'.repeat(64)],
        },
      }),
    ).rejects.toMatchObject({ code: 'INVALID_FORMAT' });

    expect(blindIndexRepo.query).not.toHaveBeenCalled();
  });

  it('decrypts encrypted text on the server for push preview when no plaintext preview is provided', async () => {
    const keyMaterial = Buffer.alloc(32, 7);
    const nonce = Buffer.from('123456789012');
    const cipher = createCipheriv('aes-256-gcm', keyMaterial, nonce);
    const plaintext = 'Xin chào từ server preview';
    const ciphertext = Buffer.concat([
      cipher.update(plaintext, 'utf8'),
      cipher.final(),
      cipher.getAuthTag(),
    ]).toString('base64');

    const encryptedEnvelope = {
      version: 1,
      alg: 'AES-256-GCM',
      key_id: 'key-1',
      nonce: nonce.toString('base64'),
      ciphertext,
    };
    const savedMessage = {
      id: 'msg-2',
      conv_id: 'conv-1',
      sender_id: 'user-1',
      type: 'text',
      content: null,
      metadata: {
        encrypted_content: encryptedEnvelope,
      },
      created_at: new Date('2026-05-01T10:00:00.000Z'),
    };

    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    messageRepo.query.mockResolvedValue([savedMessage]);
    convRepo.update.mockResolvedValue(undefined);
    convRepo.findOne.mockResolvedValue({
      id: 'conv-1',
      type: 'DIRECT',
      name: null,
    });
    memberRepo.find.mockResolvedValue([
      { user_id: 'user-1', is_muted: false },
      { user_id: 'user-2', is_muted: false },
    ]);
    encryptionKeyRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      key_id: 'key-1',
      material: keyMaterial,
    });
    notificationJob.enqueuePush.mockResolvedValue(undefined);
    redisPubSub.publish.mockResolvedValue(undefined);

    await service.sendMessage('user-1', {
      id: 'msg-2',
      conv_id: 'conv-1',
      type: 'text',
      encrypted_content: encryptedEnvelope,
    });

    expect(notificationJob.enqueuePush).toHaveBeenCalledWith(
      'user-2',
      expect.objectContaining({
        content: plaintext,
      }),
      false,
      false,
      expect.objectContaining({ id: 'conv-1' }),
    );
  });

  it('serializes mixed plaintext and encrypted history payloads', async () => {
    const encryptedEnvelope = {
      version: 1,
      alg: 'AES-256-GCM',
      key_id: 'key-2',
      nonce: Buffer.from('nonce-value').toString('base64'),
      ciphertext: Buffer.from('ciphertext-value').toString('base64'),
    };
    const getMany = jest.fn().mockResolvedValue([
      {
        id: 'msg-encrypted',
        conv_id: 'conv-1',
        sender_id: 'user-2',
        type: 'text',
        content: null,
        reply_to_id: null,
        metadata: {
          encrypted_content: encryptedEnvelope,
          mentions: [{ user_id: 'user-1' }],
        },
        created_at: new Date('2026-05-01T10:01:00.000Z'),
      },
      {
        id: 'msg-plain',
        conv_id: 'conv-1',
        sender_id: 'user-1',
        type: 'text',
        content: 'hello',
        reply_to_id: null,
        metadata: null,
        created_at: new Date('2026-05-01T10:00:00.000Z'),
      },
    ]);
    const queryBuilder = {
      where: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      getMany,
    };

    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    messageRepo.createQueryBuilder.mockReturnValue(queryBuilder);
    reactionRepo.query.mockResolvedValue([]);

    const result = await service.getMessages('conv-1', 'user-1');

    expect(result.messages).toEqual([
      expect.objectContaining({
        id: 'msg-plain',
        content: 'hello',
      }),
      expect.objectContaining({
        id: 'msg-encrypted',
        content: null,
        encrypted_content: encryptedEnvelope,
        metadata: {
          mentions: [{ user_id: 'user-1' }],
        },
      }),
    ]);
  });

  it('preserves older key_id values when serializing messages after rotation', async () => {
    const oldEnvelope = {
      version: 1,
      alg: 'AES-256-GCM',
      key_id: 'key-old',
      nonce: Buffer.from('older-nonce').toString('base64'),
      ciphertext: Buffer.from('older-ciphertext').toString('base64'),
    };
    const newEnvelope = {
      version: 1,
      alg: 'AES-256-GCM',
      key_id: 'key-new',
      nonce: Buffer.from('newer-nonce').toString('base64'),
      ciphertext: Buffer.from('newer-ciphertext').toString('base64'),
    };
    const getMany = jest.fn().mockResolvedValue([
      {
        id: 'msg-new',
        conv_id: 'conv-1',
        sender_id: 'user-1',
        type: 'text',
        content: null,
        reply_to_id: null,
        metadata: { encrypted_content: newEnvelope },
        created_at: new Date('2026-05-01T10:05:00.000Z'),
      },
      {
        id: 'msg-old',
        conv_id: 'conv-1',
        sender_id: 'user-1',
        type: 'text',
        content: null,
        reply_to_id: null,
        metadata: { encrypted_content: oldEnvelope },
        created_at: new Date('2026-05-01T10:00:00.000Z'),
      },
    ]);
    const queryBuilder = {
      where: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      getMany,
    };

    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    messageRepo.createQueryBuilder.mockReturnValue(queryBuilder);
    reactionRepo.query.mockResolvedValue([]);

    const result = await service.getMessages('conv-1', 'user-1');

    expect(
      result.messages.map((message: any) => message.encrypted_content?.key_id),
    ).toEqual(['key-old', 'key-new']);
  });

  it('replaces blind index hashes when an encrypted message is edited', async () => {
    const oldEnvelope = {
      version: 1,
      alg: 'AES-256-GCM',
      key_id: 'key-1',
      nonce: Buffer.from('old-nonce-value').toString('base64'),
      ciphertext: Buffer.from('old-ciphertext-123456').toString('base64'),
    };
    const newEnvelope = {
      version: 1,
      alg: 'AES-256-GCM',
      key_id: 'key-1',
      nonce: Buffer.from('new-nonce-value').toString('base64'),
      ciphertext: Buffer.from('new-ciphertext-123456').toString('base64'),
    };

    messageRepo.findOne
      .mockResolvedValueOnce({
        id: 'msg-1',
        conv_id: 'conv-1',
        sender_id: 'user-1',
        type: 'text',
        content: null,
        metadata: { encrypted_content: oldEnvelope },
        deleted_at: null,
      })
      .mockResolvedValueOnce({
        id: 'msg-1',
        conv_id: 'conv-1',
        sender_id: 'user-1',
        type: 'text',
        content: '[Tin nhắn mã hóa]',
        metadata: { encrypted_content: newEnvelope },
        edited_at: new Date('2026-05-01T10:05:00.000Z'),
      });
    messageRepo.query.mockResolvedValue(undefined);
    blindIndexRepo.delete.mockResolvedValue(undefined);
    blindIndexRepo.query.mockResolvedValue(undefined);
    redisPubSub.publish.mockResolvedValue(undefined);

    await service.editMessage(
      'user-1',
      'msg-1',
      undefined,
      { encrypted_content: newEnvelope },
      {
        version: 1,
        algo: 'hmac-sha256',
        tokens: ['c'.repeat(64), 'd'.repeat(64)],
      },
    );

    expect(blindIndexRepo.delete).toHaveBeenCalledWith({ message_id: 'msg-1' });
    expect(blindIndexRepo.query).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO message_blind_indexes'),
      ['msg-1', 'conv-1', ['c'.repeat(64), 'd'.repeat(64)]],
    );
  });

  it('rejects invalid blind index payloads during encrypted edits', async () => {
    const envelope = {
      version: 1,
      alg: 'AES-256-GCM',
      key_id: 'key-1',
      nonce: Buffer.from('new-nonce-value').toString('base64'),
      ciphertext: Buffer.from('new-ciphertext-123456').toString('base64'),
    };

    messageRepo.findOne.mockResolvedValueOnce({
      id: 'msg-1',
      conv_id: 'conv-1',
      sender_id: 'user-1',
      type: 'text',
      content: null,
      metadata: { encrypted_content: envelope },
      deleted_at: null,
    });

    await expect(
      service.editMessage(
        'user-1',
        'msg-1',
        undefined,
        { encrypted_content: envelope },
        {
          version: 1,
          algo: 'wrong',
          tokens: ['not-a-hash'],
        },
      ),
    ).rejects.toMatchObject({ code: 'INVALID_FORMAT' });
  });

  it('deletes blind index hashes when a message is recalled', async () => {
    messageRepo.findOne
      .mockResolvedValueOnce({
        id: 'msg-1',
        conv_id: 'conv-1',
        sender_id: 'user-1',
        type: 'text',
        content: null,
        metadata: null,
        deleted_at: null,
      })
      .mockResolvedValueOnce({
        id: 'msg-1',
        conv_id: 'conv-1',
        sender_id: 'user-1',
        type: 'text',
        content: null,
        metadata: { recalled_by: 'user-1' },
        deleted_at: new Date('2026-05-01T10:10:00.000Z'),
      });
    messageRepo.query.mockResolvedValue(undefined);
    blindIndexRepo.delete.mockResolvedValue(undefined);
    redisPubSub.publish.mockResolvedValue(undefined);

    await service.recallMessage('user-1', 'msg-1');

    expect(blindIndexRepo.delete).toHaveBeenCalledWith({ message_id: 'msg-1' });
  });
});

describe('ChatService file messages', () => {
  let service: ChatService;
  const convRepo = createRepoMock();
  const encryptionKeyRepo = createRepoMock();
  const memberRepo = createRepoMock();
  const blindIndexRepo = createRepoMock();
  const messageRepo = createRepoMock();
  const bookmarkRepo = createRepoMock();
  const reminderRepo = createRepoMock();
  const reactionRepo = createRepoMock();
  const pinnedRepo = createRepoMock();
  const userRepo = createRepoMock();
  const redisPubSub = {
    publish: jest.fn(),
    publishUserEvent: jest.fn(),
    subscribeConversation: jest.fn(),
  };
  const notificationJob = {
    enqueuePush: jest.fn(),
    enqueueGroupMembershipAdded: jest.fn(),
  };
  const connectionManager = {
    isOnline: jest.fn(),
    getConnections: jest.fn(),
  };
  const reminderJobService = {
    scheduleReminder: jest.fn(),
    removeReminder: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ChatService,
        { provide: getRepositoryToken(Conversation), useValue: convRepo },
        {
          provide: getRepositoryToken(ConversationEncryptionKey),
          useValue: encryptionKeyRepo,
        },
        {
          provide: getRepositoryToken(ConversationMember),
          useValue: memberRepo,
        },
        {
          provide: getRepositoryToken(MessageBlindIndex),
          useValue: blindIndexRepo,
        },
        { provide: getRepositoryToken(Message), useValue: messageRepo },
        {
          provide: getRepositoryToken(MessageBookmark),
          useValue: bookmarkRepo,
        },
        {
          provide: getRepositoryToken(MessageReminder),
          useValue: reminderRepo,
        },
        {
          provide: getRepositoryToken(MessageReaction),
          useValue: reactionRepo,
        },
        { provide: getRepositoryToken(PinnedMessage), useValue: pinnedRepo },
        { provide: getRepositoryToken(User), useValue: userRepo },
        {
          provide: RedisPubSubService,
          useValue: redisPubSub,
        },
        {
          provide: NotificationJobService,
          useValue: notificationJob,
        },
        {
          provide: ReminderJobService,
          useValue: reminderJobService,
        },
        {
          provide: ConnectionManager,
          useValue: connectionManager,
        },
      ],
    }).compile();

    service = module.get(ChatService);
  });

  it('persists normalized metadata for file messages', async () => {
    const metadata = {
      url: '/uploads/chat/report.pdf',
      originalName: 'report.pdf',
      mimeType: 'application/pdf',
      size: 153248,
    };
    const savedMessage = {
      id: 'msg-1',
      conv_id: 'conv-1',
      sender_id: 'user-1',
      type: 'file',
      content: 'report.pdf',
      metadata,
      created_at: new Date('2026-05-01T10:00:00.000Z'),
    };

    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    messageRepo.query.mockResolvedValue([savedMessage]);
    convRepo.update.mockResolvedValue(undefined);
    convRepo.findOne.mockResolvedValue({
      id: 'conv-1',
      type: 'GROUP',
      name: 'Files',
    });
    memberRepo.find.mockResolvedValue([
      { user_id: 'user-1', is_muted: false },
      { user_id: 'user-2', is_muted: false },
    ]);
    notificationJob.enqueuePush.mockResolvedValue(undefined);
    redisPubSub.publish.mockResolvedValue(undefined);

    const result = await service.sendMessage('user-1', {
      id: 'msg-1',
      conv_id: 'conv-1',
      type: 'file',
      metadata,
    });

    expect(messageRepo.query).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO messages'),
      expect.arrayContaining([
        'msg-1',
        'conv-1',
        'user-1',
        'file',
        'report.pdf',
        JSON.stringify(metadata),
      ]),
    );
    expect(redisPubSub.publish).toHaveBeenCalledWith(
      'conv-1',
      expect.objectContaining({
        id: 'msg-1',
        type: 'file',
        content: 'report.pdf',
        metadata,
      }),
    );
    expect(result).toEqual(savedMessage);
  });

  it('rejects file messages with incomplete attachment metadata', async () => {
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });

    await expect(
      service.sendMessage('user-1', {
        id: 'msg-1',
        conv_id: 'conv-1',
        type: 'file',
        metadata: {
          url: '/uploads/chat/report.pdf',
          originalName: 'report.pdf',
          mimeType: 'application/pdf',
        },
      }),
    ).rejects.toMatchObject({ code: 'INVALID_FORMAT' });

    expect(messageRepo.query).not.toHaveBeenCalled();
  });

  it('returns file message metadata unchanged in message history', async () => {
    const metadata = {
      url: '/uploads/chat/report.pdf',
      originalName: 'report.pdf',
      mimeType: 'application/pdf',
      size: 153248,
    };
    const getMany = jest.fn().mockResolvedValue([
      {
        id: 'msg-1',
        conv_id: 'conv-1',
        sender_id: 'user-1',
        type: 'file',
        content: 'report.pdf',
        reply_to_id: null,
        metadata,
        created_at: new Date('2026-05-01T10:00:00.000Z'),
      },
    ]);
    const queryBuilder = {
      where: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      getMany,
    };

    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    messageRepo.createQueryBuilder.mockReturnValue(queryBuilder);
    reactionRepo.query.mockResolvedValue([]);

    const result = await service.getMessages('conv-1', 'user-1');

    expect(result.messages).toEqual([
      expect.objectContaining({
        id: 'msg-1',
        type: 'file',
        content: 'report.pdf',
        metadata,
        reactions: [],
      }),
    ]);
  });

  it('continues updating read cursors and notifying other members when marking a message as read', async () => {
    const socket = { readyState: 1, send: jest.fn() };
    memberRepo.update.mockResolvedValue({ affected: 1 });
    memberRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      conv_id: 'conv-1',
      last_read_message_id: null,
    });
    messageRepo.findOne.mockResolvedValue({
      id: 'msg-1',
      conv_id: 'conv-1',
      created_at: new Date('2026-05-05T10:00:00.000Z'),
    });
    memberRepo.find.mockResolvedValue([
      { user_id: 'user-1' },
      { user_id: 'user-2' },
    ]);
    connectionManager.getConnections.mockReturnValue([socket]);

    await service.markRead('user-1', {
      conv_id: 'conv-1',
      message_id: 'msg-1',
    });

    expect(memberRepo.update).toHaveBeenCalledWith(
      { conv_id: 'conv-1', user_id: 'user-1' },
      {
        last_read_message_id: 'msg-1',
        last_read_at: expect.any(Date),
      },
    );
    const emitted = JSON.parse(socket.send.mock.calls[0][0]);
    expect(emitted).toMatchObject({
      event: 'message_read',
      data: {
        conv_id: 'conv-1',
        message_id: 'msg-1',
        reader_id: 'user-1',
        user_id: 'user-1',
      },
    });
    expect(typeof emitted.data.seen_at).toBe('string');
  });

  it('does not emit message_read when the user marks the same message as read again', async () => {
    memberRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      conv_id: 'conv-1',
      last_read_message_id: 'msg-1',
    });
    messageRepo.findOne.mockResolvedValue({
      id: 'msg-1',
      conv_id: 'conv-1',
      created_at: new Date('2026-05-05T10:00:00.000Z'),
    });

    await service.markRead('user-1', {
      conv_id: 'conv-1',
      message_id: 'msg-1',
    });

    expect(memberRepo.update).not.toHaveBeenCalled();
    expect(memberRepo.find).not.toHaveBeenCalled();
    expect(connectionManager.getConnections).not.toHaveBeenCalled();
  });

  it('does not emit message_read when the requested read progress would move backwards', async () => {
    memberRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      conv_id: 'conv-1',
      last_read_message_id: 'msg-2',
    });
    messageRepo.findOne
      .mockResolvedValueOnce({
        id: 'msg-1',
        conv_id: 'conv-1',
        created_at: new Date('2026-05-05T10:00:00.000Z'),
      })
      .mockResolvedValueOnce({
        id: 'msg-2',
        conv_id: 'conv-1',
        created_at: new Date('2026-05-05T10:05:00.000Z'),
      });

    await service.markRead('user-1', {
      conv_id: 'conv-1',
      message_id: 'msg-1',
    });

    expect(memberRepo.update).not.toHaveBeenCalled();
    expect(memberRepo.find).not.toHaveBeenCalled();
    expect(connectionManager.getConnections).not.toHaveBeenCalled();
  });
});

describe('ChatService message search', () => {
  let service: ChatService;
  const convRepo = createRepoMock();
  const encryptionKeyRepo = createRepoMock();
  const memberRepo = createRepoMock();
  const blindIndexRepo = createRepoMock();
  const messageRepo = createRepoMock();
  const bookmarkRepo = createRepoMock();
  const reminderRepo = createRepoMock();
  const reactionRepo = createRepoMock();
  const pinnedRepo = createRepoMock();
  const userRepo = createRepoMock();
  const redisPubSub = {
    publish: jest.fn(),
    publishUserEvent: jest.fn(),
    subscribeConversation: jest.fn(),
  };
  const notificationJob = {
    enqueuePush: jest.fn(),
    enqueueGroupMembershipAdded: jest.fn(),
  };
  const connectionManager = {
    isOnline: jest.fn(),
    getConnections: jest.fn(),
  };
  const reminderJobService = {
    scheduleReminder: jest.fn(),
    removeReminder: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ChatService,
        { provide: getRepositoryToken(Conversation), useValue: convRepo },
        {
          provide: getRepositoryToken(ConversationEncryptionKey),
          useValue: encryptionKeyRepo,
        },
        {
          provide: getRepositoryToken(ConversationMember),
          useValue: memberRepo,
        },
        {
          provide: getRepositoryToken(MessageBlindIndex),
          useValue: blindIndexRepo,
        },
        { provide: getRepositoryToken(Message), useValue: messageRepo },
        {
          provide: getRepositoryToken(MessageBookmark),
          useValue: bookmarkRepo,
        },
        {
          provide: getRepositoryToken(MessageReminder),
          useValue: reminderRepo,
        },
        {
          provide: getRepositoryToken(MessageReaction),
          useValue: reactionRepo,
        },
        { provide: getRepositoryToken(PinnedMessage), useValue: pinnedRepo },
        { provide: getRepositoryToken(User), useValue: userRepo },
        {
          provide: RedisPubSubService,
          useValue: redisPubSub,
        },
        {
          provide: NotificationJobService,
          useValue: notificationJob,
        },
        {
          provide: ReminderJobService,
          useValue: reminderJobService,
        },
        {
          provide: ConnectionManager,
          useValue: connectionManager,
        },
      ],
    }).compile();

    service = module.get(ChatService);
  });

  it('searches accessible conversations with the authenticated user id', async () => {
    const row = {
      id: 'msg-1',
      conv_id: 'conv-1',
      sender_id: 'user-2',
      type: 'text',
      content: 'hi',
      created_at: new Date('2026-05-04T08:00:00.000Z'),
      snippet: '<mark>hi</mark>',
      conv_name: 'Team chat',
      conv_type: 'GROUP',
      conv_avatar_url: null,
      sender_name: 'User 2',
      relevance: 1,
    };
    memberRepo.find.mockResolvedValue([{ conv_id: 'conv-1' }]);
    messageRepo.query
      .mockResolvedValueOnce(undefined)
      .mockResolvedValueOnce([row]);

    const result = await service.searchMessages('user-1', ' hi ');

    expect(memberRepo.find).toHaveBeenCalledWith({
      where: { user_id: 'user-1' },
      select: ['conv_id'],
    });
    expect(messageRepo.query).toHaveBeenNthCalledWith(
      1,
      `SET LOCAL statement_timeout = '5000'`,
    );
    expect(messageRepo.query).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining(
        'INNER JOIN conversation_members cm ON cm.conv_id = m.conv_id AND cm.user_id = $5',
      ),
      ['hi', 'hi:*', '%hi%', 0.2, 'user-1', 21],
    );
    expect(result).toEqual({
      results: [row],
      next_cursor: null,
      has_more: false,
    });
  });

  it('returns no results for an inaccessible conversation filter without querying messages', async () => {
    memberRepo.find.mockResolvedValue([{ conv_id: 'conv-1' }]);

    const result = await service.searchMessages('user-1', 'hi', 'conv-2');

    expect(result).toEqual({
      results: [],
      next_cursor: null,
      has_more: false,
    });
    expect(messageRepo.query).not.toHaveBeenCalled();
  });

  it('filters deleted messages at the SQL layer for accessible searches', async () => {
    memberRepo.find.mockResolvedValue([{ conv_id: 'conv-1' }]);
    messageRepo.query
      .mockResolvedValueOnce(undefined)
      .mockResolvedValueOnce([]);

    await service.searchMessages('user-1', 'hi', 'conv-1');

    expect(messageRepo.query).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining('AND m.deleted_at IS NULL'),
      ['hi', 'hi:*', '%hi%', 0.2, 'user-1', 'conv-1', 21],
    );
  });

  it('searches blind-index hashes within a single accessible conversation', async () => {
    const row = {
      id: 'msg-1',
      conv_id: 'conv-1',
      sender_id: 'user-2',
      type: 'text',
      content: null,
      created_at: new Date('2026-05-04T08:00:00.000Z'),
      snippet: '',
      conv_name: 'Team chat',
      conv_type: 'GROUP',
      conv_avatar_url: null,
      sender_name: 'User 2',
    };
    memberRepo.find.mockResolvedValue([{ conv_id: 'conv-1' }]);
    messageRepo.query
      .mockResolvedValueOnce(undefined)
      .mockResolvedValueOnce([row]);

    const result = await service.searchMessages(
      'user-1',
      undefined,
      'conv-1',
      undefined,
      20,
      ['a'.repeat(64), 'b'.repeat(64)],
    );

    expect(messageRepo.query).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining('INNER JOIN message_blind_indexes bi'),
      ['conv-1', ['a'.repeat(64), 'b'.repeat(64)], 2, 21],
    );
    expect(result).toEqual({
      results: [row],
      next_cursor: null,
      has_more: false,
    });
  });

  it('rejects blind-index search without conversation scope', async () => {
    memberRepo.find.mockResolvedValue([{ conv_id: 'conv-1' }]);

    await expect(
      service.searchMessages('user-1', undefined, undefined, undefined, 20, [
        'a'.repeat(64),
      ]),
    ).rejects.toMatchObject({ code: 'INVALID_FORMAT' });
  });
});
