import { Test, TestingModule } from '@nestjs/testing';
import { getQueueToken } from '@nestjs/bullmq';
import { NotificationJobService } from './notification-job.service';

describe('NotificationJobService', () => {
  let service: NotificationJobService;
  const pushQueue = {
    add: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationJobService,
        {
          provide: getQueueToken('chat-push-notification'),
          useValue: pushQueue,
        },
      ],
    }).compile();

    service = module.get(NotificationJobService);
  });

  it('enqueues chat push jobs with conversation context', async () => {
    await service.enqueuePush(
      'user-1',
      {
        id: 'msg-1',
        conv_id: 'conv-1',
        sender_id: 'sender-1',
        type: 'text',
        content: 'Hello group',
      } as any,
      false,
      false,
      { id: 'conv-1', type: 'GROUP', name: 'Backend Team' },
    );

    expect(pushQueue.add).toHaveBeenCalledWith(
      'send-push',
      expect.objectContaining({
        recipientUserId: 'user-1',
        messageId: 'msg-1',
        convId: 'conv-1',
        senderId: 'sender-1',
        conversationType: 'GROUP',
        conversationName: 'Backend Team',
      }),
      expect.any(Object),
    );
  });

  it('enqueues group membership notification jobs with actor context', async () => {
    await service.enqueueGroupMembershipAdded('user-2', 'actor-1', 'Jane Doe', {
      id: 'conv-1',
      type: 'GROUP',
      name: 'Backend Team',
    });

    expect(pushQueue.add).toHaveBeenCalledWith(
      'send-push',
      expect.objectContaining({
        notificationKind: 'group_membership_added',
        recipientUserId: 'user-2',
        convId: 'conv-1',
        actorId: 'actor-1',
        actorName: 'Jane Doe',
        conversationType: 'GROUP',
        conversationName: 'Backend Team',
      }),
      expect.any(Object),
    );
  });
});
