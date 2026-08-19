import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { User } from '../auth/entities/user.entity.js';
import { UserSession } from '../auth/entities/user-session.entity.js';
import { ChatModule } from '../chat/chat.module.js';
import { ConversationMember } from '../chat/entities/conversation-member.entity.js';
import { Message } from '../chat/entities/message.entity.js';
import { NotificationModule } from '../notification/notification.module.js';
import {
  Poc,
  PocHistory,
  PocNotificationEvent,
  PocWeeklyReport,
} from './entities/index.js';
import { PocProcessor } from './jobs/poc.processor.js';
import { PocScheduler } from './jobs/poc.scheduler.js';
import { POC_QUEUE } from './poc.constants.js';
import { PocController } from './poc.controller.js';
import { PocCalendarService } from './services/poc-calendar.service.js';
import { PocCapacityService } from './services/poc-capacity.service.js';
import { PocChatService } from './services/poc-chat.service.js';
import { PocJobService } from './services/poc-job.service.js';
import { PocPushService } from './services/poc-push.service.js';
import { PocSystemBotService } from './services/poc-system-bot.service.js';
import { PocService } from './services/poc.service.js';
import { PocWeeklyReportService } from './services/poc-weekly-report.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Poc,
      PocHistory,
      PocNotificationEvent,
      PocWeeklyReport,
      User,
      UserSession,
      ConversationMember,
      Message,
    ]),
    BullModule.registerQueue({ name: POC_QUEUE }),
    AuthModule,
    ChatModule,
    NotificationModule,
  ],
  controllers: [PocController],
  providers: [
    PocService,
    PocCalendarService,
    PocCapacityService,
    PocChatService,
    PocPushService,
    PocSystemBotService,
    PocJobService,
    PocWeeklyReportService,
    PocProcessor,
    PocScheduler,
  ],
  exports: [PocService, PocCapacityService, PocWeeklyReportService],
})
export class PocModule {}
