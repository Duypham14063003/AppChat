import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ChatReminderProcessor } from './chat-reminder.processor';
import { ChatService } from '../services/chat.service';
import { FirebaseService } from '../../notification/services/firebase.service';
import { UserSession } from '../../auth/entities/user-session.entity';

describe('ChatReminderProcessor', () => {
  let processor: ChatReminderProcessor;
  const chatService = {
    fireReminder: jest.fn(),
  };
  const firebaseService = {
    isEnabled: jest.fn(),
    sendPush: jest.fn(),
  };
  const sessionRepo = {
    find: jest.fn(),
    update: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    firebaseService.isEnabled.mockReturnValue(true);
    firebaseService.sendPush.mockResolvedValue(true);
    sessionRepo.find.mockResolvedValue([
      { id: 'session-1', fcm_token: 'fcm-1' },
    ]);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ChatReminderProcessor,
        { provide: ChatService, useValue: chatService },
        { provide: FirebaseService, useValue: firebaseService },
        { provide: getRepositoryToken(UserSession), useValue: sessionRepo },
      ],
    }).compile();

    processor = module.get(ChatReminderProcessor);
  });

  it('fires a reminder and pushes to all resolved recipients', async () => {
    chatService.fireReminder.mockResolvedValue({
      recipientUserIds: ['user-1', 'user-2'],
      pushTitle: 'Chat reminder',
      pushBody: 'Important note',
      pushData: {
        type: 'chat_reminder',
        conv_id: 'conv-1',
        message_id: 'msg-1',
        reminder_id: 'reminder-1',
      },
    });
    sessionRepo.find
      .mockResolvedValueOnce([{ id: 'session-1', fcm_token: 'token-1' }])
      .mockResolvedValueOnce([{ id: 'session-2', fcm_token: 'token-2' }]);

    await processor.process({
      data: { reminderId: 'reminder-1' },
    } as any);

    expect(chatService.fireReminder).toHaveBeenCalledWith('reminder-1');
    expect(firebaseService.sendPush).toHaveBeenCalledTimes(2);
    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'token-1',
      'Chat reminder',
      'Important note',
      expect.objectContaining({
        type: 'chat_reminder',
        conv_id: 'conv-1',
        message_id: 'msg-1',
        reminder_id: 'reminder-1',
      }),
    );
  });

  it('is idempotent when the reminder was already processed', async () => {
    chatService.fireReminder.mockResolvedValue(null);

    await processor.process({
      data: { reminderId: 'reminder-1' },
    } as any);

    expect(firebaseService.sendPush).not.toHaveBeenCalled();
    expect(sessionRepo.find).not.toHaveBeenCalled();
  });
});
