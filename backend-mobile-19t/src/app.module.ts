import { Module } from '@nestjs/common';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';
import { AppConfigModule } from './config/config.module';
import { AuthModule } from './modules/auth/auth.module';
import { ChatModule } from './modules/chat/chat.module';
import { CallModule } from './modules/call/call.module';
import { HrModule } from './modules/hr/hr.module';
import { TaskModule } from './modules/task/task.module';
import { ProfileModule } from './modules/profile/profile.module';
import { AiModule } from './modules/ai/ai.module';
import { NotificationModule } from './modules/notification/notification.module';
import { ReminderModule } from './modules/reminder/reminder.module';
import { RewardsModule } from './modules/rewards/rewards.module';
import { BotModule } from './modules/bot/bot.module';
import { PocModule } from './modules/poc/poc.module';
import { AppController } from './app.controller';

@Module({
  imports: [
    AppConfigModule,
    ...['avatars', 'chat', 'rewards', 'hr/contracts'].map((directory) =>
      ServeStaticModule.forRoot({
        rootPath: join(process.cwd(), 'uploads', ...directory.split('/')),
        serveRoot: `/uploads/${directory}`,
        serveStaticOptions: { index: false },
      }),
    ),
    AuthModule,
    ChatModule,
    CallModule,
    HrModule,
    TaskModule,
    ProfileModule,
    AiModule,
    NotificationModule,
    ReminderModule,
    RewardsModule,
    BotModule,
    PocModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
