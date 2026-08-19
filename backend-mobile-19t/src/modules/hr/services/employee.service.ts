import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { open, readFile, unlink } from 'fs/promises';
import { resolve, sep } from 'path';
import { DataSource, Repository } from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';
import {
  canManageEmployeeRoles,
  SUPPORTED_VIETQR_BANK_CODES,
} from '../hr-role.utils.js';
import { EmployeeContract, EmployeeProfile } from '../entities/index.js';
import {
  CreateEmployeeContractDto,
  EmployeeListQueryDto,
  RenewEmployeeContractDto,
  UpdateEmployeeContractDto,
  UpdateEmployeeProfileDto,
} from '../dto/employee.dto.js';

@Injectable()
export class EmployeeService {
  private readonly logger = new Logger(EmployeeService.name);
  private readonly paymentQrUploadRoot = resolve(
    process.cwd(),
    'uploads',
    'hr',
    'payment-qr',
  );

  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(EmployeeProfile)
    private readonly profileRepo: Repository<EmployeeProfile>,
    @InjectRepository(EmployeeContract)
    private readonly contractRepo: Repository<EmployeeContract>,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  async list(query: EmployeeListQueryDto) {
    const qb = this.userRepo
      .createQueryBuilder('user')
      .where('user.is_bot = false')
      .andWhere(
        `NOT EXISTS (
          SELECT 1
          FROM user_roles admin_user_role
          INNER JOIN roles admin_role ON admin_role.id = admin_user_role.role_id
          WHERE admin_user_role.user_id = "user"."id"
            AND admin_role.name = :adminRole
        )`,
        { adminRole: 'admin' },
      );
    if (query.search)
      qb.andWhere('(user.name ILIKE :search OR user.email ILIKE :search)', {
        search: `%${query.search}%`,
      });
    if (query.department)
      qb.andWhere('user.department = :department', {
        department: query.department,
      });
    if (query.job_title)
      qb.andWhere('user.job_title = :jobTitle', { jobTitle: query.job_title });
    if (query.is_active !== undefined)
      qb.andWhere('user.is_active = :active', { active: query.is_active });
    if (query.employment_status)
      qb.andWhere('user.employment_status = :status', {
        status: query.employment_status,
      });
    const [users, total] = await qb
      .orderBy('user.name', 'ASC')
      .addOrderBy('user.id', 'ASC')
      .skip((query.page - 1) * query.limit)
      .take(query.limit)
      .getManyAndCount();
    return {
      items: users.map((user) => this.summary(user)),
      total,
      page: query.page,
      limit: query.limit,
    };
  }

  async detail(requesterId: string, roles: string[], userId: string) {
    this.assertSelfOrHr(requesterId, roles, userId);
    const user = await this.userRepo.findOne({
      where: { id: userId, is_bot: false },
    });
    if (!user) throw new NotFoundException('Employee not found');
    const [profile, contracts] = await Promise.all([
      this.profileRepo.findOne({ where: { user_id: userId } }),
      this.contractRepo.find({
        where: { user_id: userId },
        order: { start_date: 'DESC' },
      }),
    ]);
    return {
      ...this.summary(user),
      profile: this.profileView(profile),
      contracts: contracts.map((contract) => this.contractView(contract)),
    };
  }

  async updateProfile(
    requesterId: string,
    roles: string[],
    userId: string,
    dto: UpdateEmployeeProfileDto,
  ) {
    this.assertSelfOrHr(requesterId, roles, userId);
    const isHr = canManageEmployeeRoles(roles);
    const selfFields = new Set([
      'current_address',
      'permanent_address',
      'personal_phone',
      'personal_email',
      'emergency_contact_name',
      'emergency_contact_phone',
      'emergency_contact_relationship',
      'marital_status',
      'bank_account_number',
      'bank_name',
      'bank_code',
      'bank_account_name',
      'bank_qr_source',
    ]);
    const values = Object.fromEntries(
      Object.entries(dto).filter(([key]) => isHr || selfFields.has(key)),
    );
    if (!isHr && Object.keys(values).length !== Object.keys(dto).length)
      throw new ForbiddenException(
        'Protected employee profile fields cannot be changed',
      );
    if (!(await this.userRepo.exist({ where: { id: userId, is_bot: false } })))
      throw new NotFoundException('Employee not found');
    let profile = await this.profileRepo.findOne({
      where: { user_id: userId },
    });
    const candidate = this.profileRepo.create({
      ...(profile ?? { user_id: userId }),
      ...values,
      updated_by: requesterId,
    });
    this.assertValidQrSource(candidate);
    profile = await this.profileRepo.save(candidate);
    return this.profileView(profile);
  }

