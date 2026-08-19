import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Call } from './entities/call.entity.js';
import { CallService } from './services/call.service.js';
import { CallController } from './call.controller.js';
import { ChatModule } from '../chat/chat.module.js';
import { AuthModule } from '../auth/auth.module.js';
import { NotificationModule } from '../notification/notification.module.js';
import { UserSession } from '../auth/entities/user-session.entity.js';
import { User } from '../auth/entities/user.entity.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([Call, UserSession, User]),
    forwardRef(() => ChatModule),
    AuthModule,
    NotificationModule,
  ],
  providers: [CallService],
  controllers: [CallController],
  exports: [CallService],
})
export class CallModule {}
