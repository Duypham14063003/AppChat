import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  PayloadTooLargeException,
  Post,
  Query,
  Res,
  StreamableFile,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { mkdirSync } from 'fs';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { v4 as uuidv4 } from 'uuid';
import type { Response } from 'express';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { Roles } from '../auth/decorators/roles.decorator.js';
import {
  CreateEmployeeContractDto,
  EmployeeListQueryDto,
  RenewEmployeeContractDto,
  UpdateEmployeeContractDto,
  UpdateEmployeeProfileDto,
} from './dto/employee.dto.js';
import { EmployeeService } from './services/employee.service.js';
import { EMPLOYEE_MANAGEMENT_ROLES } from './hr-role.utils.js';

const CONTRACT_UPLOAD_DIR = join(process.cwd(), 'uploads', 'hr', 'contracts');
const CONTRACT_ATTACHMENT_MIME_TYPES = [
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'image/jpeg',
  'image/png',
];
const CONTRACT_ATTACHMENT_MAX_SIZE = 10 * 1024 * 1024;
const PAYMENT_QR_UPLOAD_DIR = join(
  process.cwd(),
  'uploads',
  'hr',
  'payment-qr',
);
const PAYMENT_QR_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const PAYMENT_QR_MAX_SIZE = 5 * 1024 * 1024;

mkdirSync(CONTRACT_UPLOAD_DIR, { recursive: true });
mkdirSync(PAYMENT_QR_UPLOAD_DIR, { recursive: true });

const paymentQrUploadInterceptor = FileInterceptor('file', {
  storage: diskStorage({
    destination: PAYMENT_QR_UPLOAD_DIR,
    filename: (_req, file, cb) => {
      const ext =
        file.mimetype === 'image/jpeg'
          ? '.jpg'
          : file.mimetype === 'image/webp'
            ? '.webp'
            : '.png';
      cb(null, `${uuidv4()}-${Date.now()}${ext}`);
    },
  }),
  fileFilter: (_req, file, cb) => {
    if (!PAYMENT_QR_MIME_TYPES.includes(file.mimetype)) {
      cb(
        new BadRequestException(`Invalid payment QR type: ${file.mimetype}`),
        false,
      );
      return;
    }
    cb(null, true);
  },
  limits: { fileSize: PAYMENT_QR_MAX_SIZE },
});

@ApiTags('HR - Employees')
@ApiBearerAuth()
@Controller('hr/employees')
export class EmployeeController {
  constructor(private readonly employees: EmployeeService) {}

  @Roles(...EMPLOYEE_MANAGEMENT_ROLES)
  @Get()
  list(@Query() query: EmployeeListQueryDto) {
    return this.employees.list(query);
  }

  @Get('me')
  me(
    @CurrentUser('userId') userId: string,
    @CurrentUser('roles') roles: string[],
  ) {
    return this.employees.detail(userId, roles, userId);
  }

  @Patch('me/profile')
  updateMe(
    @CurrentUser('userId') userId: string,
    @CurrentUser('roles') roles: string[],
    @Body() dto: UpdateEmployeeProfileDto,
  ) {
    return this.employees.updateProfile(userId, roles, userId, dto);
  }

  @Post('me/payment-qr')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(paymentQrUploadInterceptor)
  uploadMyPaymentQr(
    @CurrentUser('userId') userId: string,
    @CurrentUser('roles') roles: string[],
    @UploadedFile() file: Express.Multer.File | undefined,
  ) {
    this.assertPaymentQrFile(file);
    return this.employees.uploadPaymentQr(userId, roles, userId, file!);
  }

  @Delete('me/payment-qr')
  deleteMyPaymentQr(
    @CurrentUser('userId') userId: string,
    @CurrentUser('roles') roles: string[],
  ) {
    return this.employees.deletePaymentQr(userId, roles, userId);
  }

  @Get('me/payment-qr/image/:filename')
  async getMyPaymentQrImage(
    @CurrentUser('userId') userId: string,
    @CurrentUser('roles') roles: string[],
    @Param('filename') filename: string,
    @Res({ passthrough: true }) response: Response,
  ) {
    const image = await this.employees.getPaymentQrImage(
      userId,
      roles,
      userId,
      filename,
    );
    response.setHeader('Content-Type', image.mimeType);
    response.setHeader('Cache-Control', 'private, max-age=300');
    return new StreamableFile(image.data);
  }

  @Roles(...EMPLOYEE_MANAGEMENT_ROLES)
  @Get('contracts/expiring')
  expiring() {
    return this.employees.expiring();
  }

  @Get(':id')
  detail(
    @CurrentUser('userId') actorId: string,
    @CurrentUser('roles') roles: string[],
    @Param('id') id: string,
  ) {
    return this.employees.detail(actorId, roles, id);
  }

