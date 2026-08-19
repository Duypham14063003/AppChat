import { Test, TestingModule } from '@nestjs/testing';
import { getQueueToken } from '@nestjs/bullmq';
import { ReminderJobService } from './reminder-job.service';

describe('ReminderJobService', () => {
  let service: ReminderJobService;
  const reminderQueue = {
    add: jest.fn(),
    getJob: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    reminderQueue.getJob.mockResolvedValue(null);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ReminderJobService,
        {
          provide: getQueueToken('chat-reminders'),
          useValue: reminderQueue,
        },
      ],
    }).compile();

    service = module.get(ReminderJobService);
  });

  it('schedules reminders with a BullMQ-safe job id', async () => {
    await service.scheduleReminder({
      id: 'reminder-1',
      remind_at: new Date(Date.now() + 60_000),
    } as any);

    expect(reminderQueue.add).toHaveBeenCalledWith(
      'fire-reminder',
      { reminderId: 'reminder-1' },
      expect.objectContaining({
        jobId: 'chat-reminder-reminder-1',
      }),
    );
  });
});
