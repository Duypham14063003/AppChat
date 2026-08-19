import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource, In } from 'typeorm';
import { UserSession } from '../auth/entities/user-session.entity';
import { User } from '../auth/entities/user.entity';
import { ChatService } from '../chat/services/chat.service';
import { RedisPubSubService } from '../chat/services/redis-pubsub.service';
import { FirebaseService } from '../notification/services/firebase.service';
import { RewardsService } from './rewards.service';
import {
  InternalRole,
  JobTitleMapping,
  JobTitleMultiplier,
  OdooTaskRewardLog,
  OdooTaskTagConfig,
  PointRule,
  PointPeriodHistory,
  PointTransaction,
  RewardItem,
  RewardRedemption,
  UserPointWallet,
} from './entities';
import { Role } from '../auth/entities/role.entity';
import { UserRole } from '../auth/entities/user-role.entity';
import { LeaveRequest } from '../hr/entities/leave-request.entity';
import { OdooService } from '../auth/services/odoo.service';
import { TaskService } from '../task/services/task.service';
import { AuthService } from '../auth/services/auth.service';

function createRepoMock() {
  return {
    findOne: jest.fn(),
    find: jest.fn(),
    findOneOrFail: jest.fn(),
    query: jest.fn(),
    create: jest.fn((value: Record<string, unknown>) => ({ ...value })),
    save: jest.fn(async (value: unknown) => value),
    update: jest.fn(),
    delete: jest.fn(),
    createQueryBuilder: jest.fn(),
  };
}

