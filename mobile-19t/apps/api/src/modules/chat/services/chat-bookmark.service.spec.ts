import { ChatService } from './chat.service';
import { BookmarkConversationTypeFilterDto } from '../dto/chat.dto.js';

describe('ChatService bookmarks', () => {
  const convRepo = {} as any;
  const memberRepo = {
    findOne: jest.fn(),
  } as any;
  const messageRepo = {
    findOne: jest.fn(),
    update: jest.fn(),
    query: jest.fn(),
  } as any;
  const reactionRepo = {
    query: jest.fn(),
  } as any;
  const pinnedMessageRepo = {} as any;
  const messageBookmarkRepo = {
    findOne: jest.fn(),
    save: jest.fn(),
    create: jest.fn((value) => value),
    delete: jest.fn(),
    query: jest.fn(),
  } as any;
  const messageReminderRepo = {} as any;
  const userRepo = {} as any;
  const reminderQueue = {} as any;
  const redisPubSub = {
    publish: jest.fn(),
  } as any;
  const notificationJob = {} as any;
  const connectionManager = {} as any;

  let service: ChatService;

  beforeEach(() => {
    jest.clearAllMocks();
    reactionRepo.query.mockResolvedValue([]);
    messageRepo.query.mockResolvedValue([]);
    service = new ChatService(
      convRepo,
      memberRepo,
      messageRepo,
      reactionRepo,
      pinnedMessageRepo,
      messageBookmarkRepo,
      messageReminderRepo,
      userRepo,
      reminderQueue,
      redisPubSub,
      notificationJob,
      connectionManager,
    );
  });

  it('bookmarks a message only when the user is a conversation member', async () => {
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    messageRepo.findOne.mockResolvedValue({
      id: 'msg-1',
      conv_id: 'conv-1',
    });
    messageBookmarkRepo.findOne.mockResolvedValue(null);

    await service.bookmarkMessage('user-1', 'conv-1', 'msg-1');

    expect(messageBookmarkRepo.save).toHaveBeenCalledWith({
      user_id: 'user-1',
      conv_id: 'conv-1',
      message_id: 'msg-1',
    });
  });

  it('rejects duplicate bookmarks for the same user and message', async () => {
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    messageRepo.findOne.mockResolvedValue({
      id: 'msg-1',
      conv_id: 'conv-1',
    });
    messageBookmarkRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      conv_id: 'conv-1',
      message_id: 'msg-1',
    });

    await expect(
      service.bookmarkMessage('user-1', 'conv-1', 'msg-1'),
    ).rejects.toMatchObject({
      code: 'ALREADY_BOOKMARKED',
    });
    expect(messageBookmarkRepo.save).not.toHaveBeenCalled();
  });

  it('deletes only the current user bookmark record', async () => {
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    messageBookmarkRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      conv_id: 'conv-1',
      message_id: 'msg-1',
    });

    await service.removeBookmark('user-1', 'conv-1', 'msg-1');

    expect(messageBookmarkRepo.delete).toHaveBeenCalledWith({
      user_id: 'user-1',
      conv_id: 'conv-1',
      message_id: 'msg-1',
    });
  });

  it('lists bookmarks only for the current user and conversation', async () => {
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    messageBookmarkRepo.query.mockResolvedValue([
      { user_id: 'user-1', conv_id: 'conv-1', message_id: 'msg-1' },
    ]);

    const result = await service.getBookmarkedMessages('user-1', 'conv-1');

    expect(messageBookmarkRepo.query).toHaveBeenCalledWith(
      expect.stringContaining('FROM message_bookmarks b'),
      ['user-1', 'conv-1'],
    );
    expect(result).toEqual([
      { user_id: 'user-1', conv_id: 'conv-1', message_id: 'msg-1' },
    ]);
  });

  it('lists global bookmarks only for the current user across accessible conversations', async () => {
    const row = {
      user_id: 'user-1',
      conv_id: 'conv-1',
      message_id: 'msg-1',
      marked_at: new Date('2026-04-24T03:00:00.000Z'),
      conversation_type: 'DIRECT',
      conversation_name: 'Jane Doe',
      conversation_avatar_url: null,
    };
    messageBookmarkRepo.query.mockResolvedValue([row]);

    const result = await service.getGlobalBookmarkedMessages('user-1');

    expect(messageBookmarkRepo.query).toHaveBeenCalledWith(
      expect.stringContaining('FROM message_bookmarks b'),
      ['user-1', 21],
    );
    const sql = messageBookmarkRepo.query.mock.calls[0][0] as string;
    expect(sql).toContain('cm.user_id = $1');
    expect(sql).toContain('b.user_id = $1');
    expect(sql).toContain('m.deleted_at IS NULL');
    expect(result).toEqual({
      items: [row],
      next_cursor: null,
      has_more: false,
    });
  });

  it('supports conversation-type filtering and cursor pagination for the global inbox', async () => {
    messageBookmarkRepo.query.mockResolvedValue([
      {
        user_id: 'user-1',
        conv_id: 'conv-2',
        message_id: 'msg-2',
        marked_at: new Date('2026-04-24T03:00:00.000Z'),
        conversation_type: 'DIRECT',
        conversation_name: 'Jane Doe',
        conversation_avatar_url: null,
      },
      {
        user_id: 'user-1',
        conv_id: 'conv-1',
        message_id: 'msg-1',
        marked_at: new Date('2026-04-24T02:00:00.000Z'),
        conversation_type: 'DIRECT',
        conversation_name: 'John Doe',
        conversation_avatar_url: null,
      },
    ]);

    const result = await service.getGlobalBookmarkedMessages('user-1', {
      convType: BookmarkConversationTypeFilterDto.DIRECT,
      cursor: '2026-04-24T04:00:00.000Z_msg-9',
      limit: 1,
    });

    const [sql, params] = messageBookmarkRepo.query.mock.calls[0] as [
      string,
      unknown[],
    ];
    expect(sql).toContain('c.type = $2');
    expect(sql).toContain('(b.marked_at, b.message_id) < ($3, $4)');
    expect(params).toEqual([
      'user-1',
      'DIRECT',
      '2026-04-24T04:00:00.000Z',
      'msg-9',
      2,
    ]);
    expect(result).toEqual({
      items: [
        {
          user_id: 'user-1',
          conv_id: 'conv-2',
          message_id: 'msg-2',
          marked_at: new Date('2026-04-24T03:00:00.000Z'),
          conversation_type: 'DIRECT',
          conversation_name: 'Jane Doe',
          conversation_avatar_url: null,
        },
      ],
      next_cursor: '2026-04-24T03:00:00.000Z_msg-2',
      has_more: true,
    });
  });

  it('edits only the sender-owned text message and publishes an update', async () => {
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    messageRepo.findOne
      .mockResolvedValueOnce({
        id: 'msg-1',
        conv_id: 'conv-1',
        sender_id: 'user-1',
        type: 'text',
        content: 'before',
        deleted_at: null,
      })
      .mockResolvedValueOnce({
        id: 'msg-1',
        conv_id: 'conv-1',
        sender_id: 'user-1',
        type: 'text',
        content: 'after',
        deleted_at: null,
        edited_at: new Date('2026-04-22T10:00:00.000Z'),
      });

    const result = await service.editMessage(
      'user-1',
      'conv-1',
      'msg-1',
      'after',
    );

    expect(messageRepo.update).toHaveBeenCalledWith(
      { id: 'msg-1', conv_id: 'conv-1' },
      expect.objectContaining({ content: 'after' }),
    );
    expect(redisPubSub.publish).toHaveBeenCalledWith(
      'conv-1',
      expect.objectContaining({
        id: 'msg-1',
        content: 'after',
        _event: 'message_updated',
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        id: 'msg-1',
        content: 'after',
      }),
    );
  });

  it('rejects recalling a message twice', async () => {
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-1',
    });
    messageRepo.findOne.mockResolvedValue({
      id: 'msg-1',
      conv_id: 'conv-1',
      sender_id: 'user-1',
      type: 'text',
      deleted_at: new Date('2026-04-22T10:00:00.000Z'),
    });

    await expect(
      service.recallMessage('user-1', 'conv-1', 'msg-1'),
    ).rejects.toMatchObject({
      code: 'ALREADY_RECALLED',
    });
    expect(messageRepo.update).not.toHaveBeenCalled();
  });
});
