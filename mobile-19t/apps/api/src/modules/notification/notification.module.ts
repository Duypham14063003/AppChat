import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bullmq';
import { UserSession } from '../auth/entities/user-session.entity.js';
import { User } from '../auth/entities/user.entity.js';
import { ConversationMember } from '../chat/entities/conversation-member.entity.js';
import { Message } from '../chat/entities/message.entity.js';
import { CHAT_PUSH_QUEUE } from '../chat/chat.constants.js';
import { FirebaseService } from './services/firebase.service.js';
import { PushNotificationProcessor } from './services/push-notification.processor.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([UserSession, User, ConversationMember, Message]),
    BullModule.registerQueue({ name: CHAT_PUSH_QUEUE }),
  ],
  providers: [FirebaseService, PushNotificationProcessor],
  exports: [FirebaseService],
})
export class NotificationModule {}
