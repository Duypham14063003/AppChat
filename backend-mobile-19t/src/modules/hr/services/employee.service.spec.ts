import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { readFile, unlink } from 'fs/promises';
import { EmployeeService } from './employee.service';

jest.mock('fs/promises', () => ({
  ...jest.requireActual<typeof import('fs/promises')>('fs/promises'),
  readFile: jest.fn(),
  unlink: jest.fn(),
}));

const mockedReadFile = jest.mocked(readFile);
const mockedUnlink = jest.mocked(unlink);

describe('EmployeeService', () => {
  const userRepo = {
    createQueryBuilder: jest.fn(),
    findOne: jest.fn(),
    exist: jest.fn(),
  };
  const profileRepo = {
    findOne: jest.fn(),
    create: jest.fn((value) => value),
    save: jest.fn(async (value) => value),
  };
  const contractRepo = {
    find: jest.fn(),
    findOne: jest.fn(),
    create: jest.fn((value) => value),
    save: jest.fn(async (value) => ({ id: 'contract-1', ...value })),
    remove: jest.fn(async (value) => value),
    createQueryBuilder: jest.fn(),
  };
  const dataSource = { transaction: jest.fn() };
  const service = new EmployeeService(
    userRepo as any,
    profileRepo as any,
    contractRepo as any,
    dataSource as any,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    jest.restoreAllMocks();
    mockedReadFile.mockResolvedValue(Buffer.from('qr-image'));
    mockedUnlink.mockResolvedValue();
  });

  it('lists each non-bot non-admin employee once with stable pagination', async () => {
    const queryBuilder = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getManyAndCount: jest.fn().mockResolvedValue([
        [
          {
            id: 'active-employee',
            name: 'Active Employee',
            email: 'active@example.com',
            is_active: true,
            is_bot: false,
          },
          {
            id: 'inactive-employee',
            name: 'Inactive Employee',
            email: 'inactive@example.com',
            is_active: false,
            is_bot: false,
          },
        ],
        2,
      ]),
    };
    userRepo.createQueryBuilder.mockReturnValue(queryBuilder);

    const result = await service.list({ page: 2, limit: 50 });

    expect(queryBuilder.where).toHaveBeenCalledWith('user.is_bot = false');
    const adminExclusion = queryBuilder.andWhere.mock.calls.find(
      ([condition]) => String(condition).includes('NOT EXISTS'),
    );
    expect(adminExclusion).toEqual([
      expect.stringContaining('admin_user_role.user_id = "user"."id"'),
      { adminRole: 'admin' },
    ]);
    expect(queryBuilder.orderBy).toHaveBeenCalledWith('user.name', 'ASC');
    expect(queryBuilder.addOrderBy).toHaveBeenCalledWith('user.id', 'ASC');
    expect(queryBuilder.skip).toHaveBeenCalledWith(50);
    expect(queryBuilder.take).toHaveBeenCalledWith(50);
    expect(result).toEqual({
      items: [
        expect.objectContaining({
          id: 'active-employee',
          is_active: true,
        }),
        expect.objectContaining({
          id: 'inactive-employee',
          is_active: false,
        }),
      ],
      total: 2,
      page: 2,
      limit: 50,
    });
  });

  it('prevents employees from reading another employee profile', async () => {
    await expect(
      service.detail('user-1', ['employee'], 'user-2'),
    ).rejects.toThrow(ForbiddenException);
  });

  it('prevents self-service updates to protected profile fields', async () => {
    await expect(
      service.updateProfile('user-1', ['employee'], 'user-1', {
        tax_code: '123',
      }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('allows self-service payment updates without unlocking tax fields', async () => {
    userRepo.exist.mockResolvedValue(true);
    profileRepo.findOne.mockResolvedValue({ user_id: 'user-1' });

    const result = await service.updateProfile(
      'user-1',
      ['employee'],
      'user-1',
      {
        bank_code: 'VCB',
        bank_name: 'Vietcombank',
        bank_account_number: '123456789',
        bank_account_name: 'NGUYEN VAN A',
        bank_qr_source: 'generated',
      },
    );

    expect(result).toEqual(
      expect.objectContaining({
        bank_code: 'VCB',
        bank_qr_source: 'generated',
        updated_by: 'user-1',
      }),
    );
  });

  it('rejects impossible QR source selections', async () => {
    userRepo.exist.mockResolvedValue(true);
    profileRepo.findOne.mockResolvedValue({ user_id: 'user-1' });

    await expect(
      service.updateProfile('user-1', ['employee'], 'user-1', {
        bank_qr_source: 'uploaded',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('rejects an explicit generated source without complete bank details', async () => {
    userRepo.exist.mockResolvedValue(true);
    profileRepo.findOne.mockResolvedValue({ user_id: 'user-1' });

    await expect(
      service.updateProfile('user-1', ['employee'], 'user-1', {
        bank_qr_source: 'generated',
      }),
    ).rejects.toThrow(
      'Generated QR source requires bank code and account number',
    );
    expect(profileRepo.save).not.toHaveBeenCalled();
  });

  it('rejects unsupported generated QR bank details', async () => {
    userRepo.exist.mockResolvedValue(true);
    profileRepo.findOne.mockResolvedValue({ user_id: 'user-1' });

    await expect(
      service.updateProfile('user-1', ['employee'], 'user-1', {
        bank_code: 'UNKNOWN',
        bank_account_number: '123456789',
        bank_qr_source: 'generated',
      }),
    ).rejects.toThrow('Unsupported VietQR bank code');
  });

  it('lets the configured HR manager update another employee payment profile', async () => {
    userRepo.exist.mockResolvedValue(true);
    profileRepo.findOne.mockResolvedValue({ user_id: 'user-2' });

    await expect(
      service.updateProfile(
        'manager-1',
        ['4a5ce6f3-25e9-462a-b161-439a6a4e3e99'],
        'user-2',
        {
          bank_code: 'MB',
          bank_account_number: '99887766',
          bank_qr_source: 'generated',
        },
      ),
    ).resolves.toEqual(expect.objectContaining({ bank_code: 'MB' }));
  });

  it('rejects other configured roles from cross-user payment updates', async () => {
    await expect(
      service.updateProfile(
        'manager-1',
        ['80c32170-fcea-494d-8c40-54bfcfad32ec'],
        'user-2',
        { bank_account_number: '99887766' },
      ),
    ).rejects.toThrow(ForbiddenException);
    expect(profileRepo.save).not.toHaveBeenCalled();
  });

  it('uploads and removes employee payment QR metadata', async () => {
    userRepo.exist.mockResolvedValue(true);
    profileRepo.findOne
      .mockResolvedValueOnce({
        user_id: 'user-1',
        bank_code: 'VCB',
        bank_account_number: '123456',
      })
      .mockResolvedValueOnce({
        user_id: 'user-1',
        bank_code: 'VCB',
        bank_account_number: '123456',
        bank_qr_image_url: '/uploads/hr/payment-qr/stored.png',
        bank_qr_source: 'uploaded',
      });

    const uploaded = await service.uploadPaymentQr(
      'user-1',
      ['employee'],
      'user-1',
      {
        filename: 'stored.png',
        mimetype: 'image/png',
        buffer: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      } as Express.Multer.File,
    );
    expect(uploaded).toEqual(
      expect.objectContaining({
        bank_qr_image_url:
          '/api/v1/hr/employees/user-1/payment-qr/image/stored.png',
        bank_qr_source: 'uploaded',
      }),
    );

    const removed = await service.deletePaymentQr(
      'user-1',
      ['employee'],
      'user-1',
    );
    expect(removed).toEqual(
      expect.objectContaining({
        bank_qr_image_url: null,
        bank_qr_source: 'generated',
      }),
    );
  });

  it('cleans a superseded managed QR only after replacement is saved', async () => {
    userRepo.exist.mockResolvedValue(true);
    profileRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      bank_qr_image_url:
        '/api/v1/hr/employees/user-1/payment-qr/image/old-1.png',
      bank_qr_source: 'uploaded',
    });
    const serviceWithCleanupSpy = service as unknown as {
      tryDeleteManagedPaymentQr: (
        oldUrl: string,
        keepUrl?: string,
      ) => Promise<void>;
    };
    const cleanup = jest
      .spyOn(serviceWithCleanupSpy, 'tryDeleteManagedPaymentQr')
      .mockResolvedValue();

    await service.uploadPaymentQr('manager-1', ['manager'], 'user-1', {
      filename: 'new-2.png',
      mimetype: 'image/png',
      buffer: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    } as Express.Multer.File);

    expect(profileRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        bank_qr_image_url:
          '/api/v1/hr/employees/user-1/payment-qr/image/new-2.png',
      }),
    );
    expect(cleanup).toHaveBeenCalledWith(
      '/api/v1/hr/employees/user-1/payment-qr/image/old-1.png',
      '/api/v1/hr/employees/user-1/payment-qr/image/new-2.png',
    );
  });

  it('cleans the new upload when saving its metadata fails', async () => {
    userRepo.exist.mockResolvedValue(true);
    profileRepo.findOne.mockResolvedValue({ user_id: 'user-1' });
    profileRepo.save.mockRejectedValueOnce(new Error('database unavailable'));
    const serviceWithCleanupSpy = service as unknown as {
      tryDeleteManagedPaymentQr: (url: string) => Promise<void>;
    };
    const cleanup = jest
      .spyOn(serviceWithCleanupSpy, 'tryDeleteManagedPaymentQr')
      .mockResolvedValue();

    await expect(
      service.uploadPaymentQr('user-1', ['employee'], 'user-1', {
        filename: 'new-3.png',
        mimetype: 'image/png',
        buffer: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      } as Express.Multer.File),
    ).rejects.toThrow('database unavailable');

    expect(cleanup).toHaveBeenCalledWith('/uploads/hr/payment-qr/new-3.png');
  });

  it('does not fail replacement when superseded-file cleanup fails', async () => {
    userRepo.exist.mockResolvedValue(true);
    profileRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      bank_qr_image_url:
        '/api/v1/hr/employees/user-1/payment-qr/image/old-4.png',
      bank_qr_source: 'uploaded',
    });
    mockedUnlink.mockRejectedValueOnce(new Error('file is locked'));

    await expect(
      service.uploadPaymentQr('user-1', ['employee'], 'user-1', {
        filename: 'new-4.png',
        mimetype: 'image/png',
        buffer: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      } as Express.Multer.File),
    ).resolves.toEqual(
      expect.objectContaining({
        bank_qr_image_url:
          '/api/v1/hr/employees/user-1/payment-qr/image/new-4.png',
        bank_qr_source: 'uploaded',
      }),
    );
  });

  it('does not fail removal when local-file cleanup fails', async () => {
    profileRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      bank_code: 'VCB',
      bank_account_number: '123456',
      bank_qr_image_url:
        '/api/v1/hr/employees/user-1/payment-qr/image/old-5.png',
      bank_qr_source: 'uploaded',
    });
    mockedUnlink.mockRejectedValueOnce(new Error('file is locked'));

    await expect(
      service.deletePaymentQr('user-1', ['employee'], 'user-1'),
    ).resolves.toEqual(
      expect.objectContaining({
        bank_qr_image_url: null,
        bank_qr_source: 'generated',
      }),
    );
  });

  it.each([
    ['image/jpeg', 'photo-1.jpg', [0xff, 0xd8, 0xff, 0xe0]],
    [
      'image/webp',
      'photo-2.webp',
      [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50],
    ],
  ])('accepts valid %s payment QR bytes', async (mimetype, filename, bytes) => {
    userRepo.exist.mockResolvedValue(true);
    profileRepo.findOne.mockResolvedValue({ user_id: 'user-1' });
    const serviceWithCleanupSpy = service as unknown as {
      tryDeleteManagedPaymentQr: (url: string) => Promise<void>;
    };
    jest
      .spyOn(serviceWithCleanupSpy, 'tryDeleteManagedPaymentQr')
      .mockResolvedValue();

    await expect(
      service.uploadPaymentQr('user-1', ['employee'], 'user-1', {
        filename,
        mimetype,
        buffer: Buffer.from(bytes),
      } as Express.Multer.File),
    ).resolves.toEqual(expect.objectContaining({ bank_qr_source: 'uploaded' }));
  });

  it('rejects unauthorized image reads and malformed managed filenames', async () => {
    await expect(
      service.getPaymentQrImage(
        'user-1',
        ['employee'],
        'user-2',
        'abc-123.png',
      ),
    ).rejects.toThrow(ForbiddenException);
    await expect(
      service.getPaymentQrImage(
        'user-1',
        ['employee'],
        'user-1',
        '../secret.png',
      ),
    ).rejects.toThrow(NotFoundException);
    expect(profileRepo.findOne).not.toHaveBeenCalled();
  });

  it('returns an authenticated employee payment QR image', async () => {
    const image = Buffer.from('protected-qr-image');
    mockedReadFile.mockResolvedValue(image);
    profileRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      bank_qr_image_url:
        '/api/v1/hr/employees/user-1/payment-qr/image/abc-123.png',
    });

    await expect(
      service.getPaymentQrImage(
        'user-1',
        ['employee'],
        'user-1',
        'abc-123.png',
      ),
    ).resolves.toEqual({ data: image, mimeType: 'image/png' });
    expect(mockedReadFile).toHaveBeenCalledWith(
      expect.stringContaining('uploads/hr/payment-qr/abc-123.png'),
    );
  });

  it('cleans the newly written upload when authorization fails', async () => {
    const serviceWithCleanupSpy = service as unknown as {
      tryDeleteManagedPaymentQr: (url: string) => Promise<void>;
    };
    const cleanup = jest
      .spyOn(serviceWithCleanupSpy, 'tryDeleteManagedPaymentQr')
      .mockResolvedValue();

    await expect(
      service.uploadPaymentQr('user-1', ['employee'], 'user-2', {
        filename: 'unauthorized.png',
      } as Express.Multer.File),
    ).rejects.toThrow(ForbiddenException);

    expect(cleanup).toHaveBeenCalledWith(
      '/uploads/hr/payment-qr/unauthorized.png',
    );
  });

  it('rejects image bytes that do not match the declared QR MIME type', async () => {
    userRepo.exist.mockResolvedValue(true);
    const serviceWithCleanupSpy = service as unknown as {
      tryDeleteManagedPaymentQr: (url: string) => Promise<void>;
    };
    jest
      .spyOn(serviceWithCleanupSpy, 'tryDeleteManagedPaymentQr')
      .mockResolvedValue();

    await expect(
      service.uploadPaymentQr('user-1', ['employee'], 'user-1', {
        filename: 'fake.png',
        mimetype: 'image/png',
        buffer: Buffer.from('not-a-png'),
      } as Express.Multer.File),
    ).rejects.toThrow('does not match its image type');
  });

  it('rejects contracts whose end date precedes start date', async () => {
    await expect(
      service.createContract('admin-1', {
        user_id: 'user-1',
        type: 'probation',
        start_date: '2026-08-01',
        end_date: '2026-07-01',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('creates a valid employee contract without replacing history', async () => {
    userRepo.exist.mockResolvedValue(true);
    const result = await service.createContract('admin-1', {
      user_id: 'user-1',
      type: 'official',
      start_date: '2026-08-01',
      end_date: '2027-08-01',
      status: 'active',
    });
    expect(result).toEqual(
      expect.objectContaining({
        user_id: 'user-1',
        created_by: 'admin-1',
        status: 'active',
      }),
    );
  });

  it('deletes an existing employee contract', async () => {
    const contract = { id: 'contract-1', user_id: 'user-1' };
    contractRepo.findOne.mockResolvedValue(contract);

    await expect(service.deleteContract('contract-1')).resolves.toEqual({
      deleted: true,
    });
    expect(contractRepo.remove).toHaveBeenCalledWith(contract);
  });

  it('rejects deleting an unknown employee contract', async () => {
    contractRepo.findOne.mockResolvedValue(null);

    await expect(service.deleteContract('missing-contract')).rejects.toThrow(
      NotFoundException,
    );
  });

  it('stores employee contract attachment metadata', async () => {
    const contract = { id: 'contract-1', user_id: 'user-1' };
    contractRepo.findOne.mockResolvedValue(contract);

    const result = await service.uploadContractAttachment('contract-1', {
      filename: 'stored-file.pdf',
      originalname: 'contract.pdf',
      mimetype: 'application/pdf',
      size: 1234,
    } as Express.Multer.File);

    expect(contractRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        attachment_url: '/uploads/hr/contracts/stored-file.pdf',
        attachment_name: 'contract.pdf',
        attachment_mime_type: 'application/pdf',
        attachment_size: 1234,
      }),
    );
    expect(result).toEqual(expect.objectContaining({ id: 'contract-1' }));
  });

  it('clears employee contract attachment metadata', async () => {
    const contract = {
      id: 'contract-1',
      user_id: 'user-1',
      attachment_url: '/uploads/hr/contracts/file.pdf',
    };
    contractRepo.findOne.mockResolvedValue(contract);

    await service.deleteContractAttachment('contract-1');

    expect(contractRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        attachment_url: null,
        attachment_name: null,
        attachment_mime_type: null,
        attachment_size: null,
      }),
    );
  });
});
