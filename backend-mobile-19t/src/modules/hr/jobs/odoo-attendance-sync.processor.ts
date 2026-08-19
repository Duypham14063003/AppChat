import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Attendance } from '../entities/attendance.entity.js';
import { User } from '../../auth/entities/user.entity.js';
import { OdooService } from '../../auth/services/odoo.service.js';

export const HR_ODOO_SYNC_QUEUE = 'hr-odoo-sync';

@Processor(HR_ODOO_SYNC_QUEUE)
export class OdooAttendanceSyncProcessor extends WorkerHost {
  private readonly logger = new Logger(OdooAttendanceSyncProcessor.name);

  constructor(
    @InjectRepository(Attendance)
    private readonly attendanceRepo: Repository<Attendance>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly odooService: OdooService,
  ) {
    super();
  }

  async process(): Promise<void> {
    const unsynced = await this.attendanceRepo.find({
      where: { odoo_synced: false },
    });

    // Only sync completed records (with checkout)
    const toSync = unsynced.filter((r) => r.checkout_at !== null);

    if (toSync.length === 0) {
      this.logger.debug('No unsynced attendance records');
      return;
    }

    this.logger.log(`Syncing ${toSync.length} attendance records to Odoo`);

    for (const record of toSync) {
      try {
        const user = await this.userRepo.findOne({
          where: { id: record.user_id },
        });
        if (!user?.odoo_uid) {
          this.logger.warn(
            `User ${record.user_id} has no odoo_uid, skipping attendance sync`,
          );
          continue;
        }

        await this.odooService.writeAttendance(
          user.odoo_uid,
          record.checkin_at,
          record.checkout_at,
        );

        record.odoo_synced = true;
        record.odoo_synced_at = new Date();
        await this.attendanceRepo.save(record);

        this.logger.log(`Synced attendance ${record.id} for user ${user.name}`);
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        this.logger.error(`Failed to sync attendance ${record.id}: ${message}`);
        // Skip and retry next cycle
      }
    }
  }
}
