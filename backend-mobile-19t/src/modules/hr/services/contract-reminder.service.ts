import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserRole } from '../../auth/entities/user-role.entity.js';
import { UserSession } from '../../auth/entities/user-session.entity.js';
import { FirebaseService } from '../../notification/services/firebase.service.js';
import { ContractReminderEvent, EmployeeContract } from '../entities/index.js';

type ContractReminderAction =
  | 'propose_official_contract'
  | 'propose_contract_renewal';

type ContractReminderRule = {
  action: ContractReminderAction;
  threshold: number;
};

@Injectable()
export class ContractReminderService {
  private readonly logger = new Logger(ContractReminderService.name);

  constructor(
    @InjectRepository(EmployeeContract) private readonly contractRepo: Repository<EmployeeContract>,
    @InjectRepository(ContractReminderEvent) private readonly eventRepo: Repository<ContractReminderEvent>,
    @InjectRepository(UserRole) private readonly userRoleRepo: Repository<UserRole>,
    @InjectRepository(UserSession) private readonly sessionRepo: Repository<UserSession>,
    private readonly firebase: FirebaseService,
  ) {}

  async process(date = this.localDate()): Promise<void> {
    const contracts = await this.contractRepo.createQueryBuilder('contract')
      .leftJoinAndSelect('contract.user', 'user')
      .where("contract.status = 'active'")
      .andWhere('contract.end_date IS NOT NULL')
      .andWhere("contract.type IN ('internship','probation','official')")
      .getMany();
    const recipientIds = await this.loadRecipientIds();

    for (const contract of contracts) {
      const rule = this.ruleForContract(contract);
      if (!rule) continue;
      if (this.daysBetween(date, contract.end_date!) !== rule.threshold) continue;
      const insert = await this.eventRepo.createQueryBuilder().insert().values({
        contract_id: contract.id,
        threshold_days: rule.threshold,
        reminder_date: date,
        status: 'pending',
      }).orIgnore().execute();
      if (!insert.identifiers.length) continue;

      try {
        await this.notifyRecipients(recipientIds, contract, rule);
        await this.eventRepo.update(
          { contract_id: contract.id, threshold_days: rule.threshold, reminder_date: date },
          { status: 'delivered', delivered_at: new Date() },
        );
      } catch (error) {
        await this.eventRepo.update(
          { contract_id: contract.id, threshold_days: rule.threshold, reminder_date: date },
          { status: 'failed' },
        );
        throw error;
      }
    }
  }

  private async loadRecipientIds(): Promise<string[]> {
    const rows = await this.userRoleRepo.createQueryBuilder('userRole')
      .innerJoin('userRole.role', 'role')
      .innerJoin('userRole.user', 'user')
      .select('DISTINCT userRole.user_id', 'user_id')
      .where('user.is_active = true')
      .andWhere('LOWER(role.name) IN (:...roles)', {
        roles: ['admin', 'manager'],
      })
      .getRawMany<{ user_id: string }>();
    return rows.map((row) => row.user_id);
  }

  private async notifyRecipients(userIds: string[], contract: EmployeeContract, rule: ContractReminderRule) {
    if (!this.firebase.isEnabled() || !userIds.length) return;
    const sessions = await this.sessionRepo.createQueryBuilder('session')
      .where('session.user_id IN (:...userIds)', { userIds })
      .andWhere('session.fcm_token IS NOT NULL')
      .getMany();
    const employeeName = contract.user?.name ?? 'Nhân sự';
    const isOfficialProposal = rule.action === 'propose_official_contract';
    const title = isOfficialProposal
      ? 'Đề xuất ký hợp đồng chính thức'
      : 'Đề xuất gia hạn hợp đồng';
    const body = isOfficialProposal
      ? `${employeeName}: hợp đồng ${contract.type} kết thúc sau ${rule.threshold} ngày, cần đề xuất ký hợp đồng chính thức`
      : `${employeeName}: hợp đồng chính thức hết hạn sau ${rule.threshold} ngày, cần đề xuất gia hạn`;
    for (const session of sessions) {
      if (!session.fcm_token) continue;
      await this.firebase.sendPush(
        session.fcm_token,
        title,
        body,
        {
          type: 'hr_contract_action_reminder',
          action: rule.action,
          contract_id: contract.id,
          user_id: contract.user_id,
        },
      );
    }
    this.logger.log(`Contract expiry reminder delivered: contract=${contract.id}, recipients=${userIds.length}`);
  }

  private ruleForContract(contract: EmployeeContract): ContractReminderRule | null {
    if (contract.type === 'internship' || contract.type === 'probation') {
      return { action: 'propose_official_contract', threshold: 7 };
    }
    if (contract.type === 'official') {
      return { action: 'propose_contract_renewal', threshold: 10 };
    }
    return null;
  }

  private localDate() { return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' }).format(new Date()); }
  private daysBetween(from: string, to: string) { return Math.ceil((new Date(`${to}T00:00:00Z`).getTime() - new Date(`${from}T00:00:00Z`).getTime()) / 86400000); }
}