  async uploadPaymentQr(
    requesterId: string,
    roles: string[],
    userId: string,
    file: Express.Multer.File,
  ) {
    const localUrl = `/uploads/hr/payment-qr/${file.filename}`;
    try {
      this.assertSelfOrHr(requesterId, roles, userId);
      if (
        !(await this.userRepo.exist({ where: { id: userId, is_bot: false } }))
      ) {
        throw new NotFoundException('Employee not found');
      }
      await this.assertValidPaymentQrFile(file);
      let profile = await this.profileRepo.findOne({
        where: { user_id: userId },
      });
      const oldUrl = profile?.bank_qr_image_url ?? null;
      const protectedUrl = `/api/v1/hr/employees/${userId}/payment-qr/image/${file.filename}`;
      profile = this.profileRepo.create({
        ...(profile ?? { user_id: userId }),
        bank_qr_image_url: protectedUrl,
        bank_qr_source: 'uploaded',
        updated_by: requesterId,
      });
      const saved = await this.profileRepo.save(profile);
      await this.tryDeleteManagedPaymentQr(oldUrl, protectedUrl);
      return this.profileView(saved);
    } catch (error) {
      await this.tryDeleteManagedPaymentQr(localUrl);
      throw error;
    }
  }

  async getPaymentQrImage(
    requesterId: string,
    roles: string[],
    userId: string,
    filename: string,
  ) {
    this.assertSelfOrHr(requesterId, roles, userId);
    if (!/^[0-9a-f-]+-\d+\.(?:jpg|png|webp)$/i.test(filename)) {
      throw new NotFoundException('Payment QR image not found');
    }
    const profile = await this.profileRepo.findOne({
      where: { user_id: userId },
    });
    const expectedUrl = `/api/v1/hr/employees/${userId}/payment-qr/image/${filename}`;
    const legacyUrl = `/uploads/hr/payment-qr/${filename}`;
    if (
      !profile ||
      ![expectedUrl, legacyUrl].includes(profile.bank_qr_image_url ?? '')
    ) {
      throw new NotFoundException('Payment QR image not found');
    }
    const path = this.resolveManagedPaymentQr(filename);
    try {
      return {
        data: await readFile(path),
        mimeType: this.paymentQrMimeType(filename),
      };
    } catch {
      throw new NotFoundException('Payment QR image not found');
    }
  }

  async deletePaymentQr(requesterId: string, roles: string[], userId: string) {
    this.assertSelfOrHr(requesterId, roles, userId);
    const profile = await this.profileRepo.findOne({
      where: { user_id: userId },
    });
    if (!profile) throw new NotFoundException('Employee profile not found');
    const oldUrl = profile.bank_qr_image_url;
    profile.bank_qr_image_url = null;
    profile.bank_qr_source = this.hasGeneratedQrDetails(profile)
      ? 'generated'
      : null;
    profile.updated_by = requesterId;
    const saved = await this.profileRepo.save(profile);
    await this.tryDeleteManagedPaymentQr(oldUrl);
    return this.profileView(saved);
  }

  async contracts(requesterId: string, roles: string[], userId: string) {
    this.assertSelfOrHr(requesterId, roles, userId);
    const rows = await this.contractRepo.find({
      where: { user_id: userId },
      order: { start_date: 'DESC' },
    });
    return rows.map((row) => this.contractView(row));
  }

  async createContract(actorId: string, dto: CreateEmployeeContractDto) {
    this.validateDates(dto.start_date, dto.end_date);
    if (
      !(await this.userRepo.exist({
        where: { id: dto.user_id, is_bot: false },
      }))
    )
      throw new NotFoundException('Employee not found');
    return this.contractRepo.save(
      this.contractRepo.create({
        ...dto,
        signed_date: dto.signed_date ?? null,
        end_date: dto.end_date ?? null,
        status: dto.status ?? 'draft',
        notes: dto.notes ?? null,
        created_by: actorId,
        updated_by: actorId,
      }),
    );
  }

  async updateContract(
    actorId: string,
    id: string,
    dto: UpdateEmployeeContractDto,
  ) {
    const contract = await this.contractRepo.findOne({ where: { id } });
    if (!contract) throw new NotFoundException('Contract not found');
    this.validateDates(
      dto.start_date ?? contract.start_date,
      dto.end_date === undefined ? contract.end_date : dto.end_date,
    );
    Object.assign(contract, dto, { updated_by: actorId });
    return this.contractRepo.save(contract);
  }

