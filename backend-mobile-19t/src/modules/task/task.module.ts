import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';
import { BullModule } from '@nestjs/bullmq';
import { AuthModule } from '../auth/auth.module.js';
import { User } from '../auth/entities/user.entity.js';
import { TaskService } from './services/task.service.js';
import { TaskController } from './task.controller.js';
import {
  TaskSyncProcessor,
  TASK_SYNC_QUEUE,
} from './jobs/task-sync.processor.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([User]),
    ConfigModule,
    AuthModule,
    BullModule.registerQueue({ name: TASK_SYNC_QUEUE }),
  ],
  controllers: [TaskController],
  providers: [TaskService, TaskSyncProcessor],
  exports: [TaskService],
})
export class TaskModule {}
