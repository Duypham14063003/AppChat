import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';
import { BullModule } from '@nestjs/bullmq';
import { CallModule } from '../call/call.module.js';
import {
  Conversation,
  ConversationEncryptionKey,
  ConversationMember,
  MessageBlindIndex,
  Message,
  MessageBookmark,
  MessageReminder,
  MessageReaction,
  PinnedMessage,
} from './entities/index.js';
import { UserSession } from '../auth/entities/user-session.entity.js';
import { User } from '../auth/entities/user.entity.js';
import { AuthModule } from '../auth/auth.module.js';
import { NotificationModule } from '../notification/notification.module.js';
import { ConnectionManager } from './services/connection-manager.service.js';
import { RedisPubSubService } from './services/redis-pubsub.service.js';
import { ChatService } from './services/chat.service.js';
import { NotificationJobService } from './services/notification-job.service.js';
import { ReminderJobService } from './services/reminder-job.service.js';
import { MessagePartitionService } from './services/message-partition.service.js';
import { ChatGateway } from './chat.gateway.js';
import { BookmarkController } from './bookmark.controller.js';
import { ReminderController } from './reminder.controller.js';
import { ConversationController } from './conversation.controller.js';
import { MessageController } from './message.controller.js';
import { SearchController } from './search.controller.js';
import { UploadController } from './upload.controller.js';
import { LinkPreviewController } from './link-preview.controller.js';
import { LinkPreviewService } from './services/link-preview.service.js';
import { CHAT_PUSH_QUEUE, CHAT_REMINDER_QUEUE } from './chat.constants.js';
import { ChatReminderProcessor } from './jobs/chat-reminder.processor.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Conversation,
      ConversationEncryptionKey,
      ConversationMember,
      MessageBlindIndex,
      Message,
      MessageBookmark,
      MessageReminder,
      MessageReaction,
      PinnedMessage,
      UserSession,
      User,
    ]),
    ConfigModule,
    AuthModule,
    NotificationModule,
    forwardRef(() => CallModule),
    BullModule.registerQueue({ name: CHAT_PUSH_QUEUE }),
    BullModule.registerQueue({ name: CHAT_REMINDER_QUEUE }),
  ],
  controllers: [
    BookmarkController,
    ReminderController,
    ConversationController,
    MessageController,
    SearchController,
    UploadController,
    LinkPreviewController,
  ],
  providers: [
    ConnectionManager,
    RedisPubSubService,
    ChatService,
    NotificationJobService,
    ReminderJobService,
    MessagePartitionService,
    ChatGateway,
    ChatReminderProcessor,
    LinkPreviewService,
  ],
  exports: [ChatService, ConnectionManager, RedisPubSubService],
})
export class ChatModule {}
