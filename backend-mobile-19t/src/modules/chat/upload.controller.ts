import {
  Controller,
  Post,
  UseInterceptors,
  UploadedFiles,
  BadRequestException,
  PayloadTooLargeException,
  Logger,
} from '@nestjs/common';
import {
  FilesInterceptor,
  FileFieldsInterceptor,
} from '@nestjs/platform-express';
import { ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { v4 as uuidv4 } from 'uuid';
import { mkdirSync } from 'fs';

const UPLOAD_DIR = join(process.cwd(), 'uploads', 'chat');
const DEFAULT_MAX_VIDEO_SIZE_MB = 250;
const configuredVideoLimitMb = Number(
  process.env.CHAT_VIDEO_MAX_FILE_SIZE_MB || DEFAULT_MAX_VIDEO_SIZE_MB,
);
const MAX_VIDEO_SIZE_MB =
  Number.isFinite(configuredVideoLimitMb) && configuredVideoLimitMb > 0
    ? configuredVideoLimitMb
    : DEFAULT_MAX_VIDEO_SIZE_MB;
const MAX_VIDEO_SIZE = MAX_VIDEO_SIZE_MB * 1024 * 1024;
const ALLOWED_VIDEO_TYPES = [
  'video/mp4',
  'video/quicktime',
  'video/x-msvideo',
  'video/x-matroska',
  'video/webm',
];
const ALLOWED_THUMBNAIL_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

// Ensure upload directories exist
mkdirSync(UPLOAD_DIR, { recursive: true });
mkdirSync(join(UPLOAD_DIR, 'videos'), { recursive: true });
mkdirSync(join(UPLOAD_DIR, 'thumbnails'), { recursive: true });

function normalizeOriginalName(originalname: string): string {
  try {
    const decoded = Buffer.from(originalname, 'latin1').toString('utf8');
    return decoded.includes('\uFFFD') ? originalname : decoded;
  } catch {
    return originalname;
  }
}

@ApiTags('chat')
@Controller('chat')
export class UploadController {
  private readonly logger = new Logger(UploadController.name);

  @Post('upload')
  @ApiOperation({
    summary: 'Upload non-video attachments for chat messages',
  })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FilesInterceptor('files', 10, {
      storage: diskStorage({
        destination: UPLOAD_DIR,
        filename: (_req, file, cb) => {
          const ext = extname(file.originalname).toLowerCase() || '.jpg';
          const filename = `${uuidv4()}-${Date.now()}${ext}`;
          cb(null, filename);
        },
      }),
    }),
  )
  uploadFiles(@UploadedFiles() files: Express.Multer.File[]) {
    if (!files || files.length === 0) {
      throw new BadRequestException('No files provided');
    }

    if (files.length > 10) {
      throw new BadRequestException('Maximum 10 files per upload');
    }

    this.logger.log(`Uploaded ${files.length} file(s)`);

    return {
      files: files.map((file) => ({
        url: `/uploads/chat/${file.filename}`,
        originalName: normalizeOriginalName(file.originalname),
        size: file.size,
        mimeType: file.mimetype,
      })),
    };
  }

  @Post('upload-video')
  @ApiOperation({ summary: 'Upload video and thumbnail for chat messages' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'video', maxCount: 1 },
        { name: 'thumbnail', maxCount: 1 },
      ],
      {
        storage: diskStorage({
          destination: (req, file, cb) => {
            const dir =
              file.fieldname === 'video'
                ? join(UPLOAD_DIR, 'videos')
                : join(UPLOAD_DIR, 'thumbnails');
            cb(null, dir);
          },
          filename: (_req, file, cb) => {
            const ext = extname(file.originalname).toLowerCase() || '.mp4';
            const filename = `${uuidv4()}-${Date.now()}${ext}`;
            cb(null, filename);
          },
        }),
        fileFilter: (_req, file, cb) => {
          if (file.fieldname === 'video') {
            if (!ALLOWED_VIDEO_TYPES.includes(file.mimetype)) {
              cb(
                new BadRequestException(`Invalid video type: ${file.mimetype}`),
                false,
              );
              return;
            }
          } else if (file.fieldname === 'thumbnail') {
            if (!ALLOWED_THUMBNAIL_TYPES.includes(file.mimetype)) {
              cb(
                new BadRequestException(
                  `Invalid thumbnail type: ${file.mimetype}`,
                ),
                false,
              );
              return;
            }
          }
          cb(null, true);
        },
        limits: {
          fileSize: MAX_VIDEO_SIZE,
          files: 2,
        },
      },
    ),
  )
  uploadVideo(
    @UploadedFiles()
    files: {
      video?: Express.Multer.File[];
      thumbnail?: Express.Multer.File[];
    },
  ) {
    if (!files.video || files.video.length === 0) {
      throw new BadRequestException('No video file provided');
    }

    const videoFile = files.video[0];
    const thumbnailFile = files.thumbnail?.[0];

    if (videoFile.size > MAX_VIDEO_SIZE) {
      throw new PayloadTooLargeException(
        `Video exceeds ${MAX_VIDEO_SIZE_MB}MB limit`,
      );
    }

    this.logger.log(
      `Uploaded video: ${videoFile.filename} (${videoFile.size} bytes)`,
    );

    return {
      video: {
        url: `/uploads/chat/videos/${videoFile.filename}`,
        originalName: normalizeOriginalName(videoFile.originalname),
        size: videoFile.size,
        mimeType: videoFile.mimetype,
      },
      thumbnail: thumbnailFile
        ? {
            url: `/uploads/chat/thumbnails/${thumbnailFile.filename}`,
            size: thumbnailFile.size,
          }
        : null,
    };
  }
}
