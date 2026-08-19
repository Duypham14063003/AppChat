import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { PushNotificationProcessor } from './push-notification.processor';
import { FirebaseService } from './firebase.service';
import { UserSession } from '../../auth/entities/user-session.entity';
import { User } from '../../auth/entities/user.entity';
import { ConversationMember } from '../../chat/entities/conversation-member.entity';
import { Message } from '../../chat/entities/message.entity';

describe('PushNotificationProcessor', () => {
  let processor: PushNotificationProcessor;
  const firebaseService = {
    isEnabled: jest.fn(),
    sendPush: jest.fn(),
  };
  const sessionRepo = {
    find: jest.fn(),
    update: jest.fn(),
  };
  const userRepo = {
    findOne: jest.fn(),
  };
  const memberRepo = {
    findOne: jest.fn(),
  };
  const messageRepo = {
    query: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    firebaseService.isEnabled.mockReturnValue(true);
    firebaseService.sendPush.mockResolvedValue(true);
    sessionRepo.find.mockResolvedValue([
      { id: 'session-1', fcm_token: 'fcm-1' },
    ]);
    userRepo.findOne.mockResolvedValue({ name: 'Jane Doe' });
    memberRepo.findOne.mockResolvedValue({ is_muted: false });
    messageRepo.query.mockResolvedValue([{ cnt: '5' }]);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PushNotificationProcessor,
        { provide: FirebaseService, useValue: firebaseService },
        { provide: getRepositoryToken(UserSession), useValue: sessionRepo },
        { provide: getRepositoryToken(User), useValue: userRepo },
        {
          provide: getRepositoryToken(ConversationMember),
          useValue: memberRepo,
        },
        { provide: getRepositoryToken(Message), useValue: messageRepo },
      ],
    }).compile();

    processor = module.get(PushNotificationProcessor);
  });

  it('keeps direct chat notifications sender-focused', async () => {
    await processor.process({
      data: {
        recipientUserId: 'user-1',
        senderId: 'sender-1',
        convId: 'conv-1',
        messageId: 'msg-1',
        content: 'Hi there',
        type: 'text',
        isMentioned: false,
        isMentionAll: false,
        conversationType: 'DIRECT',
        conversationName: null,
      },
    } as any);

    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'fcm-1',
      'Jane Doe',
      'Hi there',
      expect.objectContaining({
        conv_id: 'conv-1',
        message_id: 'msg-1',
        type: 'chat_message',
        conv_type: 'DIRECT',
      }),
      5,
    );
  });

  it('skips push delivery when the sender and recipient are the same user', async () => {
    await processor.process({
      data: {
        recipientUserId: 'user-1',
        senderId: 'user-1',
        convId: 'conv-1',
        messageId: 'msg-1',
        content: 'Hi there',
        type: 'text',
        isMentioned: false,
        isMentionAll: false,
        conversationType: 'DIRECT',
        conversationName: null,
      },
    } as any);

    expect(memberRepo.findOne).not.toHaveBeenCalled();
    expect(sessionRepo.find).not.toHaveBeenCalled();
    expect(firebaseService.sendPush).not.toHaveBeenCalled();
  });

  it('falls back to a generic preview when no decrypted/plaintext content is available', async () => {
    await processor.process({
      data: {
        recipientUserId: 'user-1',
        senderId: 'sender-1',
        convId: 'conv-1',
        messageId: 'msg-1',
        content: null,
        type: 'text',
        isMentioned: false,
        isMentionAll: false,
        conversationType: 'DIRECT',
        conversationName: null,
      },
    } as any);

    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'fcm-1',
      'Jane Doe',
      'Bạn có tin nhắn mới',
      expect.objectContaining({
        conv_id: 'conv-1',
        message_id: 'msg-1',
      }),
      5,
    );
  });

  it('renders group chat notifications with conversation title and sender attribution', async () => {
    await processor.process({
      data: {
        recipientUserId: 'user-1',
        senderId: 'sender-1',
        convId: 'conv-1',
        messageId: 'msg-1',
        content: 'Deployment complete',
        type: 'text',
        isMentioned: false,
        isMentionAll: false,
        conversationType: 'GROUP',
        conversationName: 'Backend Team',
      },
    } as any);

    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'fcm-1',
      'Backend Team',
      'Jane Doe: Deployment complete',
      expect.objectContaining({
        conv_type: 'GROUP',
        conv_name: 'Backend Team',
      }),
      5,
    );
  });

  it('uses a fallback label when the group name is missing', async () => {
    await processor.process({
      data: {
        recipientUserId: 'user-1',
        senderId: 'sender-1',
        convId: 'conv-1',
        messageId: 'msg-1',
        content: 'Hello',
        type: 'text',
        isMentioned: false,
        isMentionAll: false,
        conversationType: 'GROUP',
        conversationName: null,
      },
    } as any);

    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'fcm-1',
      'Group chat',
      'Jane Doe: Hello',
      expect.objectContaining({
        conv_type: 'GROUP',
        conv_name: 'Group chat',
      }),
      5,
    );
  });

  it('keeps group mention notifications identifiable', async () => {
    await processor.process({
      data: {
        recipientUserId: 'user-1',
        senderId: 'sender-1',
        convId: 'conv-1',
        messageId: 'msg-1',
        content: 'Please check this',
        type: 'text',
        isMentioned: true,
        isMentionAll: false,
        conversationType: 'GROUP',
        conversationName: 'Backend Team',
      },
    } as any);

    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'fcm-1',
      'Backend Team',
      'Jane Doe đã nhắc đến bạn: Please check this',
      expect.objectContaining({
        is_mention: 'true',
        conv_type: 'GROUP',
      }),
      5,
    );
  });

  it('keeps group mention-all notifications identifiable', async () => {
    await processor.process({
      data: {
        recipientUserId: 'user-1',
        senderId: 'sender-1',
        convId: 'conv-1',
        messageId: 'msg-1',
        content: 'Standup in 5 minutes',
        type: 'text',
        isMentioned: false,
        isMentionAll: true,
        conversationType: 'GROUP',
        conversationName: 'Backend Team',
      },
    } as any);

    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'fcm-1',
      'Backend Team',
      'Jane Doe đã nhắc đến mọi người: Standup in 5 minutes',
      expect.objectContaining({
        conv_type: 'GROUP',
        conv_name: 'Backend Team',
      }),
      5,
    );
  });

  it('computes badge count from total unread chat messages for the recipient', async () => {
    await processor.process({
      data: {
        recipientUserId: 'user-1',
        senderId: 'sender-1',
        convId: 'conv-1',
        messageId: 'msg-1',
        content: 'Hi there',
        type: 'text',
        isMentioned: false,
        isMentionAll: false,
        conversationType: 'DIRECT',
        conversationName: null,
      },
    } as any);

    expect(messageRepo.query).toHaveBeenCalledWith(
      expect.stringContaining('FROM conversation_members cm'),
      ['user-1'],
    );
  });

  it('renders dedicated group membership notifications with actor context', async () => {
    await processor.process({
      data: {
        notificationKind: 'group_membership_added',
        recipientUserId: 'user-1',
        convId: 'conv-1',
        actorId: 'actor-1',
        actorName: 'Jane Doe',
        conversationType: 'GROUP',
        conversationName: 'Backend Team',
      },
    } as any);

    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'fcm-1',
      'Backend Team',
      'Jane Doe đã thêm bạn vào nhóm',
      expect.objectContaining({
        conv_id: 'conv-1',
        type: 'group_membership_added',
        conv_type: 'GROUP',
        conv_name: 'Backend Team',
        actor_id: 'actor-1',
        actor_name: 'Jane Doe',
      }),
      5,
    );
  });
});
