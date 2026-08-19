import { Processor, WorkerHost, InjectQueue } from '@nestjs/bullmq';
import { Logger, OnModuleInit } from '@nestjs/common';
import { Queue } from 'bullmq';
import { RewardsService } from '../rewards.service.js';
import { OdooService } from '../../auth/services/odoo.service.js';
import { TaskService } from '../../task/services/task.service.js';

export const ODOO_TASK_REWARD_QUEUE = 'odoo-task-reward';

@Processor(ODOO_TASK_REWARD_QUEUE)
export class OdooTaskRewardProcessor extends WorkerHost implements OnModuleInit {
  private readonly logger = new Logger(OdooTaskRewardProcessor.name);

  constructor(
    private readonly rewardsService: RewardsService,
    private readonly odooService: OdooService,
    private readonly taskService: TaskService,
    @InjectQueue(ODOO_TASK_REWARD_QUEUE) private readonly queue: Queue,
  ) {
    super();
  }

  async onModuleInit(): Promise<void> {
    try {
      // Actively remove the persistent repeatable job scheduler from Redis
      await this.queue.removeJobScheduler('daily-odoo-task-reward');
      this.logger.log(
        'Successfully removed persistent job scheduler: daily-odoo-task-reward',
      );
    } catch (error) {
      this.logger.error(
        `Failed to remove job scheduler from Redis: ${error}`,
      );
    }
  }

  async process(): Promise<void> {
    this.logger.warn(
      'Daily Odoo task reward processing is disabled. Skipping execution.',
    );
  }
}
