import { ContractReminderService } from './contract-reminder.service';

describe('ContractReminderService', () => {
  const contractQb = { leftJoinAndSelect: jest.fn().mockReturnThis(), where: jest.fn().mockReturnThis(), andWhere: jest.fn().mockReturnThis(), getMany: jest.fn() };
  const insertQb = { insert: jest.fn().mockReturnThis(), values: jest.fn().mockReturnThis(), orIgnore: jest.fn().mockReturnThis(), execute: jest.fn() };
  const roleQb = { innerJoin: jest.fn().mockReturnThis(), select: jest.fn().mockReturnThis(), where: jest.fn().mockReturnThis(), andWhere: jest.fn().mockReturnThis(), getRawMany: jest.fn() };
  const sessionQb = { where: jest.fn().mockReturnThis(), andWhere: jest.fn().mockReturnThis(), getMany: jest.fn() };
  const contractRepo = { createQueryBuilder: jest.fn().mockReturnValue(contractQb) };
  const eventRepo = { createQueryBuilder: jest.fn().mockReturnValue(insertQb), update: jest.fn().mockResolvedValue({}) };
  const userRoleRepo = { createQueryBuilder: jest.fn().mockReturnValue(roleQb) };
  const sessionRepo = { createQueryBuilder: jest.fn().mockReturnValue(sessionQb) };
  const firebase = { isEnabled: jest.fn().mockReturnValue(true), sendPush: jest.fn().mockResolvedValue(true) };
  const service = new ContractReminderService(contractRepo as any, eventRepo as any, userRoleRepo as any, sessionRepo as any, firebase as any);

  beforeEach(() => {
    jest.clearAllMocks();
    roleQb.getRawMany.mockResolvedValue([{ user_id: 'admin-1' }]);
    sessionQb.getMany.mockResolvedValue([{ user_id: 'admin-1', fcm_token: 'token' }]);
    insertQb.execute.mockResolvedValue({ identifiers: [{ id: 'event-1' }] });
  });

  it.each([
    ['probation', '2026-07-27', 7, 'propose_official_contract', 'Đề xuất ký hợp đồng chính thức'],
    ['internship', '2026-07-27', 7, 'propose_official_contract', 'Đề xuất ký hợp đồng chính thức'],
    ['official', '2026-07-30', 10, 'propose_contract_renewal', 'Đề xuất gia hạn hợp đồng'],
  ])('sends the configured %s action reminder', async (type, endDate, threshold, action, title) => {
    contractQb.getMany.mockResolvedValue([{ id: 'c1', user_id: 'u1', type, status: 'active', end_date: endDate, user: { name: 'Alice' } }]);
    await service.process('2026-07-20');
    expect(firebase.sendPush).toHaveBeenCalledWith(
      'token',
      title,
      expect.stringContaining(`${threshold} ngày`),
      {
        type: 'hr_contract_action_reminder',
        action,
        contract_id: 'c1',
        user_id: 'u1',
      },
    );
  });

  it('ignores temporary contracts', async () => {
    contractQb.getMany.mockResolvedValue([{ id: 'c1', user_id: 'u1', type: 'temporary', status: 'active', end_date: '2026-07-27' }]);
    await service.process('2026-07-20');
    expect(contractQb.andWhere).toHaveBeenCalledWith("contract.type IN ('internship','probation','official')");
    expect(insertQb.execute).not.toHaveBeenCalled();
    expect(firebase.sendPush).not.toHaveBeenCalled();
  });

  it('filters recipients to active admin and manager role names only', async () => {
    contractQb.getMany.mockResolvedValue([]);
    await service.process('2026-07-20');
    expect(roleQb.where).toHaveBeenCalledWith('user.is_active = true');
    expect(roleQb.andWhere).toHaveBeenCalledWith('LOWER(role.name) IN (:...roles)', {
      roles: ['admin', 'manager'],
    });
  });

  it('does not deliver a duplicate reminder event', async () => {
    contractQb.getMany.mockResolvedValue([{ id: 'c1', user_id: 'u1', type: 'official', status: 'active', end_date: '2026-07-30' }]);
    insertQb.execute.mockResolvedValue({ identifiers: [] });
    await service.process('2026-07-20');
    expect(firebase.sendPush).not.toHaveBeenCalled();
  });
});