  async deleteContract(id: string) {
    const contract = await this.contractRepo.findOne({ where: { id } });
    if (!contract) throw new NotFoundException('Contract not found');
    await this.contractRepo.remove(contract);
    return { deleted: true };
  }

  async uploadContractAttachment(id: string, file: Express.Multer.File) {
    const contract = await this.contractRepo.findOne({ where: { id } });
    if (!contract) throw new NotFoundException('Contract not found');
    Object.assign(contract, {
      attachment_url: `/uploads/hr/contracts/${file.filename}`,
      attachment_name: this.normalizeOriginalName(file.originalname),
      attachment_mime_type: file.mimetype,
      attachment_size: file.size,
    });
    return this.contractRepo.save(contract);
  }

  async deleteContractAttachment(id: string) {
    const contract = await this.contractRepo.findOne({ where: { id } });
    if (!contract) throw new NotFoundException('Contract not found');
    Object.assign(contract, {
      attachment_url: null,
      attachment_name: null,
      attachment_mime_type: null,
      attachment_size: null,
    });
    return this.contractRepo.save(contract);
  }

  async renewContract(
    actorId: string,
    id: string,
    dto: RenewEmployeeContractDto,
  ) {
    const prior = await this.contractRepo.findOne({ where: { id } });
    if (!prior) throw new NotFoundException('Contract not found');
    this.validateDates(dto.start_date, dto.end_date);
    return this.dataSource.transaction(async (manager) => {
      prior.status = 'renewed';
      prior.updated_by = actorId;
      await manager.save(prior);
      return manager.save(
        manager.create(EmployeeContract, {
          ...dto,
          user_id: prior.user_id,
          signed_date: dto.signed_date ?? null,
          end_date: dto.end_date ?? null,
          status: dto.status ?? 'active',
          notes: dto.notes ?? null,
          renewed_from_id: prior.id,
          created_by: actorId,
          updated_by: actorId,
        }),
      );
    });
  }

  async expiring() {
    const today = new Date().toISOString().slice(0, 10);
    const rows = await this.contractRepo
      .createQueryBuilder('contract')
      .leftJoinAndSelect('contract.user', 'user')
      .where("contract.status = 'active'")
      .andWhere('contract.end_date IS NOT NULL')
      .andWhere("contract.type IN ('internship','probation','official')")
      .getMany();
    return rows
      .map((contract) => ({
        ...this.contractView(contract),
        employee: contract.user ? this.summary(contract.user) : null,
        days_until_expiry: this.daysBetween(today, contract.end_date!),
      }))
      .filter(
        (row) =>
          row.days_until_expiry >= 0 &&
          row.days_until_expiry <= (row.type === 'official' ? 10 : 7),
      );
  }

