import {
  Controller,
  Post,
  Delete,
  Param,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UploadService } from './upload.service';

const MAX_COVER = 10 * 1024 * 1024; // 10 MB
const MAX_AUDIO = 100 * 1024 * 1024; // 100 MB

// Magic bytes for image formats
const IMAGE_SIGNATURES: Array<{ bytes: number[]; offset?: number }> = [
  { bytes: [0xff, 0xd8, 0xff] },                     // JPEG
  { bytes: [0x89, 0x50, 0x4e, 0x47] },               // PNG
  { bytes: [0x52, 0x49, 0x46, 0x46] },               // WEBP (RIFF header)
  { bytes: [0x47, 0x49, 0x46, 0x38] },               // GIF
];

// Magic bytes for audio formats
const AUDIO_SIGNATURES: Array<{ bytes: number[]; offset?: number }> = [
  { bytes: [0x49, 0x44, 0x33] },                     // MP3 (ID3)
  { bytes: [0xff, 0xfb] },                           // MP3 (no ID3)
  { bytes: [0xff, 0xf3] },                           // MP3 (no ID3)
  { bytes: [0xff, 0xf2] },                           // MP3 (no ID3)
  { bytes: [0x66, 0x4c, 0x61, 0x43] },               // FLAC
  { bytes: [0x4f, 0x67, 0x67, 0x53] },               // OGG
  { bytes: [0x52, 0x49, 0x46, 0x46] },               // WAV (RIFF header)
  { bytes: [0x00, 0x00, 0x00], offset: 0 },          // M4A/AAC (ftyp box)
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

@UseGuards(JwtAuthGuard)
@Controller('upload')
export class UploadController {
  constructor(private readonly uploadService: UploadService) {}

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
  async uploadCover(@UploadedFile() file: Express.Multer.File) {
    if (!file) {
      throw new HttpException('file is required', HttpStatus.BAD_REQUEST);
    }
    // Validate magic bytes
    if (!matchesMagic(file.buffer, IMAGE_SIGNATURES)) {
      throw new HttpException(
        'invalid image file',
        HttpStatus.BAD_REQUEST,
      );
    }
    const url = await this.uploadService.uploadFile(file, 'covers');
    return { success: true, url };
  }

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
  async uploadAudio(@UploadedFile() file: Express.Multer.File) {
    if (!file) {
      throw new HttpException('file is required', HttpStatus.BAD_REQUEST);
    }
    // Validate magic bytes
    if (!matchesMagic(file.buffer, AUDIO_SIGNATURES)) {
      throw new HttpException(
        'invalid audio file',
        HttpStatus.BAD_REQUEST,
      );
    }
    const url = await this.uploadService.uploadFile(file, 'tracks');
    return { success: true, url };
  }

  @Delete(':key')
  async deleteFile(@Param('key') key: string) {
    // key comes URL-encoded, e.g. "covers%2Ffile.jpg" -> "covers/file.jpg"
    const decoded = decodeURIComponent(key);
    await this.uploadService.deleteFile(decoded);
    return { success: true };
  }
}
