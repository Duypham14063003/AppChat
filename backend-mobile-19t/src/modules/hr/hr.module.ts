import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bullmq';
import {
  Attendance,
  CompanyWfhYearlyConfig,
  LeaveRequest,
  LeaveRequestDay,
  MonthlyLeaveBalance,
  YearlyLeaveBalance,
  YearlyWfhBalance,
  PayrollConfig,
  DailyReport,
  DailyReportItem,
  EmployeeProfile,
  EmployeeContract,
  ContractReminderEvent,
} from './entities/index.js';
import { User } from '../auth/entities/user.entity.js';
import { UserRole } from '../auth/entities/user-role.entity.js';
import { Role } from '../auth/entities/role.entity.js';
import { UserSession } from '../auth/entities/user-session.entity.js';
import { AuthModule } from '../auth/auth.module.js';
import { NotificationModule } from '../notification/notification.module.js';
import { RewardsModule } from '../rewards/rewards.module.js';
import { ChatModule } from '../chat/chat.module.js';
import { AttendanceService } from './services/attendance.service.js';
import { LeaveService } from './services/leave.service.js';
import { PayrollConfigService } from './services/payroll-config.service.js';
import { DailyReportService } from './services/daily-report.service.js';
import { DailyReportStatisticsService } from './services/daily-report-statistics.service.js';
import { PayrollExportService } from './services/payroll-export.service.js';
import { AttendanceController } from './attendance.controller.js';
import { LeaveController } from './leave.controller.js';
import { PayrollConfigController } from './payroll-config.controller.js';
import { PayrollExportController } from './payroll-export.controller.js';
import { DailyReportController } from './daily-report.controller.js';
import { PublicDailyReportController } from './public-daily-report.controller.js';
import { EmployeeController } from './employee.controller.js';
import { EmployeeService } from './services/employee.service.js';
import { ContractReminderService } from './services/contract-reminder.service.js';
import {
  AttendanceReminderProcessor,
  HR_REMINDERS_QUEUE,
} from './jobs/attendance-reminder.processor.js';
import { AttendanceReminderScheduler } from './jobs/attendance-reminder.scheduler.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Attendance,
      CompanyWfhYearlyConfig,
      LeaveRequest,
      LeaveRequestDay,
      MonthlyLeaveBalance,
      YearlyLeaveBalance,
      YearlyWfhBalance,
      PayrollConfig,
      DailyReport,
      DailyReportItem,
      EmployeeProfile,
      EmployeeContract,
      ContractReminderEvent,
      User,
      UserRole,
      Role,
      UserSession,
    ]),
    BullModule.registerQueue({ name: HR_REMINDERS_QUEUE }),
    AuthModule,
    NotificationModule,
    RewardsModule,
    ChatModule,
  ],
  controllers: [
    AttendanceController,
    LeaveController,
    PayrollConfigController,
    PayrollExportController,
    DailyReportController,
    PublicDailyReportController,
    EmployeeController,
  ],
  providers: [
    AttendanceService,
    LeaveService,
    PayrollConfigService,
    PayrollExportService,
    DailyReportService,
    EmployeeService,
    ContractReminderService,
    DailyReportStatisticsService,
    AttendanceReminderProcessor,
    AttendanceReminderScheduler,
  ],
})
export class HrModule {}
