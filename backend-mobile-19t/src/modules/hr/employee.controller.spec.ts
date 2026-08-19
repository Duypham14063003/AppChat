import { BadRequestException, PayloadTooLargeException } from '@nestjs/common';
import { EmployeeController } from './employee.controller';

describe('EmployeeController payment QR endpoints', () => {
  const employees = {
    uploadPaymentQr: jest.fn(),
    deletePaymentQr: jest.fn(),
    getPaymentQrImage: jest.fn(),
  };
  const controller = new EmployeeController(employees as any);

  beforeEach(() => jest.clearAllMocks());

  it('delegates self and HR-targeted uploads with actor context', async () => {
    const file = { filename: 'qr.png', size: 1024 } as Express.Multer.File;
    employees.uploadPaymentQr.mockResolvedValue({ bank_qr_source: 'uploaded' });

    await controller.uploadMyPaymentQr('user-1', ['employee'], file);
    await controller.uploadPaymentQr('hr-1', ['manager'], 'user-2', file);

    expect(employees.uploadPaymentQr).toHaveBeenNthCalledWith(
      1,
      'user-1',
      ['employee'],
      'user-1',
      file,
    );
    expect(employees.uploadPaymentQr).toHaveBeenNthCalledWith(
      2,
      'hr-1',
      ['manager'],
      'user-2',
      file,
    );
  });

  it('rejects missing and oversized files before service mutation', () => {
    expect(() => controller.uploadMyPaymentQr('user-1', [], undefined)).toThrow(
      BadRequestException,
    );
    expect(() =>
      controller.uploadMyPaymentQr('user-1', [], {
        size: 5 * 1024 * 1024 + 1,
      } as Express.Multer.File),
    ).toThrow(PayloadTooLargeException);
    expect(employees.uploadPaymentQr).not.toHaveBeenCalled();
  });

  it('delegates QR removal through self and target routes', async () => {
    await controller.deleteMyPaymentQr('user-1', ['employee']);
    await controller.deletePaymentQr('hr-1', ['manager'], 'user-2');

    expect(employees.deletePaymentQr).toHaveBeenNthCalledWith(
      1,
      'user-1',
      ['employee'],
      'user-1',
    );
    expect(employees.deletePaymentQr).toHaveBeenNthCalledWith(
      2,
      'hr-1',
      ['manager'],
      'user-2',
    );
  });

  it('streams QR bytes only through the authorized employee service', async () => {
    const response = { setHeader: jest.fn() };
    employees.getPaymentQrImage.mockResolvedValue({
      data: Buffer.from('png'),
      mimeType: 'image/png',
    });

    await controller.getPaymentQrImage(
      'hr-1',
      ['manager'],
      'user-2',
      'abc-123.png',
      response as any,
    );

    expect(employees.getPaymentQrImage).toHaveBeenCalledWith(
      'hr-1',
      ['manager'],
      'user-2',
      'abc-123.png',
    );
    expect(response.setHeader).toHaveBeenCalledWith(
      'Cache-Control',
      'private, max-age=300',
    );
  });
});
