import { Injectable, Inject, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { UploadService } from '../upload/upload.service';
import { FfmpegService, VideoStyle, VideoStyleInput } from './ffmpeg.service';
import axios from 'axios';
import * as fs from 'fs';
import { promisify } from 'util';

const writeFile = promisify(fs.writeFile);

interface GenerateVideoParams {
  trackId: number;
  startTime: number;
  duration: number;
  style: VideoStyleInput;
  userId: number;
}

@Injectable()
export class PromoVideoService {
  private readonly logger = new Logger(PromoVideoService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly upload: UploadService,
    private readonly ffmpeg: FfmpegService,
  ) {}

  async generateVideo(params: GenerateVideoParams): Promise<{ url: string; styleUsed: VideoStyle }> {
    const { trackId, startTime, duration, style, userId } = params;

    // ── 1. Fetch track + release + ownership ──────────────────
    const { rows: trackRows } = await this.pool.query(
      `SELECT t.id, t.title, t.audio_url, t.duration AS track_duration, t.release_id,
              r.cover_url, r.title AS release_title, a.user_id
       FROM tracks t
       JOIN releases r ON r.id = t.release_id
       JOIN artists a ON a.id = r.artist_id
       WHERE t.id = $1`,
      [trackId],
    );

    const track = trackRows[0];
    if (!track) {
      throw new HttpException('Track not found', HttpStatus.NOT_FOUND);
    }
    if (track.user_id !== userId) {
      throw new HttpException('Access denied', HttpStatus.FORBIDDEN);
    }
    if (!track.audio_url) {
      throw new HttpException('Track has no audio file', HttpStatus.BAD_REQUEST);
    }
    if (!track.cover_url) {
      throw new HttpException('Release has no cover image', HttpStatus.BAD_REQUEST);
    }

    // Resolve 'auto' style
    const resolvedStyle: VideoStyle =
      style === 'auto'
        ? this.ffmpeg.detectStyle(track.title, track.release_title)
        : style;

    // Validate startTime + duration within track length
    if (track.track_duration && startTime + duration > track.track_duration) {
      throw new HttpException(
        `Requested segment exceeds track duration (${track.track_duration}s)`,
        HttpStatus.BAD_REQUEST,
      );
    }

    this.logger.log(
      `[generate] trackId=${trackId} style=${style}→${resolvedStyle} ` +
      `start=${startTime}s dur=${duration}s user=${userId}`,
    );

    await this.ffmpeg.ensureTmpDir();

    // Temp file paths
    const coverTmp = this.ffmpeg.tmpFile('.jpg');
    const audioTmp = this.ffmpeg.tmpFile('.mp3');
    const audioCut = this.ffmpeg.tmpFile('.aac');
    const videoOut = this.ffmpeg.tmpFile('.mp4');

    try {
      // ── 2. Download cover + audio to temp ───────────────────
      await Promise.all([
        this.downloadFile(track.cover_url, coverTmp),
        this.downloadFile(track.audio_url, audioTmp),
      ]);
      this.logger.log('[generate] downloaded cover + audio');

      // ── 3. Cut audio segment ────────────────────────────────
      await this.ffmpeg.cutAudio(audioTmp, audioCut, startTime, duration);
      this.logger.log('[generate] audio cut done');

      // ── 4. Generate styled video ────────────────────────────
      await this.ffmpeg.generateVideo({
        coverPath: coverTmp,
        audioPath: audioCut,
        outputPath: videoOut,
        duration,
        style: resolvedStyle,
      });
      this.logger.log('[generate] video rendered');

      // ── 5. Upload to S3/MinIO ───────────────────────────────
      const videoBuffer = fs.readFileSync(videoOut);
      const { url } = await this.upload.uploadFile(
        {
          buffer: videoBuffer,
          originalname: `promo-${trackId}-${resolvedStyle}.mp4`,
          mimetype: 'video/mp4',
        } as Express.Multer.File,
        'production',
        String(userId),
        { type: 'promo', id: String(trackId) },
      );

      this.logger.log(`[generate] uploaded → ${url} (style: ${resolvedStyle})`);
      return { url, styleUsed: resolvedStyle };
    } finally {
      // ── 6. Cleanup temp files ───────────────────────────────
      await this.ffmpeg.cleanup(coverTmp, audioTmp, audioCut, videoOut);
      this.logger.log('[generate] temp files cleaned');
    }
  }

  // ── Download file from URL to local path ──────────────────
  private async downloadFile(url: string, destPath: string): Promise<void> {
    // If URL is relative to our storage, resolve to MinIO internal URL
    const resolved = this.resolveStorageUrl(url);

    const response = await axios.get(resolved, {
      responseType: 'arraybuffer',
      timeout: 60_000,
      maxContentLength: 200 * 1024 * 1024, // 200MB
    });

    await writeFile(destPath, Buffer.from(response.data));
  }

  // Convert public storage URL to internal MinIO URL for server-side download
  private resolveStorageUrl(url: string): string {
    const minioEndpoint = process.env.MINIO_ENDPOINT || 'http://localhost:9000';
    const bucket = process.env.MINIO_BUCKET || 'aurix';

    // Match any public storage URL pattern and extract the key
    // e.g. https://aurixmusic.ru/storage/covers/xxx.jpg → covers/xxx.jpg
    // e.g. https://194.67.99.229/storage/tracks/xxx.mp3 → tracks/xxx.mp3
    const storageMatch = url.match(/\/storage\/(.+)$/);
    if (storageMatch) {
      return `${minioEndpoint}/${bucket}/${storageMatch[1]}`;
    }

    // Already a direct MinIO URL or external URL
    return url;
  }
}
