import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../auth/entities/user.entity.js';
import { ConversationMember } from '../chat/entities/conversation-member.entity.js';
import { Conversation } from '../chat/entities/conversation.entity.js';
import { Message } from '../chat/entities/message.entity.js';
import { ChatModule } from '../chat/chat.module.js';
import { BotController } from './bot.controller.js';
import { BotsAdminController } from './bots-admin.controller.js';
import { BotService } from './bot.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, ConversationMember, Conversation, Message]),
    ChatModule,
  ],
  controllers: [BotController, BotsAdminController],
  providers: [BotService],
})
export class BotModule {}
