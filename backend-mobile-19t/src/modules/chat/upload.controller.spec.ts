import { UploadController } from './upload.controller';

function createFile(
  overrides: Partial<Express.Multer.File> = {},
): Express.Multer.File {
  return {
    fieldname: 'files',
    originalname: 'report.pdf',
    encoding: '7bit',
    mimetype: 'application/pdf',
    size: 1024,
    destination: '/tmp',
    filename: 'stored-report.pdf',
    path: '/tmp/stored-report.pdf',
    buffer: Buffer.alloc(0),
    stream: undefined as never,
    ...overrides,
  };
}

describe('UploadController', () => {
  let controller: UploadController;

  beforeEach(() => {
    controller = new UploadController();
  });

  it('returns normalized metadata for uploaded document files', () => {
    const result = controller.uploadFiles([
      createFile(),
      createFile({
        originalname: 'sheet.xlsx',
        mimetype:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        filename: 'stored-sheet.xlsx',
      }),
    ]);

    expect(result).toEqual({
      files: [
        {
          url: '/uploads/chat/stored-report.pdf',
          originalName: 'report.pdf',
          size: 1024,
          mimeType: 'application/pdf',
        },
        {
          url: '/uploads/chat/stored-sheet.xlsx',
          originalName: 'sheet.xlsx',
          size: 1024,
          mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        },
      ],
    });
  });

  it('accepts uncommon mime types for generic chat uploads', () => {
    const result = controller.uploadFiles([
      createFile({
        originalname: 'debug.har',
        mimetype: 'application/json+har',
        filename: 'stored-debug.har',
      }),
    ]);

    expect(result).toEqual({
      files: [
        {
          url: '/uploads/chat/stored-debug.har',
          originalName: 'debug.har',
          size: 1024,
          mimeType: 'application/json+har',
        },
      ],
    });
  });

  it('decodes mojibake Vietnamese filenames from multipart uploads', () => {
    const originalName = Buffer.from('Chi tiết dịch vụ 19T Digital.docx', 'utf8')
      .toString('latin1');

    const result = controller.uploadFiles([
      createFile({
        originalname: originalName,
        filename: 'stored-vn.docx',
        mimetype:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      }),
    ]);

    expect(result).toEqual({
      files: [
        {
          url: '/uploads/chat/stored-vn.docx',
          originalName: 'Chi tiết dịch vụ 19T Digital.docx',
          size: 1024,
          mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        },
      ],
    });
  });

  it('preserves the dedicated video upload response shape', () => {
    const result = controller.uploadVideo({
      video: [
        createFile({
          fieldname: 'video',
          originalname: 'demo.mp4',
          mimetype: 'video/mp4',
          filename: 'stored-demo.mp4',
          size: 2048,
        }),
      ],
      thumbnail: [
        createFile({
          fieldname: 'thumbnail',
          originalname: 'thumb.jpg',
          mimetype: 'image/jpeg',
          filename: 'stored-thumb.jpg',
          size: 512,
        }),
      ],
    });

    expect(result).toEqual({
      video: {
        url: '/uploads/chat/videos/stored-demo.mp4',
        originalName: 'demo.mp4',
        size: 2048,
        mimeType: 'video/mp4',
      },
      thumbnail: {
        url: '/uploads/chat/thumbnails/stored-thumb.jpg',
        size: 512,
      },
    });
  });

  it('rejects oversized videos using the configured limit', () => {
    expect(() =>
      controller.uploadVideo({
        video: [
          createFile({
            fieldname: 'video',
            originalname: 'huge.mp4',
            mimetype: 'video/mp4',
            filename: 'stored-huge.mp4',
            size: 300 * 1024 * 1024,
          }),
        ],
      }),
    ).toThrow('Video exceeds 250MB limit');
  });
});