describe('RewardsService', () => {
  let service: RewardsService;
  const userRepo = createRepoMock();
  const sessionRepo = createRepoMock();
  const roleRepo = createRepoMock();
  const userRoleRepo = createRepoMock();
  const leaveRequestRepo = createRepoMock();
  const walletRepo = createRepoMock();
  const pointRuleRepo = createRepoMock();
  const pointTransactionRepo = createRepoMock();
  const pointPeriodHistoryRepo = createRepoMock();
  const rewardItemRepo = createRepoMock();
  const rewardRedemptionRepo = createRepoMock();
  const taskTagConfigRepo = createRepoMock();
  const jobTitleMultiplierRepo = createRepoMock();
  const taskRewardLogRepo = createRepoMock();
  const internalRoleRepo = createRepoMock();
  const jobTitleMappingRepo = createRepoMock();
  const odooService = {
    fetchTodayAttendance: jest.fn(),
    findEmployeeIdByUserUidOrEmployeeId: jest.fn(),
    fetchProjectTags: jest.fn(),
  };
  const firebaseService = {
    isEnabled: jest.fn(),
    sendPush: jest.fn(),
  };
  const chatService = {
    sendMessage: jest.fn(),
  };
  const redisPubSubService = {
    publishUserEvent: jest.fn(),
    publishGlobalRewardUpdate: jest.fn(),
    getCache: jest.fn(),
    setCache: jest.fn(),
  };
  const taskService = {};
  const authService = {};

  let managerRepos: Map<unknown, ReturnType<typeof createRepoMock>>;
  let dataSource: {
    transaction: jest.Mock;
    getRepository: jest.Mock;
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    managerRepos = new Map();
    const conversationsRepo = createRepoMock();
    const conversationMembersRepo = createRepoMock();
    conversationsRepo.findOne.mockResolvedValue({
      id: '35353995-517b-4fcb-b4d7-e0f23c5f4042',
    });
    conversationMembersRepo.findOne.mockResolvedValue({
      conv_id: '35353995-517b-4fcb-b4d7-e0f23c5f4042',
      user_id: '00000000-0000-0000-0000-000000000001',
    });
    dataSource = {
      transaction: jest.fn(async (callback) =>
        callback({
          getRepository: (entity: unknown) => managerRepos.get(entity),
        }),
      ),
      getRepository: jest.fn((entity: string) => {
        if (entity === 'conversations') {
          return conversationsRepo;
        }
        if (entity === 'conversation_members') {
          return conversationMembersRepo;
        }
        return createRepoMock();
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RewardsService,
        { provide: getRepositoryToken(User), useValue: userRepo },
        { provide: getRepositoryToken(UserSession), useValue: sessionRepo },
        { provide: getRepositoryToken(Role), useValue: roleRepo },
        { provide: getRepositoryToken(UserRole), useValue: userRoleRepo },
        {
          provide: getRepositoryToken(LeaveRequest),
          useValue: leaveRequestRepo,
        },
        { provide: getRepositoryToken(UserPointWallet), useValue: walletRepo },
        { provide: getRepositoryToken(PointRule), useValue: pointRuleRepo },
        {
          provide: getRepositoryToken(PointTransaction),
          useValue: pointTransactionRepo,
        },
        {
          provide: getRepositoryToken(PointPeriodHistory),
          useValue: pointPeriodHistoryRepo,
        },
        { provide: getRepositoryToken(RewardItem), useValue: rewardItemRepo },
        {
          provide: getRepositoryToken(RewardRedemption),
          useValue: rewardRedemptionRepo,
        },
        {
          provide: getRepositoryToken(OdooTaskTagConfig),
          useValue: taskTagConfigRepo,
        },
        {
          provide: getRepositoryToken(JobTitleMultiplier),
          useValue: jobTitleMultiplierRepo,
        },
        {
          provide: getRepositoryToken(OdooTaskRewardLog),
          useValue: taskRewardLogRepo,
        },
        {
          provide: getRepositoryToken(InternalRole),
          useValue: internalRoleRepo,
        },
        {
          provide: getRepositoryToken(JobTitleMapping),
          useValue: jobTitleMappingRepo,
        },
        { provide: DataSource, useValue: dataSource },
        { provide: FirebaseService, useValue: firebaseService },
        { provide: OdooService, useValue: odooService },
        { provide: ChatService, useValue: chatService },
        { provide: RedisPubSubService, useValue: redisPubSubService },
        { provide: TaskService, useValue: taskService },
        { provide: AuthService, useValue: authService },
      ],
    }).compile();

    service = module.get(RewardsService);
    firebaseService.isEnabled.mockReturnValue(true);
    firebaseService.sendPush.mockResolvedValue(true);
    chatService.sendMessage.mockResolvedValue({ id: 'message-1' });
    redisPubSubService.publishUserEvent.mockResolvedValue(undefined);
    redisPubSubService.publishGlobalRewardUpdate.mockResolvedValue(undefined);
    redisPubSubService.getCache.mockResolvedValue(null);
    redisPubSubService.setCache.mockResolvedValue(undefined);
    sessionRepo.find.mockResolvedValue([
      { id: 'session-1', fcm_token: 'token-1' },
    ]);
  });

  it('adjusts points and creates wallet history atomically', async () => {
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockImplementation(async ({ where }) => {
      if (where?.id === 'admin-1') {
        return { id: 'admin-1', is_active: true };
      }
      if (where?.id === 'user-1') {
        return {
          id: 'user-1',
          is_active: true,
          name: 'Nguyen Van A',
        };
      }
      if (where?.id === '00000000-0000-0000-0000-000000000001') {
        return {
          id: '00000000-0000-0000-0000-000000000001',
          is_active: true,
          name: 'Daily Report Bot',
        };
      }
      return null;
    });
    managerWalletRepo.findOne.mockResolvedValue(null);
    managerWalletRepo.save
      .mockResolvedValueOnce({
        user_id: 'user-1',
        balance: 0,
        lifetime_earned: 0,
        lifetime_spent: 0,
      })
      .mockResolvedValueOnce({
        user_id: 'user-1',
        balance: 20,
        lifetime_earned: 20,
        lifetime_spent: 0,
      });
    managerTxRepo.save.mockResolvedValue({
      id: 'tx-1',
      user_id: 'user-1',
      points: 20,
      balance_after: 20,
    });

    const result = await service.adjustPoints('admin-1', {
      user_id: 'user-1',
      points: 20,
      reason: 'Excellent work',
    });

    expect(result.wallet.balance).toBe(20);
    expect(managerTxRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: 'user-1',
        created_by: 'admin-1',
        points: 20,
      }),
    );
    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'token-1',
      'Excellent work',
      '+20 Điểm. Số dư hiện tại: 20 tim.',
      expect.objectContaining({
        type: 'reward_points_changed',
        source_type: 'admin_manual',
      }),
    );
    expect(redisPubSubService.publishUserEvent).toHaveBeenCalledWith(
      'user-1',
      expect.objectContaining({
        _event: 'reward_points_changed',
        transaction_id: 'tx-1',
        source_type: 'admin_manual',
        transaction_type: 'adjust',
        points: 20,
        balance: 20,
      }),
    );
  });

  it('tracks lifetime spent for negative adjust transactions only', async () => {
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockImplementation(async ({ where }) => {
      if (where?.id === 'admin-1') {
        return { id: 'admin-1', is_active: true };
      }
      if (where?.id === 'user-1') {
        return {
          id: 'user-1',
          is_active: true,
          name: 'Nguyen Van A',
        };
      }
      return null;
    });
    managerWalletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 50,
      lifetime_earned: 120,
      lifetime_spent: 10,
    });
    managerWalletRepo.save.mockResolvedValue({
      user_id: 'user-1',
      balance: 35,
      lifetime_earned: 120,
      lifetime_spent: 25,
    });
    managerTxRepo.save.mockResolvedValue({
      id: 'tx-adjust-negative',
      user_id: 'user-1',
      points: -15,
      balance_after: 35,
      type: 'adjust',
      source_type: 'admin_manual',
    });

    const result = await service.adjustPoints('admin-1', {
      user_id: 'user-1',
      points: -15,
      reason: 'Penalty',
    });

    expect(result.wallet).toEqual(
      expect.objectContaining({
        balance: 35,
        lifetime_earned: 120,
        lifetime_spent: 25,
      }),
    );
  });

  it('grants points to a user with a positive amount', async () => {
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockResolvedValue({ id: 'admin-1', is_active: true });
    userRepo.findOne.mockResolvedValueOnce({ id: 'admin-1', is_active: true });
    userRepo.findOne.mockResolvedValueOnce({ id: 'user-1', is_active: true });
    roleRepo.findOne.mockResolvedValue(null);
    walletRepo.findOne.mockResolvedValue({
      user_id: 'admin-1',
      balance: 15,
      lifetime_earned: 15,
      lifetime_spent: 0,
    });
    managerWalletRepo.findOne.mockImplementation(async ({ where }) => {
      if (where?.user_id === 'admin-1') {
        return {
          user_id: 'admin-1',
          balance: 15,
          lifetime_earned: 15,
          lifetime_spent: 0,
        };
      }
      if (where?.user_id === 'user-1') {
        return {
          user_id: 'user-1',
          balance: 0,
          lifetime_earned: 0,
          lifetime_spent: 0,
        };
      }
      return null;
    });
    let walletSaveCall = 0;
    managerWalletRepo.save.mockImplementation(async () => {
      walletSaveCall += 1;
      if (walletSaveCall === 1) {
        return {
          user_id: 'admin-1',
          balance: 0,
          lifetime_earned: 15,
          lifetime_spent: 0,
        };
      }
      if (walletSaveCall === 2) {
        return {
          user_id: 'user-1',
          balance: 15,
          lifetime_earned: 15,
          lifetime_spent: 0,
        };
      }
      return {
        user_id: 'user-1',
        balance: 15,
        lifetime_earned: 15,
        lifetime_spent: 0,
      };
    });
    managerTxRepo.save.mockResolvedValue({
      id: 'tx-2',
      user_id: 'user-1',
      points: 15,
      balance_after: 15,
      type: 'earn',
      source_type: 'admin_grant',
    });

    const result = await service.grantPoints('admin-1', {
      user_id: 'user-1',
      points: 15,
    });

    expect(result.wallet.balance).toBe(15);
    expect(result.recipient_total_points).toBe(15);
    expect(managerWalletRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: 'admin-1',
        balance: 0,
        lifetime_earned: 15,
        lifetime_spent: 0,
      }),
    );
    expect(managerTxRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: 'user-1',
        created_by: 'admin-1',
        points: 15,
        type: 'earn',
        source_type: 'admin_grant',
        note: 'Admin grant points',
      }),
    );
    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'token-1',
      'Bạn vừa được cộng điểm',
      '+15 Điểm. Số dư hiện tại: 15 tim.',
      expect.objectContaining({
        type: 'reward_points_changed',
        source_type: 'admin_grant',
      }),
    );
    expect(chatService.sendMessage).toHaveBeenCalledWith(
      '00000000-0000-0000-0000-000000000001',
      expect.objectContaining({
        conv_id: '35353995-517b-4fcb-b4d7-e0f23c5f4042',
        type: 'text',
        content: expect.stringContaining('Nhân sự: user-1'),
      }),
    );
    expect(chatService.sendMessage).toHaveBeenCalledWith(
      '00000000-0000-0000-0000-000000000001',
      expect.objectContaining({
        content: expect.stringContaining('Số tim: +15'),
      }),
    );
    expect(chatService.sendMessage).toHaveBeenCalledWith(
      '00000000-0000-0000-0000-000000000001',
      expect.objectContaining({
        content: expect.stringContaining('Tổng điểm hiện tại: 15'),
      }),
    );
    expect(chatService.sendMessage).toHaveBeenCalledWith(
      '00000000-0000-0000-0000-000000000001',
      expect.objectContaining({
        content: expect.stringContaining('Lý do: Admin grant points'),
      }),
    );
  });

  it('deducts a negative admin grant from recipient lifetime earned', async () => {
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      is_active: true,
      name: 'Nguyen Van A',
    });
    roleRepo.findOne.mockResolvedValue({ id: 'role-admin', name: 'admin' });
    userRoleRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      role_id: 'role-employee',
    });
    walletRepo.findOne.mockResolvedValue({
      user_id: 'admin-1',
      balance: 0,
      lifetime_earned: 0,
      lifetime_spent: 0,
    });
    managerWalletRepo.findOne
      .mockResolvedValueOnce({
        user_id: 'admin-1',
        balance: 0,
        lifetime_earned: 0,
        lifetime_spent: 0,
      })
      .mockResolvedValueOnce({
        user_id: 'user-1',
        balance: 50,
        lifetime_earned: 120,
        lifetime_spent: 10,
      });

    const result = await service.grantPoints('admin-1', {
      user_id: 'user-1',
      points: -10,
      note: 'Penalty',
    });

    expect(result.wallet).toEqual(
      expect.objectContaining({
        balance: 40,
        lifetime_earned: 110,
        lifetime_spent: 10,
      }),
    );
    expect(managerWalletRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: 'user-1',
        balance: 40,
        lifetime_earned: 110,
        lifetime_spent: 10,
      }),
    );
  });

  it('resets wallet balance and point-related records for all non-admin users', async () => {
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    const managerRedemptionRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);
    managerRepos.set(RewardRedemption, managerRedemptionRepo);

    userRepo.findOne.mockResolvedValue({ id: 'admin-1', is_active: true });
    roleRepo.findOne.mockResolvedValue({ id: 'role-admin', name: 'admin' });
    userRoleRepo.find.mockResolvedValue([{ user_id: 'admin-1' }]);
    userRepo.find.mockResolvedValue([
      { id: 'admin-1' },
      { id: 'user-1' },
      { id: 'user-2' },
    ]);
    managerWalletRepo.findOne
      .mockResolvedValueOnce({
        user_id: 'user-1',
        balance: 120,
        lifetime_earned: 150,
        lifetime_spent: 30,
      })
      .mockResolvedValueOnce(null);
    managerWalletRepo.save
      .mockResolvedValueOnce({
        user_id: 'user-1',
        balance: 0,
        lifetime_earned: 0,
        lifetime_spent: 0,
      })
      .mockResolvedValueOnce({
        user_id: 'user-2',
        balance: 0,
        lifetime_earned: 0,
        lifetime_spent: 0,
      });
    managerTxRepo.update
      .mockResolvedValueOnce({ affected: 4 })
      .mockResolvedValueOnce({ affected: 1 });
    managerRedemptionRepo.update
      .mockResolvedValueOnce({ affected: 2 })
      .mockResolvedValueOnce({ affected: 0 });

    const result = await service.resetPoints('admin-1');

    expect(managerWalletRepo.save).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({
        user_id: 'user-1',
        balance: 0,
        lifetime_earned: 0,
        lifetime_spent: 0,
      }),
    );
    expect(managerWalletRepo.save).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        user_id: 'user-2',
        balance: 0,
        lifetime_earned: 0,
        lifetime_spent: 0,
      }),
    );
    expect(managerTxRepo.update).toHaveBeenNthCalledWith(
      1,
      { user_id: 'user-1' },
      expect.objectContaining({
        rule_id: null,
        created_by: 'admin-1',
        source_ref_id: null,
        event_key: null,
        points: 0,
        balance_after: 0,
        note: null,
        metadata: null,
      }),
    );
    expect(managerTxRepo.update).toHaveBeenNthCalledWith(
      2,
      { user_id: 'user-2' },
      expect.objectContaining({
        created_by: 'admin-1',
        points: 0,
        balance_after: 0,
      }),
    );
    expect(managerRedemptionRepo.update).toHaveBeenNthCalledWith(
      1,
      { user_id: 'user-1' },
      {
        unit_points_cost: 0,
        total_points_cost: 0,
      },
    );
    expect(managerRedemptionRepo.update).toHaveBeenNthCalledWith(
      2,
      { user_id: 'user-2' },
      {
        unit_points_cost: 0,
        total_points_cost: 0,
      },
    );
    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'token-1',
      'Điểm đã được reset',
      'Số điểm và dữ liệu điểm liên quan của bạn đã được reset về 0.',
      expect.objectContaining({
        type: 'reward_points_reset',
        user_id: 'user-1',
      }),
    );
    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'token-1',
      'Điểm đã được reset',
      'Số điểm và dữ liệu điểm liên quan của bạn đã được reset về 0.',
      expect.objectContaining({
        type: 'reward_points_reset',
        user_id: 'user-2',
      }),
    );
    expect(redisPubSubService.publishUserEvent).toHaveBeenCalledWith(
      'user-1',
      expect.objectContaining({
        _event: 'reward_points_changed',
        source_type: 'reward_points_reset',
        transaction_type: 'reset',
        points: 0,
        balance: 0,
      }),
    );
    expect(redisPubSubService.publishUserEvent).toHaveBeenCalledWith(
      'user-2',
      expect.objectContaining({
        _event: 'reward_points_changed',
        source_type: 'reward_points_reset',
        transaction_type: 'reset',
        points: 0,
        balance: 0,
      }),
    );
    expect(result).toEqual({
      users_reset: 2,
      user_ids: ['user-1', 'user-2'],
      wallets: [
        {
          user_id: 'user-1',
          balance: 0,
          lifetime_earned: 0,
          lifetime_spent: 0,
        },
        {
          user_id: 'user-2',
          balance: 0,
          lifetime_earned: 0,
          lifetime_spent: 0,
        },
      ],
      point_transactions_affected: 5,
      reward_redemptions_affected: 2,
    });
  });

  it('returns the latest wallet snapshot for client resync', async () => {
    userRepo.findOne.mockResolvedValue({ id: 'user-1', is_active: true });
    roleRepo.findOne.mockResolvedValue(null);
    walletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 45,
      lifetime_earned: 60,
      lifetime_spent: 15,
      updated_at: new Date('2026-05-12T03:00:00.000Z'),
    });
    pointTransactionRepo.find.mockResolvedValue([
      {
        id: 'tx-latest',
        user_id: 'user-1',
        points: -5,
        balance_after: 45,
        note: 'Redeemed Bottle',
        created_at: new Date('2026-05-12T02:59:00.000Z'),
      },
    ]);

    const result = await service.getMyWallet('user-1');

    expect(result.balance).toBe(45);
    expect(result.recent_transactions).toHaveLength(1);
    expect(pointTransactionRepo.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { user_id: 'user-1' },
      }),
    );
  });

  it('returns leaderboard overview for employee and manager users ordered by monthly earned points', async () => {
    const qb = {
      innerJoin: jest.fn().mockReturnThis(),
      leftJoin: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getRawMany: jest.fn().mockResolvedValue([
        {
          user_id: 'user-1',
          name: 'Alice',
          email: 'alice@example.com',
          avatar_url: null,
          odoo_uid: '101',
          odoo_employee_id: '201',
          job_title: 'Backend Developer',
          department: 'Development',
          balance: '120',
          lifetime_earned: '150',
          lifetime_spent: '30',
          updated_at: null,
        },
        {
          user_id: 'user-2',
          name: 'Bob',
          email: 'bob@example.com',
          avatar_url: '/avatar.png',
          odoo_uid: '102',
          odoo_employee_id: null,
          job_title: 'Designer',
          department: 'Marketing',
          balance: '80',
          lifetime_earned: '100',
          lifetime_spent: '20',
          updated_at: null,
        },
      ]),
    };
    userRepo.createQueryBuilder.mockReturnValue(qb);
    odooService.fetchTodayAttendance
      .mockResolvedValueOnce([{ id: 1 }])
      .mockResolvedValueOnce([]);
    odooService.findEmployeeIdByUserUidOrEmployeeId.mockResolvedValue(202);
    leaveRequestRepo.find.mockResolvedValue([
      {
        id: 'leave-1',
        user_id: 'user-2',
        type: 'ot',
        start_date: '2026-05-08',
        end_date: '2026-05-08',
        start_time: '18:00',
        end_time: '20:00',
        is_half_day: false,
        half_day_part: null,
        requested_days: 0,
        reason: 'Finish deployment',
        status: 'submitted',
        created_at: new Date('2026-05-08T08:00:00.000Z'),
        requester: {
          name: 'Bob',
          email: 'bob@example.com',
        },
      },
    ]);

    const result = await service.getOverview(10);

    expect(qb.innerJoin).toHaveBeenNthCalledWith(
      2,
      Role,
      'role',
      'role.id = userRole.role_id AND role.name IN (:...roleNames)',
      { roleNames: ['employee', 'manager'] },
    );
    expect(qb.orderBy).toHaveBeenCalledWith(
      'COALESCE(wallet.lifetime_earned, 0) - COALESCE(wallet.lifetime_spent, 0)',
      'DESC',
    );
    expect(qb.addOrderBy).toHaveBeenNthCalledWith(
      1,
      'COALESCE(wallet.balance, 0)',
      'DESC',
    );
    expect(qb.andWhere).not.toHaveBeenCalled();
    expect(qb.take).toHaveBeenCalledWith(10);
    expect(odooService.fetchTodayAttendance).toHaveBeenCalledWith(201);
    expect(
      odooService.findEmployeeIdByUserUidOrEmployeeId,
    ).toHaveBeenCalledWith(102);
    expect(leaveRequestRepo.find).toHaveBeenCalledWith({
      where: { status: 'submitted' },
      relations: ['requester'],
      order: { created_at: 'DESC' },
    });
    expect(result).toEqual({
      today_checkin_user_count: 1,
      leaderboard: [
        {
          rank: 1,
          user_id: 'user-1',
          name: 'Alice',
          email: 'alice@example.com',
          avatar_url: null,
          job_title: 'Backend Developer',
          department: 'Development',
          balance: 120,
          wallet_balance: 120,
          ranking_points: 120,
          lifetime_earned: 150,
          lifetime_spent: 30,
          updated_at: null,
        },
        {
          rank: 2,
          user_id: 'user-2',
          name: 'Bob',
          email: 'bob@example.com',
          avatar_url: '/avatar.png',
          job_title: 'Designer',
          department: 'Marketing',
          balance: 80,
          wallet_balance: 80,
          ranking_points: 80,
          lifetime_earned: 100,
          lifetime_spent: 20,
          updated_at: null,
        },
      ],
      pending_leave_requests: [
        {
          id: 'leave-1',
          user_id: 'user-2',
          user_name: 'Bob',
          user_email: 'bob@example.com',
          type: 'ot',
          start_date: '2026-05-08',
          end_date: '2026-05-08',
          start_time: '18:00',
          end_time: '20:00',
          is_half_day: false,
          half_day_part: null,
          requested_days: 0,
          reason: 'Finish deployment',
          status: 'submitted',
          created_at: new Date('2026-05-08T08:00:00.000Z'),
        },
      ],
    });
  });

  it('filters rewards overview to Development when department is Phát triển sản phẩm', async () => {
    const qb = {
      innerJoin: jest.fn().mockReturnThis(),
      leftJoin: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getRawMany: jest.fn().mockResolvedValue([]),
    };
    userRepo.createQueryBuilder.mockReturnValue(qb);
    leaveRequestRepo.find.mockResolvedValue([]);

    await service.getOverview(10, 'Phát triển sản phẩm');

    expect(qb.andWhere).toHaveBeenCalledWith('user.department = :department', {
      department: 'Development',
    });
  });

  it('filters rewards overview to non-Development when department is not Phát triển sản phẩm', async () => {
    const qb = {
      innerJoin: jest.fn().mockReturnThis(),
      leftJoin: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getRawMany: jest.fn().mockResolvedValue([]),
    };
    userRepo.createQueryBuilder.mockReturnValue(qb);
    leaveRequestRepo.find.mockResolvedValue([]);

    await service.getOverview(10, 'Kinh doanh');

    expect(qb.andWhere).toHaveBeenCalledWith(
      '(user.department IS NULL OR user.department != :department)',
      { department: 'Development' },
    );
  });

  it('returns the active monthly leaderboard from wallet ranking points', async () => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-06-29T10:00:00+07:00'));

    const qb = {
      innerJoin: jest.fn().mockReturnThis(),
      leftJoin: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getRawMany: jest.fn().mockResolvedValue([
        {
          user_id: 'user-1',
          name: 'Alice',
          email: 'alice@example.com',
          avatar_url: null,
          wallet_balance: '120',
          ranking_points: '35',
        },
      ]),
    };
    userRepo.createQueryBuilder.mockReturnValue(qb);

    const result = await service.getMonthlyLeaderboard(undefined, undefined, 10);

    expect(qb.innerJoin).toHaveBeenNthCalledWith(
      2,
      Role,
      'role',
      'role.id = userRole.role_id AND role.name IN (:...roleNames)',
      { roleNames: ['employee', 'manager'] },
    );
    expect(qb.leftJoin).toHaveBeenNthCalledWith(
      2,
      PointPeriodHistory,
      'history',
      'history.user_id = user.id AND history.period = :targetPeriod',
      { targetPeriod: '2026-07' },
    );
    expect(qb.select).toHaveBeenCalledWith([
      'user.id AS user_id',
      'user.name AS name',
      'user.avatar_url AS avatar_url',
      'user.email AS email',
      'COALESCE(wallet.balance, 0) AS wallet_balance',
      'COALESCE(wallet.lifetime_earned, 0) AS ranking_points',
    ]);
    expect(result).toEqual({
      period: '2026-07',
      is_active_period: true,
      leaderboard: [
        {
          rank: 1,
          user_id: 'user-1',
          name: 'Alice',
          email: 'alice@example.com',
          avatar_url: null,
          ranking_points: 35,
          wallet_balance: 120,
        },
      ],
    });
  });

  it('returns a historical monthly leaderboard from snapshot history', async () => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-06-29T10:00:00+07:00'));

    const qb = {
      innerJoin: jest.fn().mockReturnThis(),
      leftJoin: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getRawMany: jest.fn().mockResolvedValue([
        {
          user_id: 'user-2',
          name: 'Bob',
          email: 'bob@example.com',
          avatar_url: '/avatar.png',
          wallet_balance: '80',
          ranking_points: '100',
        },
      ]),
    };
    userRepo.createQueryBuilder.mockReturnValue(qb);

    const result = await service.getMonthlyLeaderboard(2026, 6, 5);

    expect(qb.leftJoin).toHaveBeenNthCalledWith(
      2,
      PointPeriodHistory,
      'history',
      'history.user_id = user.id AND history.period = :targetPeriod',
      { targetPeriod: '2026-06' },
    );
    expect(qb.select).toHaveBeenCalledWith([
      'user.id AS user_id',
      'user.name AS name',
      'user.avatar_url AS avatar_url',
      'user.email AS email',
      'COALESCE(wallet.balance, 0) AS wallet_balance',
      'COALESCE(history.points_earned, 0) AS ranking_points',
    ]);
    expect(result).toEqual({
      period: '2026-06',
      is_active_period: false,
      leaderboard: [
        {
          rank: 1,
          user_id: 'user-2',
          name: 'Bob',
          email: 'bob@example.com',
          avatar_url: '/avatar.png',
          ranking_points: 100,
          wallet_balance: 80,
        },
      ],
    });
  });

  it('snapshots the current reset cycle and resets only leaderboard points', async () => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-06-25T00:05:00+07:00'));

    const managerWalletRepo = createRepoMock();
    const managerHistoryRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointPeriodHistory, managerHistoryRepo);

    managerWalletRepo.find.mockResolvedValue([
      {
        user_id: 'user-1',
        balance: 120,
        lifetime_earned: 45,
        lifetime_spent: 10,
      },
      {
        user_id: 'user-2',
        balance: 30,
        lifetime_earned: 0,
        lifetime_spent: 12,
      },
    ]);
    managerHistoryRepo.save.mockImplementation(async (value) => value);
    managerWalletRepo.save.mockImplementation(async (value) => value);

    await service.snapshotMonthlyPoints();

    expect(managerHistoryRepo.save).toHaveBeenCalledWith({
      user_id: 'user-1',
      period: '2026-06',
      points_earned: 45,
    });
    expect(managerHistoryRepo.save).toHaveBeenCalledTimes(1);
    expect(managerWalletRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: 'user-1',
        balance: 120,
        lifetime_earned: 0,
        lifetime_spent: 0,
      }),
    );
    expect(managerWalletRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: 'user-2',
        balance: 30,
        lifetime_earned: 0,
        lifetime_spent: 0,
      }),
    );
  });

  it('returns active employees with id and name only', async () => {
    const qb = {
      innerJoin: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      distinct: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      getRawMany: jest.fn().mockResolvedValue([
        { id: 'user-1', name: 'Alice' },
        { id: 'user-2', name: 'Bob' },
      ]),
    };
    userRepo.createQueryBuilder.mockReturnValue(qb);

    const result = await service.listEmployees();

    expect(qb.innerJoin).toHaveBeenNthCalledWith(
      1,
      UserRole,
      'userRole',
      'userRole.user_id = user.id',
    );
    expect(qb.innerJoin).toHaveBeenNthCalledWith(
      2,
      Role,
      'role',
      'role.id = userRole.role_id AND role.name = :roleName',
      { roleName: 'employee' },
    );
    expect(qb.select).toHaveBeenCalledWith([
      'user.id AS id',
      'user.name AS name',
    ]);
    expect(qb.where).toHaveBeenCalledWith('user.is_active = true');
    expect(qb.distinct).toHaveBeenCalledWith(true);
    expect(qb.orderBy).toHaveBeenCalledWith('user.name', 'ASC');
    expect(qb.addOrderBy).toHaveBeenCalledWith('user.id', 'ASC');
    expect(result).toEqual([
      { id: 'user-1', name: 'Alice' },
      { id: 'user-2', name: 'Bob' },
    ]);
  });

  it('prevents duplicate attendance awards for the same source event', async () => {
    pointRuleRepo.findOne.mockResolvedValue({
      id: 'rule-1',
      name: 'Checkin',
      points: 5,
      is_active: true,
    });
    pointTransactionRepo.findOne.mockResolvedValue({
      id: 'tx-existing',
      event_key: 'attendance_checkin:555',
    });

    const result = await service.awardAttendanceEvent(
      'user-1',
      'attendance_checkin',
      '555',
    );

    expect(result.awarded).toBe(false);
    expect(result.reason).toBe('duplicate');
    expect(dataSource.transaction).not.toHaveBeenCalled();
  });

  it('returns only active reward items for admin by default', async () => {
    const qb = {
      where: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue([{ id: 'item-1', is_active: true }]),
    };
    rewardItemRepo.createQueryBuilder.mockReturnValue(qb);

    const result = await service.listRewardItems({}, true);

    expect(qb.where).toHaveBeenCalledWith('item.is_active = true');
    expect(qb.getMany).toHaveBeenCalled();
    expect(result).toEqual([{ id: 'item-1', is_active: true }]);
  });

  it('includes inactive reward items for admin only when explicitly requested', async () => {
    const qb = {
      where: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue([
        { id: 'item-1', is_active: true },
        { id: 'item-2', is_active: false },
      ]),
    };
    rewardItemRepo.createQueryBuilder.mockReturnValue(qb);

    const result = await service.listRewardItems(
      { include_inactive: true },
      true,
    );

    expect(qb.where).not.toHaveBeenCalled();
    expect(qb.getMany).toHaveBeenCalled();
    expect(result).toEqual([
      { id: 'item-1', is_active: true },
      { id: 'item-2', is_active: false },
    ]);
  });

  it('deletes a reward item for an active admin', async () => {
    userRepo.findOne.mockResolvedValue({ id: 'admin-1', is_active: true });
    rewardItemRepo.findOne.mockResolvedValue({ id: 'item-1', name: 'Bottle' });
    rewardItemRepo.delete.mockResolvedValue({ affected: 1 });

    await service.deleteRewardItem('admin-1', 'item-1');

    expect(rewardItemRepo.delete).toHaveBeenCalledWith({ id: 'item-1' });
  });

  it('throws when deleting a reward item that does not exist', async () => {
    userRepo.findOne.mockResolvedValue({ id: 'admin-1', is_active: true });
    rewardItemRepo.findOne.mockResolvedValue(null);

    await expect(
      service.deleteRewardItem('admin-1', 'missing-item'),
    ).rejects.toThrow('Reward item not found');
    expect(rewardItemRepo.delete).not.toHaveBeenCalled();
  });

  it('rejects redemption when the user balance is insufficient', async () => {
    const managerItemRepo = createRepoMock();
    const managerRedemptionRepo = createRepoMock();
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(RewardItem, managerItemRepo);
    managerRepos.set(RewardRedemption, managerRedemptionRepo);
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockResolvedValue({ id: 'user-1', is_active: true });
    managerItemRepo.findOne.mockResolvedValue({
      id: 'item-1',
      name: 'Bottle',
      is_active: true,
      stock_remaining: 10,
      points_cost: 100,
    });
    managerRedemptionRepo.save.mockResolvedValue({
      id: 'redeem-1',
      reward_item_id: 'item-1',
      quantity: 1,
      total_points_cost: 100,
    });
    managerWalletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 30,
      lifetime_earned: 30,
      lifetime_spent: 0,
    });

    await expect(
      service.redeemReward('user-1', {
        reward_item_id: 'item-1',
        quantity: 1,
      }),
    ).rejects.toThrow('Insufficient points balance');
  });

  it('deducts points and stock for a successful redemption', async () => {
    const managerItemRepo = createRepoMock();
    const managerRedemptionRepo = createRepoMock();
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(RewardItem, managerItemRepo);
    managerRepos.set(RewardRedemption, managerRedemptionRepo);
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      is_active: true,
      name: 'Alice',
    });
    roleRepo.findOne.mockResolvedValue({ id: 'role-admin', name: 'admin' });
    userRoleRepo.find.mockResolvedValue([
      { user_id: 'admin-1', role_id: 'role-admin' },
    ]);
    const item = {
      id: 'item-1',
      name: 'Bottle',
      is_active: true,
      stock_remaining: 3,
      points_cost: 20,
    };
    managerItemRepo.findOne.mockResolvedValue(item);
    managerRedemptionRepo.save.mockResolvedValue({
      id: 'redeem-1',
      user_id: 'user-1',
      reward_item_id: 'item-1',
      quantity: 2,
      unit_points_cost: 20,
      total_points_cost: 40,
    });
    managerRedemptionRepo.findOneOrFail.mockResolvedValue({
      id: 'redeem-1',
      user_id: 'user-1',
      reward_item_id: 'item-1',
      quantity: 2,
      status: 'pending',
      reward_item: { ...item, stock_remaining: 1 },
    });
    managerWalletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 100,
      lifetime_earned: 100,
      lifetime_spent: 0,
    });
    managerWalletRepo.save.mockResolvedValue({
      user_id: 'user-1',
      balance: 60,
      lifetime_earned: 100,
      lifetime_spent: 0,
    });
    managerTxRepo.save.mockResolvedValue({
      id: 'tx-1',
      user_id: 'user-1',
      points: -40,
      balance_after: 60,
    });

    const result = await service.redeemReward('user-1', {
      reward_item_id: 'item-1',
      quantity: 2,
    });

    expect(managerWalletRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: 'user-1',
        balance: 60,
        lifetime_earned: 100,
        lifetime_spent: 0,
      }),
    );
    expect(managerItemRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({ stock_remaining: 1 }),
    );
    expect(managerTxRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: 'user-1',
        points: -40,
        source_type: 'reward_redemption',
      }),
    );
    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'token-1',
      'Yêu cầu đổi quà đã được gửi',
      'Bạn đã gửi yêu cầu đổi 2 x Bottle.',
      expect.objectContaining({
        type: 'reward_redemption_created',
        reward_item_id: 'item-1',
      }),
    );
    expect(redisPubSubService.publishUserEvent).toHaveBeenCalledWith(
      'user-1',
      expect.objectContaining({
        _event: 'reward_points_changed',
        source_type: 'reward_redemption',
        transaction_type: 'spend',
        points: -40,
        balance: 60,
      }),
    );
    expect(result.status).toBe('pending');
  });

  it('notifies user when admin rejects a redemption', async () => {
    const managerItemRepo = createRepoMock();
    const managerRedemptionRepo = createRepoMock();
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(RewardItem, managerItemRepo);
    managerRepos.set(RewardRedemption, managerRedemptionRepo);
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockResolvedValue({ id: 'admin-1', is_active: true });
    managerRedemptionRepo.findOne.mockResolvedValue({
      id: 'redeem-1',
      user_id: 'user-1',
      reward_item_id: 'item-1',
      quantity: 1,
      unit_points_cost: 100,
      total_points_cost: 100,
      status: 'pending',
      reward_item: {
        id: 'item-1',
        name: 'Bottle',
        stock_remaining: 0,
      },
    });
    managerRedemptionRepo.save.mockImplementation(async (value) => value);
    managerItemRepo.save.mockImplementation(async (value) => value);
    managerWalletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 0,
      lifetime_earned: 0,
      lifetime_spent: 100,
    });
    managerWalletRepo.save.mockResolvedValue({
      user_id: 'user-1',
      balance: 100,
      lifetime_earned: 100,
      lifetime_spent: 100,
    });
    managerTxRepo.save.mockResolvedValue({
      id: 'tx-refund-1',
      user_id: 'user-1',
      points: 100,
      balance_after: 100,
    });
    managerRedemptionRepo.findOneOrFail.mockResolvedValue({
      id: 'redeem-1',
      user_id: 'user-1',
      reward_item_id: 'item-1',
      quantity: 1,
      unit_points_cost: 100,
      total_points_cost: 100,
      status: 'rejected',
      processed_note: 'Het hang',
      reward_item: { id: 'item-1', name: 'Bottle' },
    });

    await service.updateRedemptionStatus('admin-1', 'redeem-1', {
      status: 'rejected',
      processed_note: 'Het hang',
    });

    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'token-1',
      'Yêu cầu đổi quà bị từ chối',
      'Yêu cầu đổi 1 x Bottle không được chấp nhận. 100 điểm đã được hoàn. Lý do: Het hang',
      expect.objectContaining({
        type: 'reward_redemption_status_updated',
        status: 'rejected',
      }),
    );
    expect(redisPubSubService.publishUserEvent).toHaveBeenCalledWith(
      'user-1',
      expect.objectContaining({
        _event: 'reward_points_changed',
        source_type: 'reward_redemption_refund',
        transaction_type: 'earn',
        points: 100,
        balance: 100,
      }),
    );
  });

  it('does not award points again when a task was already rewarded before', async () => {
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      is_active: true,
      job_title: 'Developer',
    });
    taskTagConfigRepo.find.mockResolvedValue([
      {
        id: 15,
        tag_name: 'Dễ ( < 1h )',
        base_points: 1,
      },
    ]);
    odooService.fetchProjectTags.mockResolvedValue([
      { id: 15, name: 'Dễ ( < 1h )' },
    ]);
    jobTitleMappingRepo.find.mockResolvedValue([
      {
        job_title: 'Developer',
        internal_role: { name: 'Developer', multiplier: 2 },
      },
    ]);
    managerTxRepo.findOne.mockResolvedValue(null);
    managerTxRepo.find.mockResolvedValue([
      {
        source_ref_id: 'older-report',
        metadata: { task_id: '101' },
      },
    ]);
    walletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 10,
      lifetime_earned: 10,
      lifetime_spent: 0,
    });

    const result = await service.applyDailyReportPoints(
      'user-1',
      'Developer',
      'report-2',
      [
        {
          id: '101',
          name: 'Repeat task',
          status: 'done',
          tag_ids: [15],
        },
      ],
    );

    expect(result.totalPoints).toBe(0);
    expect(result.taskPointsMap.get('101')).toEqual({
      points: 0,
      reason: 'Task đã ăn điểm trước đó, không cộng lại',
    });
    expect(managerTxRepo.save).not.toHaveBeenCalled();
  });

  it('keeps QC reward logic unchanged even when the task was rewarded before', async () => {
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      is_active: true,
      job_title: 'QC',
    });
    taskTagConfigRepo.find.mockResolvedValue([
      {
        id: 11,
        tag_name: 'QC_Done',
        base_points: 0,
      },
      {
        id: 99,
        tag_name: 'Báo cáo lại',
        base_points: 9,
      },
    ]);
    odooService.fetchProjectTags.mockResolvedValue([]);
    jobTitleMappingRepo.find.mockResolvedValue([
      {
        job_title: 'QC',
        internal_role: { name: 'QC', multiplier: 2 },
      },
    ]);
    managerTxRepo.findOne.mockResolvedValue(null);
    managerTxRepo.find.mockResolvedValue([
      {
        source_ref_id: 'older-report',
        metadata: { task_id: '201' },
      },
    ]);
    managerWalletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 10,
      lifetime_earned: 10,
      lifetime_spent: 0,
    });
    managerWalletRepo.save.mockImplementation(async (wallet) => wallet);
    managerTxRepo.save.mockImplementation(async (tx) => ({
      id: 'tx-qc',
      ...tx,
    }));
    walletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 12,
      lifetime_earned: 12,
      lifetime_spent: 0,
    });

    const result = await service.applyDailyReportPoints(
      'user-1',
      'QC',
      'report-2',
      [
        {
          id: '201',
          name: 'QC repeat task',
          qc_done: 1,
        },
      ],
    );

    expect(result.totalPoints).toBe(2);
    expect(result.taskPointsMap.get('201')).toEqual({
      points: 2,
      reason: '',
    });
    expect(managerTxRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        points: 2,
        metadata: expect.not.objectContaining({
          is_re_report: true,
        }),
      }),
    );
  });

  it('uses the normal daily report reward path for QC tasks assigned to a QC assignee', async () => {
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      is_active: true,
      job_title: 'QC',
    });
    userRepo.find.mockResolvedValue([
      {
        job_title: 'QC',
      },
    ]);
    taskTagConfigRepo.find.mockResolvedValue([
      {
        id: 99,
        tag_name: 'Báo cáo lại',
        base_points: 9,
      },
    ]);
    odooService.fetchProjectTags.mockResolvedValue([]);
    jobTitleMappingRepo.find.mockResolvedValue([
      {
        job_title: 'QC',
        internal_role: { name: 'QC', multiplier: 2 },
      },
    ]);
    managerTxRepo.findOne.mockResolvedValue(null);
    managerTxRepo.find.mockResolvedValue([]);
    managerWalletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 10,
      lifetime_earned: 10,
      lifetime_spent: 0,
    });
    managerWalletRepo.save.mockImplementation(async (wallet) => wallet);
    managerTxRepo.save.mockImplementation(async (tx) => ({
      id: 'tx-qc-normal',
      ...tx,
    }));
    walletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 28,
      lifetime_earned: 28,
      lifetime_spent: 0,
    });

    const result = await service.applyDailyReportPoints(
      'user-1',
      'QC',
      'report-qc-normal',
      [
        {
          id: '301',
          name: 'QC assigned task',
          status: 'done',
          tag_ids: [99],
          user_ids: [501],
        },
      ],
    );

    expect(userRepo.find).toHaveBeenCalledWith({
      where: { odoo_uid: In([501]) },
      select: ['job_title'],
    });
    expect(result.totalPoints).toBe(18);
    expect(result.taskPointsMap.get('301')).toEqual({
      points: 18,
      reason: '',
    });
    expect(managerTxRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        points: 18,
        // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
        metadata: expect.objectContaining({
          base_points: 9,
          multiplier: 2,
        }),
      }),
    );
  });

  it('keeps the QC fixed-point fallback when no QC assignee is present', async () => {
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      is_active: true,
      job_title: 'QC',
    });
    userRepo.find.mockResolvedValue([
      {
        job_title: 'Developer',
      },
    ]);
    taskTagConfigRepo.find.mockResolvedValue([]);
    odooService.fetchProjectTags.mockResolvedValue([]);
    jobTitleMappingRepo.find.mockResolvedValue([
      {
        job_title: 'QC',
        internal_role: { name: 'QC', multiplier: 2 },
      },
      {
        job_title: 'Developer',
        internal_role: { name: 'Developer', multiplier: 2 },
      },
    ]);
    managerTxRepo.findOne.mockResolvedValue(null);
    managerTxRepo.find.mockResolvedValue([]);
    managerWalletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 10,
      lifetime_earned: 10,
      lifetime_spent: 0,
    });
    managerWalletRepo.save.mockImplementation(async (wallet) => wallet);
    managerTxRepo.save.mockImplementation(async (tx) => ({
      id: 'tx-qc-fallback',
      ...tx,
    }));
    walletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 12,
      lifetime_earned: 12,
      lifetime_spent: 0,
    });

    const result = await service.applyDailyReportPoints(
      'user-1',
      'QC',
      'report-qc-fallback',
      [
        {
          id: '302',
          name: 'Non-QC assigned task',
          status: 'done',
          tag_ids: [99],
          user_ids: [601],
        },
      ],
    );

    expect(result.totalPoints).toBe(2);
    expect(result.taskPointsMap.get('302')).toEqual({
      points: 2,
      reason: '',
    });
    expect(managerTxRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        points: 2,
        metadata: expect.objectContaining({
          points_per_task: 2,
        }),
      }),
    );
  });

  it('keeps the QC fixed-point fallback when QC assignees cannot be resolved', async () => {
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      is_active: true,
      job_title: 'QC',
    });
    userRepo.find.mockResolvedValue([]);
    taskTagConfigRepo.find.mockResolvedValue([]);
    odooService.fetchProjectTags.mockResolvedValue([]);
    jobTitleMappingRepo.find.mockResolvedValue([
      {
        job_title: 'QC',
        internal_role: { name: 'QC', multiplier: 2 },
      },
    ]);
    managerTxRepo.findOne.mockResolvedValue(null);
    managerTxRepo.find.mockResolvedValue([]);
    managerWalletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 10,
      lifetime_earned: 10,
      lifetime_spent: 0,
    });
    managerWalletRepo.save.mockImplementation(async (wallet) => wallet);
    managerTxRepo.save.mockImplementation(async (tx) => ({
      id: 'tx-qc-unresolved',
      ...tx,
    }));
    walletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 12,
      lifetime_earned: 12,
      lifetime_spent: 0,
    });

    const result: Awaited<
      ReturnType<RewardsService['applyDailyReportPoints']>
    > = await service.applyDailyReportPoints(
      'user-1',
      'QC',
      'report-qc-unresolved',
      [
        {
          id: '303',
          name: 'Unresolved assignee task',
          qc_done: 1,
          user_ids: [999],
        },
      ],
    );

    expect(result.totalPoints).toBe(2);
    expect(result.taskPointsMap.get('303')).toEqual({
      points: 2,
      reason: '',
    });
    expect(managerTxRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        points: 2,
        metadata: expect.objectContaining({
          points_per_task: 2,
        }),
      }),
    );
  });

  it('awards daily report points by configured tag id even when Odoo tag lookup is missing', async () => {
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      is_active: true,
      job_title: 'Fullstack Developer',
    });
    taskTagConfigRepo.find.mockResolvedValue([
      {
        id: 16,
        tag_name: 'Trung Bình ( <2h )',
        base_points: 2,
      },
    ]);
    odooService.fetchProjectTags.mockResolvedValue([]);
    jobTitleMappingRepo.find.mockResolvedValue([
      {
        job_title: 'Fullstack Developer',
        internal_role: { name: 'Developer', multiplier: 1 },
      },
    ]);
    managerTxRepo.findOne.mockResolvedValue(null);
    managerTxRepo.find.mockResolvedValue([]);
    managerWalletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 0,
      lifetime_earned: 0,
      lifetime_spent: 0,
    });
    managerWalletRepo.save.mockImplementation(async (wallet) => wallet);
    managerTxRepo.save.mockImplementation(async (tx) => ({
      id: 'tx-tag-id-fallback',
      ...tx,
    }));
    walletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 2,
      lifetime_earned: 2,
      lifetime_spent: 0,
    });

    const result = await service.applyDailyReportPoints(
      'user-1',
      'Fullstack Developer',
      'report-3',
      [
        {
          id: '3290',
          name: 'Task with configured tag id',
          status: 'done',
          tag_ids: [16],
        },
      ],
    );

    expect(result.totalPoints).toBe(2);
    expect(result.taskPointsMap.get('3290')).toEqual({
      points: 2,
      reason: '',
    });
    expect(managerTxRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        points: 2,
        metadata: expect.objectContaining({
          task_id: '3290',
          base_points: 2,
          multiplier: 1,
        }),
      }),
    );
  });

  it('reconciles edited daily reports by adding missing reward deltas', async () => {
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      is_active: true,
      job_title: 'Developer',
    });
    taskTagConfigRepo.find.mockResolvedValue([
      {
        id: 15,
        tag_name: 'Dễ ( < 1h )',
        base_points: 2,
      },
    ]);
    odooService.fetchProjectTags.mockResolvedValue([
      { id: 15, name: 'Dễ ( < 1h )' },
    ]);
    jobTitleMappingRepo.find.mockResolvedValue([
      {
        job_title: 'Developer',
        internal_role: { name: 'Developer', multiplier: 2 },
      },
    ]);
    managerTxRepo.find.mockImplementation(async ({ where }) => {
      if (where?.source_ref_id === 'report-1') {
        return [];
      }
      return [];
    });
    managerWalletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 10,
      lifetime_earned: 10,
      lifetime_spent: 0,
    });
    managerWalletRepo.save.mockImplementation(async (wallet) => wallet);
    managerTxRepo.save.mockImplementation(async (tx) => ({
      id: 'tx-reconcile-add',
      ...tx,
    }));
    walletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 14,
      lifetime_earned: 14,
      lifetime_spent: 0,
    });

    const result = await service.reconcileDailyReportPoints(
      'user-1',
      'Developer',
      'report-1',
      [
        {
          id: '101',
          name: 'Newly done task',
          status: 'done',
          tag_ids: [15],
        },
      ],
    );

    expect(result).toEqual(
      expect.objectContaining({
        totalPoints: 4,
        netDelta: 4,
        adjustedTaskCount: 1,
      }),
    );
    expect(result.taskPointsMap.get('101')).toEqual({
      points: 4,
      reason: '',
    });
    expect(managerTxRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        points: 4,
        type: 'adjust',
        source_type: 'daily_report_task',
        metadata: expect.objectContaining({
          correction: true,
          desired_points: 4,
          previous_points: 0,
          delta: 4,
        }),
      }),
    );
  });

  it('reconciles edited daily reports by revoking no-longer-eligible reward points', async () => {
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      is_active: true,
      job_title: 'Developer',
    });
    taskTagConfigRepo.find.mockResolvedValue([
      {
        id: 15,
        tag_name: 'Dễ ( < 1h )',
        base_points: 2,
      },
    ]);
    odooService.fetchProjectTags.mockResolvedValue([
      { id: 15, name: 'Dễ ( < 1h )' },
    ]);
    jobTitleMappingRepo.find.mockResolvedValue([
      {
        job_title: 'Developer',
        internal_role: { name: 'Developer', multiplier: 2 },
      },
    ]);
    managerTxRepo.find.mockImplementation(async ({ where }) => {
      if (where?.source_ref_id === 'report-1') {
        return [
          {
            points: 4,
            metadata: { task_id: '101', task_name: 'Task now doing' },
          },
        ];
      }
      return [];
    });
    managerWalletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 10,
      lifetime_earned: 10,
      lifetime_spent: 0,
    });
    managerWalletRepo.save.mockImplementation(async (wallet) => wallet);
    managerTxRepo.save.mockImplementation(async (tx) => ({
      id: 'tx-reconcile-revoke',
      ...tx,
    }));
    walletRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      balance: 6,
      lifetime_earned: 10,
      lifetime_spent: 0,
    });

    const result = await service.reconcileDailyReportPoints(
      'user-1',
      'Developer',
      'report-1',
      [
        {
          id: '101',
          name: 'Task now doing',
          status: 'doing',
          tag_ids: [15],
        },
      ],
    );

    expect(result).toEqual(
      expect.objectContaining({
        totalPoints: 0,
        netDelta: -4,
        adjustedTaskCount: 1,
      }),
    );
    expect(result.taskPointsMap.get('101')).toEqual({
      points: 0,
      reason: 'Task chưa hoàn thành (Doing)',
    });
    expect(managerTxRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        points: -4,
        type: 'adjust',
        source_type: 'daily_report_task',
        metadata: expect.objectContaining({
          correction: true,
          desired_points: 0,
          previous_points: 4,
          delta: -4,
        }),
      }),
    );
  });

  it('does not create duplicate reward deltas for repeated identical report edits', async () => {
    const managerWalletRepo = createRepoMock();
    const managerTxRepo = createRepoMock();
    managerRepos.set(UserPointWallet, managerWalletRepo);
    managerRepos.set(PointTransaction, managerTxRepo);

    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      is_active: true,
      job_title: 'Developer',
    });
    taskTagConfigRepo.find.mockResolvedValue([
      {
        id: 15,
        tag_name: 'Dễ ( < 1h )',
        base_points: 2,
      },
    ]);
    odooService.fetchProjectTags.mockResolvedValue([
      { id: 15, name: 'Dễ ( < 1h )' },
    ]);
    jobTitleMappingRepo.find.mockResolvedValue([
      {
        job_title: 'Developer',
        internal_role: { name: 'Developer', multiplier: 2 },
      },
    ]);
    managerTxRepo.find.mockImplementation(async ({ where }) => {
      if (where?.source_ref_id === 'report-1') {
        return [
          {
            points: 4,
            metadata: { task_id: '101', task_name: 'Already rewarded task' },
          },
        ];
      }
      return [];
    });

    const result = await service.reconcileDailyReportPoints(
      'user-1',
      'Developer',
      'report-1',
      [
        {
          id: '101',
          name: 'Already rewarded task',
          status: 'done',
          tag_ids: [15],
        },
      ],
    );

    expect(result).toEqual(
      expect.objectContaining({
        totalPoints: 4,
        netDelta: 0,
        adjustedTaskCount: 0,
      }),
    );
    expect(result.taskPointsMap.get('101')).toEqual({
      points: 4,
      reason: '',
    });
    expect(managerTxRepo.save).not.toHaveBeenCalled();
    expect(walletRepo.findOne).not.toHaveBeenCalled();
  });
});