  private summary(user: User) {
    return {
      id: user.id,
      name: user.name,
      email: user.email,
      avatar_url: user.avatar_url,
      department: user.department,
      job_title: user.job_title,
      employment_status: user.employment_status,
      is_active: user.is_active,
    };
  }
  private contractView(contract: EmployeeContract) {
    return {
      ...contract,
      days_until_expiry: contract.end_date
        ? this.daysBetween(
            new Date().toISOString().slice(0, 10),
            contract.end_date,
          )
        : null,
    };
  }
  private assertSelfOrHr(requesterId: string, roles: string[], userId: string) {
    if (requesterId !== userId && !canManageEmployeeRoles(roles))
      throw new ForbiddenException('Cannot access another employee profile');
  }
  private assertValidQrSource(profile: Partial<EmployeeProfile>) {
    if (profile.bank_qr_source === 'uploaded' && !profile.bank_qr_image_url) {
      throw new BadRequestException(
        'Uploaded QR source requires a custom QR image',
      );
    }
    if (profile.bank_qr_source === 'generated') {
      const bankCode = profile.bank_code?.trim().toUpperCase() ?? '';
      const account = profile.bank_account_number?.replace(/\s+/g, '') ?? '';
      if (!bankCode || !account) {
        throw new BadRequestException(
          'Generated QR source requires bank code and account number',
        );
      }
      if (!SUPPORTED_VIETQR_BANK_CODES.has(bankCode)) {
        throw new BadRequestException('Unsupported VietQR bank code');
      }
      if (!/^[A-Za-z0-9]{6,19}$/.test(account)) {
        throw new BadRequestException(
          'Bank account number must contain 6 to 19 letters or digits',
        );
      }
      profile.bank_code = bankCode;
      profile.bank_account_number = account;
    }
  }
  private hasGeneratedQrDetails(profile: Partial<EmployeeProfile>) {
    const bankCode = profile.bank_code?.trim().toUpperCase() ?? '';
    const account = profile.bank_account_number?.replace(/\s+/g, '') ?? '';
    return (
      SUPPORTED_VIETQR_BANK_CODES.has(bankCode) &&
      /^[A-Za-z0-9]{6,19}$/.test(account)
    );
  }
  private profileView(profile: EmployeeProfile | null) {
    if (!profile) return null;
    let source = profile.bank_qr_source;
    if (source === 'uploaded' && !profile.bank_qr_image_url) {
      source = this.hasGeneratedQrDetails(profile) ? 'generated' : null;
    } else if (source === 'generated' && !this.hasGeneratedQrDetails(profile)) {
      source = profile.bank_qr_image_url ? 'uploaded' : null;
    }
    const bankQrImageUrl = profile.bank_qr_image_url
      ? `/api/v1/hr/employees/${profile.user_id}/payment-qr/image/${profile.bank_qr_image_url.split('/').pop()}`
      : null;
    return {
      ...profile,
      bank_qr_image_url: bankQrImageUrl,
      bank_qr_source: source,
    };
  }
  private async tryDeleteManagedPaymentQr(
    oldUrl: string | null,
    keepUrl?: string | null,
  ) {
    if (!oldUrl || oldUrl === keepUrl) return;
    const filename = oldUrl.split('/').pop();
    if (!filename) return;
    const isManagedUrl =
      oldUrl.startsWith('/uploads/hr/payment-qr/') ||
      /^\/api\/v1\/hr\/employees\/[^/]+\/payment-qr\/image\/[^/]+$/.test(
        oldUrl,
      );
    if (!isManagedUrl) return;
    const candidate = this.resolveManagedPaymentQr(filename);
    try {
      await unlink(candidate);
    } catch (error) {
      this.logger.warn(
        `Unable to clean up employee payment QR: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }
  private resolveManagedPaymentQr(filename: string) {
    const candidate = resolve(this.paymentQrUploadRoot, filename);
    if (!candidate.startsWith(`${this.paymentQrUploadRoot}${sep}`)) {
      throw new BadRequestException('Invalid payment QR path');
    }
    return candidate;
  }
  private paymentQrMimeType(filename: string) {
    if (filename.toLowerCase().endsWith('.jpg')) return 'image/jpeg';
    if (filename.toLowerCase().endsWith('.webp')) return 'image/webp';
    return 'image/png';
  }
  private async assertValidPaymentQrFile(file: Express.Multer.File) {
    let handle: Awaited<ReturnType<typeof open>> | null = null;
    try {
      let header: Buffer;
      if (file.buffer?.length) {
        header = file.buffer.subarray(0, 12);
      } else {
        handle = await open(file.path);
        header = Buffer.alloc(12);
        await handle.read(header, 0, 12, 0);
      }
      const isJpeg =
        header[0] === 0xff && header[1] === 0xd8 && header[2] === 0xff;
      const isPng = header
        .subarray(0, 8)
        .equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
      const isWebp =
        header.subarray(0, 4).toString('ascii') === 'RIFF' &&
        header.subarray(8, 12).toString('ascii') === 'WEBP';
      const valid =
        (file.mimetype === 'image/jpeg' && isJpeg) ||
        (file.mimetype === 'image/png' && isPng) ||
        (file.mimetype === 'image/webp' && isWebp);
      if (!valid) {
        throw new BadRequestException(
          'Payment QR content does not match its image type',
        );
      }
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      throw new BadRequestException('Unable to read payment QR image');
    } finally {
      await handle?.close();
    }
  }
  private validateDates(start: string, end?: string | null) {
    if (end && end < start)
      throw new BadRequestException(
        'Contract end date must not precede start date',
      );
  }
  private daysBetween(from: string, to: string) {
    return Math.ceil(
      (new Date(`${to}T00:00:00Z`).getTime() -
        new Date(`${from}T00:00:00Z`).getTime()) /
        86400000,
    );
  }
  private normalizeOriginalName(originalname: string) {
    try {
      const decoded = Buffer.from(originalname, 'latin1').toString('utf8');
      return decoded.includes('\uFFFD') ? originalname : decoded;
    } catch {
      return originalname;
    }
  }
}