  @Patch(':id/profile')
  updateProfile(
    @CurrentUser('userId') actorId: string,
    @CurrentUser('roles') roles: string[],
    @Param('id') id: string,
    @Body() dto: UpdateEmployeeProfileDto,
  ) {
    return this.employees.updateProfile(actorId, roles, id, dto);
  }

  @Post(':id/payment-qr')
  @Roles(...EMPLOYEE_MANAGEMENT_ROLES)
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(paymentQrUploadInterceptor)
  uploadPaymentQr(
    @CurrentUser('userId') actorId: string,
    @CurrentUser('roles') roles: string[],
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File | undefined,
  ) {
    this.assertPaymentQrFile(file);
    return this.employees.uploadPaymentQr(actorId, roles, id, file!);
  }

  @Delete(':id/payment-qr')
  @Roles(...EMPLOYEE_MANAGEMENT_ROLES)
  deletePaymentQr(
    @CurrentUser('userId') actorId: string,
    @CurrentUser('roles') roles: string[],
    @Param('id') id: string,
  ) {
    return this.employees.deletePaymentQr(actorId, roles, id);
  }

  @Get(':id/payment-qr/image/:filename')
  async getPaymentQrImage(
    @CurrentUser('userId') actorId: string,
    @CurrentUser('roles') roles: string[],
    @Param('id') id: string,
    @Param('filename') filename: string,
    @Res({ passthrough: true }) response: Response,
  ) {
    const image = await this.employees.getPaymentQrImage(
      actorId,
      roles,
      id,
      filename,
    );
    response.setHeader('Content-Type', image.mimeType);
    response.setHeader('Cache-Control', 'private, max-age=300');
    return new StreamableFile(image.data);
  }

  @Get(':id/contracts')
  contracts(
    @CurrentUser('userId') actorId: string,
    @CurrentUser('roles') roles: string[],
    @Param('id') id: string,
  ) {
    return this.employees.contracts(actorId, roles, id);
  }

  @Roles(...EMPLOYEE_MANAGEMENT_ROLES)
  @Post('contracts')
  createContract(
    @CurrentUser('userId') actorId: string,
    @Body() dto: CreateEmployeeContractDto,
  ) {
    return this.employees.createContract(actorId, dto);
  }

  @Roles(...EMPLOYEE_MANAGEMENT_ROLES)
  @Patch('contracts/:id')
  updateContract(
    @CurrentUser('userId') actorId: string,
    @Param('id') id: string,
    @Body() dto: UpdateEmployeeContractDto,
  ) {
    return this.employees.updateContract(actorId, id, dto);
  }

  @Roles(...EMPLOYEE_MANAGEMENT_ROLES)
  @Delete('contracts/:id')
  deleteContract(@Param('id') id: string) {
    return this.employees.deleteContract(id);
  }

  @Roles(...EMPLOYEE_MANAGEMENT_ROLES)
  @Post('contracts/:id/attachment')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: CONTRACT_UPLOAD_DIR,
        filename: (_req, file, cb) => {
          const ext = extname(file.originalname).toLowerCase() || '.bin';
          cb(null, `${uuidv4()}-${Date.now()}${ext}`);
        },
      }),
      fileFilter: (_req, file, cb) => {
        if (!CONTRACT_ATTACHMENT_MIME_TYPES.includes(file.mimetype)) {
          cb(
            new BadRequestException(
              `Invalid contract attachment type: ${file.mimetype}`,
            ),
            false,
          );
          return;
        }
        cb(null, true);
      },
      limits: { fileSize: CONTRACT_ATTACHMENT_MAX_SIZE },
    }),
  )
  uploadContractAttachment(
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File | undefined,
  ) {
    if (!file) throw new BadRequestException('No contract attachment provided');
    if (file.size > CONTRACT_ATTACHMENT_MAX_SIZE)
      throw new PayloadTooLargeException('Contract attachment exceeds 10MB');
    return this.employees.uploadContractAttachment(id, file);
  }

  @Roles(...EMPLOYEE_MANAGEMENT_ROLES)
  @Delete('contracts/:id/attachment')
  deleteContractAttachment(@Param('id') id: string) {
    return this.employees.deleteContractAttachment(id);
  }

  @Roles(...EMPLOYEE_MANAGEMENT_ROLES)
  @Post('contracts/:id/renew')
  renew(
    @CurrentUser('userId') actorId: string,
    @Param('id') id: string,
    @Body() dto: RenewEmployeeContractDto,
  ) {
    return this.employees.renewContract(actorId, id, dto);
  }

  private assertPaymentQrFile(file: Express.Multer.File | undefined): void {
    if (!file) throw new BadRequestException('No payment QR image provided');
    if (file.size > PAYMENT_QR_MAX_SIZE) {
      throw new PayloadTooLargeException('Payment QR image exceeds 5MB');
    }
  }
}
