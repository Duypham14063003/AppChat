import { Processor, WorkerHost, InjectQueue } from '@nestjs/bullmq';
import { Logger, OnModuleInit } from '@nestjs/common';
import { Queue } from 'bullmq';
import { TaskService } from '../services/task.service.js';

export const TASK_SYNC_QUEUE = 'task-sync';

@Processor(TASK_SYNC_QUEUE)
export class TaskSyncProcessor extends WorkerHost implements OnModuleInit {
  private readonly logger = new Logger(TaskSyncProcessor.name);

  constructor(
    private readonly taskService: TaskService,
    @InjectQueue(TASK_SYNC_QUEUE) private readonly queue: Queue,
  ) {
    super();
  }

  async onModuleInit(): Promise<void> {
    await this.queue.upsertJobScheduler(
      'task-sync-15min',
      { every: 900_000 },
      { opts: { attempts: 3, backoff: { type: 'exponential', delay: 2000 } } },
    );
    this.logger.log('Task sync scheduled: every 15 minutes');
  }

  async process(): Promise<void> {
    try {
      const stages = await this.taskService.getTaskStages(true);
      this.logger.log(`Task sync: ${stages.length} stages cached`);
    } catch (error) {
      this.logger.error(`Task sync failed: ${error}`);
      throw error;
    }
  }
}
