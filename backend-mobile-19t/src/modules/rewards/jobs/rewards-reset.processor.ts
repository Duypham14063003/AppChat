import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { RewardsService } from '../rewards.service.js';

export const REWARDS_RESET_QUEUE = 'rewards-reset';

@Processor(REWARDS_RESET_QUEUE)
export class RewardsResetProcessor extends WorkerHost {
  private readonly logger = new Logger(RewardsResetProcessor.name);

  constructor(private readonly rewardsService: RewardsService) {
    super();
  }

  async process(): Promise<void> {
    this.logger.log('Executing monthly rewards points snapshot and reset...');
    await this.rewardsService.snapshotMonthlyPoints();
  }
}
