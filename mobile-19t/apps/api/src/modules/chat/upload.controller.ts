import {
  Controller,
  Post,
  UseInterceptors,
  UploadedFiles,
  BadRequestException,
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
import { rename, unlink } from 'fs/promises';
import { spawn } from 'child_process';

const UPLOAD_DIR = join(__dirname, '..', '..', '..', 'uploads', 'chat');
const ALLOWED_VIDEO_TYPES = [
  'video/mp4',
  'video/quicktime',
  'video/x-msvideo',
  'video/x-matroska',
  'video/webm',
];
const ALLOWED_THUMBNAIL_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const FASTSTART_COMPATIBLE_VIDEO_EXTENSIONS = new Set(['.mp4', '.mov', '.m4v']);

// Ensure upload directories exist
mkdirSync(UPLOAD_DIR, { recursive: true });
mkdirSync(join(UPLOAD_DIR, 'videos'), { recursive: true });
mkdirSync(join(UPLOAD_DIR, 'thumbnails'), { recursive: true });

function shouldOptimizeVideoForStreaming(file: Express.Multer.File): boolean {
  const extension =
    extname(file.originalname).toLowerCase() ||
    extname(file.filename).toLowerCase();
  return FASTSTART_COMPATIBLE_VIDEO_EXTENSIONS.has(extension);
}

async function optimizeVideoForStreaming(filePath: string): Promise<void> {
  const tempPath = `${filePath}.faststart.tmp`;

  try {
    await new Promise<void>((resolve, reject) => {
      const ffmpeg = spawn('ffmpeg', [
        '-y',
        '-i',
        filePath,
        '-c',
        'copy',
        '-movflags',
        '+faststart',
        tempPath,
      ]);

      let stderr = '';

      ffmpeg.stderr.on('data', (chunk: Buffer | string) => {
        stderr += chunk.toString();
      });

      ffmpeg.on('error', reject);
      ffmpeg.on('close', (code) => {
        if (code === 0) {
          resolve();
          return;
        }
        reject(
          new Error(
            stderr.trim().length === 0
              ? `ffmpeg exited with code ${code}`
              : stderr.trim(),
          ),
        );
      });
    });
    await rename(tempPath, filePath);
  } catch (error) {
    await unlink(tempPath).catch(() => undefined);
    throw error;
  }
}

@ApiTags('chat')
@Controller('chat')
export class UploadController {
  private readonly logger = new Logger(UploadController.name);

  @Post('upload')
  @ApiOperation({ summary: 'Upload media files for chat messages' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FilesInterceptor('files', undefined, {
      storage: diskStorage({
        destination: UPLOAD_DIR,
        filename: (_req, file, cb) => {
          const ext = extname(file.originalname).toLowerCase() || '.jpg';
          const filename = `${uuidv4()}-${Date.now()}${ext}`;
          cb(null, filename);
        },
      }),
      fileFilter: (_req, _file, cb) => {
        cb(null, true);
      },
    }),
  )
  uploadImages(@UploadedFiles() files: Express.Multer.File[]) {
    if (!files || files.length === 0) {
      throw new BadRequestException('No files provided');
    }

    this.logger.log(`Uploaded ${files.length} file(s)`);

    return {
      files: files.map((file) => ({
        url: `/uploads/chat/${file.filename}`,
        originalName: file.originalname,
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
      },
    ),
  )
  async uploadVideo(
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

    this.logger.log(
      `Uploaded video: ${videoFile.filename} (${videoFile.size} bytes)`,
    );

    if (shouldOptimizeVideoForStreaming(videoFile)) {
      const filePath = join(UPLOAD_DIR, 'videos', videoFile.filename);
      try {
        await optimizeVideoForStreaming(filePath);
        this.logger.log(
          `Optimized video for streaming seek: ${videoFile.filename}`,
        );
      } catch (error) {
        this.logger.warn(
          `Failed to optimize uploaded video ${videoFile.filename}; keeping original file`,
          error instanceof Error ? error.message : String(error),
        );
      }
    }

    return {
      video: {
        url: `/uploads/chat/videos/${videoFile.filename}`,
        originalName: videoFile.originalname,
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
