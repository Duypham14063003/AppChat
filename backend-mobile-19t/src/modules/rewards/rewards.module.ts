import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bullmq';
import { AuthModule } from '../auth/auth.module.js';
import { ChatModule } from '../chat/chat.module.js';
import { UserSession } from '../auth/entities/user-session.entity.js';
import { User } from '../auth/entities/user.entity.js';
import { Role } from '../auth/entities/role.entity.js';
import { UserRole } from '../auth/entities/user-role.entity.js';
import { LeaveRequest } from '../hr/entities/leave-request.entity.js';
import { NotificationModule } from '../notification/notification.module.js';
import { TaskModule } from '../task/task.module.js';
import {
  PointRule,
  PointTransaction,
  RewardItem,
  RewardRedemption,
  UserPointWallet,
  PointPeriodHistory,
  OdooTaskTagConfig,
  JobTitleMultiplier,
  OdooTaskRewardLog,
  InternalRole,
  JobTitleMapping,
} from './entities/index.js';
import { RewardsController } from './rewards.controller.js';
import { RewardsAdminController } from './rewards-admin.controller.js';
import { RewardsService } from './rewards.service.js';
import {
  RewardsResetProcessor,
  REWARDS_RESET_QUEUE,
} from './jobs/rewards-reset.processor.js';
import {
  OdooTaskRewardProcessor,
  ODOO_TASK_REWARD_QUEUE,
} from './jobs/odoo-task-reward.processor.js';
import { RewardsResetScheduler } from './jobs/rewards-reset.scheduler.js';

@Module({
  imports: [
    AuthModule,
    ChatModule,
    NotificationModule,
    TaskModule,
    TypeOrmModule.forFeature([
      User,
      UserSession,
      Role,
      UserRole,
      LeaveRequest,
      UserPointWallet,
      PointRule,
      PointTransaction,
      RewardItem,
      RewardRedemption,
      PointPeriodHistory,
      OdooTaskTagConfig,
      JobTitleMultiplier,
      OdooTaskRewardLog,
      InternalRole,
      JobTitleMapping,
    ]),
    BullModule.registerQueue({ name: REWARDS_RESET_QUEUE }),
    BullModule.registerQueue({ name: ODOO_TASK_REWARD_QUEUE }),
  ],
  controllers: [RewardsController, RewardsAdminController],
  providers: [
    RewardsService,
    RewardsResetProcessor,
    RewardsResetScheduler,
    OdooTaskRewardProcessor,
  ],
  exports: [RewardsService],
})
export class RewardsModule {}
