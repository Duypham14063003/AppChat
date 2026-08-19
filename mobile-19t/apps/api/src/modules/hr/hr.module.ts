import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bullmq';
import { Attendance, LeaveRequest, PayrollConfig } from './entities/index.js';
import { User } from '../auth/entities/user.entity.js';
import { UserRole } from '../auth/entities/user-role.entity.js';
import { Role } from '../auth/entities/role.entity.js';
import { UserSession } from '../auth/entities/user-session.entity.js';
import { AuthModule } from '../auth/auth.module.js';
import { NotificationModule } from '../notification/notification.module.js';
import { AttendanceService } from './services/attendance.service.js';
import { LeaveService } from './services/leave.service.js';
import { PayrollConfigService } from './services/payroll-config.service.js';
import { AttendanceController } from './attendance.controller.js';
import { LeaveController } from './leave.controller.js';
import { PayrollConfigController } from './payroll-config.controller.js';
import {
  OdooAttendanceSyncProcessor,
  HR_ODOO_SYNC_QUEUE,
} from './jobs/odoo-attendance-sync.processor.js';
import {
  AttendanceReminderProcessor,
  HR_REMINDERS_QUEUE,
} from './jobs/attendance-reminder.processor.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Attendance,
      LeaveRequest,
      PayrollConfig,
      User,
      UserRole,
      Role,
      UserSession,
    ]),
    BullModule.registerQueue({ name: HR_ODOO_SYNC_QUEUE }),
    BullModule.registerQueue({ name: HR_REMINDERS_QUEUE }),
    AuthModule,
    NotificationModule,
  ],
  controllers: [AttendanceController, LeaveController, PayrollConfigController],
  providers: [
    AttendanceService,
    LeaveService,
    PayrollConfigService,
    OdooAttendanceSyncProcessor,
    AttendanceReminderProcessor,
  ],
})
export class HrModule {}
