import {
  Controller,
  Post,
  Get,
  Delete,
  Param,
  Query,
  Req,
  Res,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  HttpException,
  HttpStatus,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import type { Response } from 'express';
import { Throttle } from '@nestjs/throttler';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { UploadService } from './upload.service';

const MAX_COVER = 10 * 1024 * 1024;
const MAX_AUDIO = 100 * 1024 * 1024;

const IMAGE_SIGNATURES: Array<{ bytes: number[]; offset?: number }> = [
  { bytes: [0xff, 0xd8, 0xff] },
  { bytes: [0x89, 0x50, 0x4e, 0x47] },
  { bytes: [0x52, 0x49, 0x46, 0x46] },
  { bytes: [0x47, 0x49, 0x46, 0x38] },
];

const AUDIO_SIGNATURES: Array<{ bytes: number[]; offset?: number }> = [
  { bytes: [0x49, 0x44, 0x33] },
  { bytes: [0xff, 0xfb] },
  { bytes: [0xff, 0xf3] },
  { bytes: [0xff, 0xf2] },
  { bytes: [0x66, 0x4c, 0x61, 0x43] },
  { bytes: [0x4f, 0x67, 0x67, 0x53] },
  { bytes: [0x52, 0x49, 0x46, 0x46] },
  { bytes: [0x00, 0x00, 0x00], offset: 0 },
];

function matchesMagic(
  buffer: Buffer,
  sigs: Array<{ bytes: number[]; offset?: number }>,
): boolean {
  return sigs.some((sig) => {
    const off = sig.offset ?? 0;
    if (buffer.length < off + sig.bytes.length) return false;
    return sig.bytes.every((b, i) => buffer[off + i] === b);
  });
}

function clientIp(req: any): string | undefined {
  const xff = req.headers?.['x-forwarded-for'];
  if (typeof xff === 'string') return xff.split(',')[0].trim();
  return req.ip ?? req.connection?.remoteAddress;
}

function userAgent(req: any): string | undefined {
  return req.headers?.['user-agent']?.slice(0, 512);
}

@UseGuards(JwtAuthGuard)
@Controller('upload')
export class UploadController {
  constructor(private readonly svc: UploadService) {}

  // ── Upload cover ────────────────────────────────────────

  @Post('cover')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_COVER },
      fileFilter: (_req, file, cb) => {
        if (!file.mimetype.startsWith('image/')) {
          return cb(
            new HttpException('only image files allowed', HttpStatus.BAD_REQUEST),
            false,
          );
        }
        cb(null, true);
      },
    }),
  )
  async uploadCover(
    @Req() req: any,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new HttpException('file is required', HttpStatus.BAD_REQUEST);
    if (!matchesMagic(file.buffer, IMAGE_SIGNATURES)) {
      throw new HttpException('invalid image file', HttpStatus.BAD_REQUEST);
    }
    const userId = req.user?.id;
    await this.svc.trackDevice(userId, clientIp(req) ?? '0.0.0.0', userAgent(req));
    const { key, url } = await this.svc.uploadFile(file, 'covers', userId);
    return { success: true, url, key };
  }

  // ── Upload audio ────────────────────────────────────────

  @Post('audio')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_AUDIO },
      fileFilter: (_req, file, cb) => {
        if (!file.mimetype.startsWith('audio/')) {
          return cb(
            new HttpException('only audio files allowed', HttpStatus.BAD_REQUEST),
            false,
          );
        }
        cb(null, true);
      },
    }),
  )
  async uploadAudio(
    @Req() req: any,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new HttpException('file is required', HttpStatus.BAD_REQUEST);
    if (!matchesMagic(file.buffer, AUDIO_SIGNATURES)) {
      throw new HttpException('invalid audio file', HttpStatus.BAD_REQUEST);
    }
    const userId = req.user?.id;
    await this.svc.trackDevice(userId, clientIp(req) ?? '0.0.0.0', userAgent(req));
    const { key, url } = await this.svc.uploadFile(file, 'tracks', userId);
    return { success: true, url, key };
  }

  // ── Signed URL ──────────────────────────────────────────

  @Throttle({ default: { ttl: 60000, limit: 60 } })
  @Get('signed')
  async getSignedUrl(
    @Req() req: any,
    @Query('key') key: string,
  ) {
    const userId = req.user?.id;
    const ip = clientIp(req);
    const ua = userAgent(req);
    if (!userId) throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);

    if (!key || !this.svc.validateKey(key)) {
      throw new BadRequestException('Invalid file key');
    }

    // 1. File access block check
    if (await this.svc.isFileAccessBlocked(userId)) {
      await this.svc.logSecurity(userId, 'signed_url_while_blocked', key, 'high', { ip });
      throw new HttpException(
        'File access temporarily restricted',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // 2. Download quota check
    const quota = await this.svc.getDownloadQuota(userId);
    if (quota.blocked) {
      await this.svc.logSecurity(userId, 'download_quota_exceeded', key, 'medium', {
        hourly: quota.hourly, daily: quota.daily, ip,
      });
      throw new HttpException(
        'Download limit reached. Try again later.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // 3. Ownership check
    const owned = await this.svc.isOwnedByUser(key, userId);
    if (!owned) {
      throw new ForbiddenException('Access denied');
    }

    // 4. Track device
    await this.svc.trackDevice(userId, ip ?? '0.0.0.0', ua);

    // 5. Generate signed URL with folder-aware TTL
    const result = await this.svc.createSignedUrl(key, userId, { ip, userAgent: ua });

    // 6. Background: check for download abuse
    this.svc.checkDownloadAbuse(userId, ip).catch(() => {});

    return result;
  }

  // ── Admin download ──────────────────────────────────────
  // Стримит файл через API с принудительным Content-Disposition и Content-Type,
  // чтобы браузер сохранял как нормальный медиафайл (mp3/wav/png), а не как binary doc.

  @Get('admin/download')
  @UseGuards(AdminGuard)
  async adminDownload(
    @Req() req: any,
    @Res({ passthrough: false }) res: Response,
    @Query('key') key: string,
    @Query('filename') filename?: string,
  ) {
    const userId = req.user?.id;
    if (!userId) throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);

    if (!key || !this.svc.validateKey(key)) {
      throw new BadRequestException('Invalid file key');
    }

    const safeName = this.svc.sanitizeDownloadFilename(filename, key);
    await this.svc.streamDownload(key, safeName, res, {
      ip: clientIp(req),
      userAgent: userAgent(req),
      adminId: userId,
    });
  }

  // ── Delete file ─────────────────────────────────────────

  @Throttle({ default: { ttl: 60000, limit: 20 } })
  @Delete(':key')
  async deleteFile(@Req() req: any, @Param('key') key: string) {
    const userId = req.user?.id;
    const ip = clientIp(req);
    if (!userId) throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);

    const decoded = decodeURIComponent(key);

    if (!this.svc.validateKey(decoded)) {
      throw new BadRequestException('Invalid file key');
    }

    if (await this.svc.isDeleteBlocked(userId)) {
      await this.svc.logSecurity(userId, 'delete_while_blocked', decoded, 'high', { ip });
      throw new HttpException(
        'Deletions temporarily blocked. Try again later.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    if (await this.svc.isDeletionRateLimited(userId)) {
      await this.svc.logSecurity(userId, 'delete_rate_limited', decoded, 'medium', { ip });
      throw new HttpException(
        'Too many deletions, try again later',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const owned = await this.svc.isOwnedByUser(decoded, userId);
    if (!owned) {
      await this.svc.logSecurity(userId, 'delete_access_denied', decoded, 'high', { ip });
      throw new ForbiddenException('Access denied');
    }

    await this.svc.softDelete(decoded, userId);
    await this.svc.logSecurity(userId, 'file_deleted', decoded, 'low', { ip });
    await this.svc.checkAndAutoBlock(userId, ip);

    return { success: true };
  }
}
