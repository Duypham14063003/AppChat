import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';
import { BullModule } from '@nestjs/bullmq';
import {
  Conversation,
  ConversationMember,
  Message,
  MessageReaction,
  PinnedMessage,
  MessageBookmark,
  MessageReminder,
} from './entities/index.js';
import { User } from '../auth/entities/user.entity.js';
import { AuthModule } from '../auth/auth.module.js';
import { NotificationModule } from '../notification/notification.module.js';
import { ConnectionManager } from './services/connection-manager.service.js';
import { RedisPubSubService } from './services/redis-pubsub.service.js';
import { ChatService } from './services/chat.service.js';
import { NotificationJobService } from './services/notification-job.service.js';
import { ChatGateway } from './chat.gateway.js';
import { ConversationController } from './conversation.controller.js';
import { SearchController } from './search.controller.js';
import { UploadController } from './upload.controller.js';
import { LinkPreviewController } from './link-preview.controller.js';
import { UserBookmarkController } from './user-bookmark.controller.js';
import { LinkPreviewService } from './services/link-preview.service.js';
import { MessageReminderProcessor } from './services/message-reminder.processor.js';
import { CHAT_PUSH_QUEUE, CHAT_REMINDER_QUEUE } from './chat.constants.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Conversation,
      ConversationMember,
      Message,
      MessageReaction,
      PinnedMessage,
      MessageBookmark,
      MessageReminder,
      User,
    ]),
    ConfigModule,
    AuthModule,
    NotificationModule,
    BullModule.registerQueue(
      { name: CHAT_PUSH_QUEUE },
      { name: CHAT_REMINDER_QUEUE },
    ),
  ],
  controllers: [
    ConversationController,
    UserBookmarkController,
    SearchController,
    UploadController,
    LinkPreviewController,
  ],
  providers: [
    ConnectionManager,
    RedisPubSubService,
    ChatService,
    NotificationJobService,
    MessageReminderProcessor,
    ChatGateway,
    LinkPreviewService,
  ],
  exports: [ChatService, ConnectionManager],
})
export class ChatModule {}
