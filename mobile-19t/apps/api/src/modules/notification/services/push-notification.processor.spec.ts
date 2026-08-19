import type { Job } from 'bullmq';
import { PushNotificationProcessor } from './push-notification.processor';

describe('PushNotificationProcessor', () => {
  const firebaseService = {
    isEnabled: jest.fn().mockReturnValue(true),
    sendPush: jest.fn().mockResolvedValue(true),
  } as any;

  const sessionRepo = {
    find: jest.fn(),
    update: jest.fn(),
  } as any;

  const userRepo = {
    findOne: jest.fn(),
  } as any;

  const memberRepo = {
    findOne: jest.fn(),
  } as any;

  const messageRepo = {
    query: jest.fn(),
  } as any;

  let processor: PushNotificationProcessor;

  beforeEach(() => {
    jest.clearAllMocks();
    processor = new PushNotificationProcessor(
      firebaseService,
      sessionRepo,
      userRepo,
      memberRepo,
      messageRepo,
    );
  });

  it('sends computed unread badge count in chat push payloads', async () => {
    memberRepo.findOne.mockResolvedValue({
      conv_id: 'conv-1',
      user_id: 'user-2',
      is_muted: false,
    });
    userRepo.findOne.mockResolvedValue({ name: 'Alice' });
    sessionRepo.find.mockResolvedValue([{ id: 'session-1', fcm_token: 'fcm-1' }]);
    messageRepo.query.mockResolvedValue([{ cnt: '7' }]);

    await processor.process({
      data: {
        recipientUserId: 'user-2',
        senderId: 'user-1',
        convId: 'conv-1',
        messageId: 'msg-1',
        content: 'hello',
        type: 'text',
        isMentioned: false,
        isMentionAll: false,
      },
    } as Job);

    expect(messageRepo.query).toHaveBeenCalledWith(expect.stringContaining('COUNT(*) AS cnt'), [
      'user-2',
    ]);
    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'fcm-1',
      'Alice',
      'hello',
      {
        conv_id: 'conv-1',
        message_id: 'msg-1',
        type: 'chat_message',
        badge_count: '7',
      },
      7,
    );
  });
});
