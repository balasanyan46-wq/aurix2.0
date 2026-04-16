import { Injectable, Inject, Logger, OnModuleInit } from '@nestjs/common';
import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
  GetObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { randomUUID } from 'crypto';
import * as path from 'path';

const SAFE_KEY_RE = /^(covers|tracks|production)\/[a-zA-Z0-9\-_.]+$/;

type EntityType = 'release' | 'track' | 'promo';
type RiskLevel = 'low' | 'medium' | 'high' | 'critical';
type Folder = 'covers' | 'tracks' | 'production';

/** Folder-specific TTL defaults and max (seconds) */
const FOLDER_TTL: Record<string, { default: number; max: number }> = {
  covers:     { default: 120, max: 120 },
  tracks:     { default: 60,  max: 60 },
  production: { default: 120, max: 120 },
};

/** Download quotas */
const SIGNED_URL_LIMIT_HOUR = 50;
const SIGNED_URL_LIMIT_DAY = 200;

/** Auto-block thresholds */
const DELETE_BLOCK_THRESHOLD = 15;   // deletes in 5 min
const DELETE_BLOCK_DURATION = '10 minutes';
const DOWNLOAD_BLOCK_THRESHOLD = 300; // signed URLs in 1 hour
const DOWNLOAD_BLOCK_DURATION = '30 minutes';

@Injectable()
export class UploadService implements OnModuleInit {
  private readonly log = new Logger(UploadService.name);
  private readonly s3: S3Client;
  private readonly bucket = process.env.MINIO_BUCKET || 'aurix';
  private readonly endpoint = process.env.MINIO_ENDPOINT || 'http://localhost:9000';
  private readonly publicBase = process.env.APP_URL
    ? `${process.env.APP_URL}/storage`
    : 'http://localhost:9000/aurix';

  constructor(@Inject(PG_POOL) private readonly pool: Pool) {
    this.s3 = new S3Client({
      endpoint: this.endpoint,
      region: 'us-east-1',
      forcePathStyle: true,
      credentials: {
        accessKeyId: process.env.MINIO_ACCESS_KEY || '',
        secretAccessKey: process.env.MINIO_SECRET_KEY || '',
      },
    });
    this.log.log('S3/MinIO client initialized');
  }

  onModuleInit() {
    const HOUR = 60 * 60 * 1000;
    setInterval(() => {
      this.purgeExpired().catch((e) => this.log.error(`Purge failed: ${e}`));
    }, HOUR);
    this.log.log('File purge job scheduled (every 1h)');
  }

  // ═══════════════════════════════════════════════════════
  //  SIGNED URLS — folder-aware TTL, quotas, logging
  // ═══════════════════════════════════════════════════════

  /** Generate presigned URL with folder-appropriate TTL. */
  async createSignedUrl(
    key: string,
    userId: string,
    opts?: { ip?: string; userAgent?: string },
  ): Promise<{ url: string; expires_in: number }> {
    const folder = key.split('/')[0];
    const limits = FOLDER_TTL[folder] ?? FOLDER_TTL.covers;
    const ttl = limits.default;

    const command = new GetObjectCommand({ Bucket: this.bucket, Key: key });
    const url = await getSignedUrl(this.s3, command, { expiresIn: ttl });

    // Log access for quota tracking
    await this.pool.query(
      `INSERT INTO signed_url_log (user_id, file_key, folder, ip, user_agent)
       VALUES ($1, $2, $3, $4::inet, $5)`,
      [userId, key, folder, opts?.ip ?? null, opts?.userAgent ?? null],
    ).catch((e) => this.log.error(`signed_url_log write failed: ${e}`));

    return { url, expires_in: ttl };
  }

  /**
   * Стримит файл из S3/MinIO напрямую в Express Response с корректными
   * Content-Type и Content-Disposition: attachment.
   */
  async streamDownload(
    key: string,
    filename: string,
    res: any,
    opts?: { ip?: string; userAgent?: string; adminId?: string },
  ): Promise<void> {
    const mime = this.guessMimeType(key);
    const asciiSafe = filename.replace(/[^\x20-\x7E]/g, '_').replace(/"/g, '');
    const disposition = `attachment; filename="${asciiSafe}"; filename*=UTF-8''${encodeURIComponent(filename)}`;

    const command = new GetObjectCommand({ Bucket: this.bucket, Key: key });
    const obj = await this.s3.send(command);

    res.setHeader('Content-Type', mime);
    res.setHeader('Content-Disposition', disposition);
    if (obj.ContentLength) res.setHeader('Content-Length', String(obj.ContentLength));
    res.setHeader('Cache-Control', 'private, no-store');

    // Логируем скачивание (не блокирующе)
    this.pool.query(
      `INSERT INTO signed_url_log (user_id, file_key, folder, ip, user_agent)
       VALUES ($1, $2, $3, $4::inet, $5)`,
      [opts?.adminId ?? null, key, key.split('/')[0], opts?.ip ?? null, opts?.userAgent ?? null],
    ).catch(() => {});

    const body: any = obj.Body;
    if (body && typeof body.pipe === 'function') {
      body.pipe(res);
      return new Promise((resolve, reject) => {
        body.on('end', resolve);
        body.on('error', reject);
      });
    }
    // Fallback: буферизуем (на случай если SDK вернул buffer)
    const buf = await obj.Body?.transformToByteArray();
    if (buf) res.end(Buffer.from(buf));
    else res.end();
  }

  /** Догадка MIME-типа по расширению ключа. */
  private guessMimeType(key: string): string {
    const ext = key.split('.').pop()?.toLowerCase() || '';
    switch (ext) {
      case 'wav': return 'audio/wav';
      case 'mp3': return 'audio/mpeg';
      case 'flac': return 'audio/flac';
      case 'aac': case 'm4a': return 'audio/aac';
      case 'ogg': case 'oga': return 'audio/ogg';
      case 'png': return 'image/png';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'webp': return 'image/webp';
      case 'gif': return 'image/gif';
      default: return 'application/octet-stream';
    }
  }

  /** Безопасное имя файла для скачивания. */
  sanitizeDownloadFilename(raw: string | undefined, key: string): string {
    const ext = key.split('.').pop()?.toLowerCase() || 'bin';
    const cleaned = (raw || '').trim()
      .replace(/[\/\\:*?"<>|]/g, '_')
      .replace(/\s+/g, ' ')
      .slice(0, 180);
    if (!cleaned) return `download.${ext}`;
    // Если имя не оканчивается на расширение — добавим
    if (!/\.[a-zA-Z0-9]{2,5}$/.test(cleaned)) return `${cleaned}.${ext}`;
    return cleaned;
  }

  /** Resolve key → signed URL for API responses. Null-safe. */
  async resolveUrl(
    key: string | null | undefined,
    userId?: string,
  ): Promise<string | null> {
    if (!key) return null;
    try {
      const folder = key.split('/')[0];
      const ttl = (FOLDER_TTL[folder] ?? FOLDER_TTL.covers).default;
      const cmd = new GetObjectCommand({ Bucket: this.bucket, Key: key });
      return await getSignedUrl(this.s3, cmd, { expiresIn: ttl });
    } catch {
      return null;
    }
  }

  // ── Download quotas ───────────────────────────────────

  /** Returns { hourly, daily } counts and whether either is exceeded. */
  async getDownloadQuota(userId: string): Promise<{
    hourly: number;
    daily: number;
    blocked: boolean;
  }> {
    const { rows } = await this.pool.query(
      `SELECT
         count(*) FILTER (WHERE created_at > now() - interval '1 hour')::int AS hourly,
         count(*) FILTER (WHERE created_at > now() - interval '1 day')::int  AS daily
       FROM signed_url_log
       WHERE user_id = $1 AND created_at > now() - interval '1 day'`,
      [userId],
    );
    const hourly = rows[0]?.hourly ?? 0;
    const daily = rows[0]?.daily ?? 0;
    return {
      hourly,
      daily,
      blocked: hourly >= SIGNED_URL_LIMIT_HOUR || daily >= SIGNED_URL_LIMIT_DAY,
    };
  }

  /** True if user's file access is temporarily restricted. */
  async isFileAccessBlocked(userId: string): Promise<boolean> {
    const { rows } = await this.pool.query(
      `SELECT file_access_blocked_until FROM profiles WHERE user_id = $1`,
      [userId],
    );
    const until = rows[0]?.file_access_blocked_until;
    return until ? new Date(until) > new Date() : false;
  }

  /** Check and auto-restrict if download volume is extreme. */
  async checkDownloadAbuse(userId: string, ip?: string): Promise<boolean> {
    const { hourly } = await this.getDownloadQuota(userId);
    if (hourly >= DOWNLOAD_BLOCK_THRESHOLD) {
      await this.pool.query(
        `UPDATE profiles SET file_access_blocked_until = now() + interval '${DOWNLOAD_BLOCK_DURATION}' WHERE user_id = $1`,
        [userId],
      );
      await this.logSecurity(userId, 'auto_block_download', null, 'critical', {
        downloads_1h: hourly,
        blocked_for: DOWNLOAD_BLOCK_DURATION,
        ip,
      });
      return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════
  //  DEVICE TRACKING
  // ═══════════════════════════════════════════════════════

  /** Record or update a device fingerprint for a user. */
  async trackDevice(
    userId: string,
    ip: string,
    userAgent?: string,
    fingerprint?: string,
  ): Promise<{ isNew: boolean; isSuspicious: boolean }> {
    const fp = fingerprint ?? `${ip}|${(userAgent ?? '').slice(0, 100)}`;

    const { rows } = await this.pool.query(
      `INSERT INTO user_devices (user_id, ip, user_agent, fingerprint)
       VALUES ($1, $2::inet, $3, $4)
       ON CONFLICT (user_id, ip, fingerprint) DO UPDATE
         SET last_seen = now(), user_agent = EXCLUDED.user_agent
       RETURNING (xmax = 0) AS is_new, is_suspicious`,
      [userId, ip, userAgent ?? null, fp],
    );
    const isNew = rows[0]?.is_new ?? true;
    const isSuspicious = rows[0]?.is_suspicious ?? false;

    // New device → check if user has too many devices
    if (isNew) {
      const { rows: cnt } = await this.pool.query(
        `SELECT count(*)::int AS c FROM user_devices WHERE user_id = $1`,
        [userId],
      );
      if ((cnt[0]?.c ?? 0) > 10) {
        await this.logSecurity(userId, 'many_devices', null, 'high', {
          device_count: cnt[0].c,
          new_ip: ip,
        });
      }
    }

    return { isNew, isSuspicious };
  }

  /** Mark a device as suspicious. */
  async flagDevice(
    userId: string,
    ip: string,
    fingerprint: string,
    note?: string,
  ): Promise<void> {
    await this.pool.query(
      `UPDATE user_devices SET is_suspicious = true, note = $4
       WHERE user_id = $1 AND ip = $2::inet AND fingerprint = $3`,
      [userId, ip, fingerprint, note ?? null],
    );
  }

  // ═══════════════════════════════════════════════════════
  //  UPLOAD
  // ═══════════════════════════════════════════════════════

  async uploadFile(
    file: Express.Multer.File,
    folder: Folder,
    userId: string,
    entity?: { type: EntityType; id: string },
  ): Promise<{ key: string; url: string }> {
    const ext = path.extname(file.originalname) || this.guessExt(file.mimetype);
    const key = `${folder}/${randomUUID()}${ext.replace(/[^a-zA-Z0-9.]/g, '')}`;

    await this.s3.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: file.buffer,
        ContentType: file.mimetype,
      }),
    );

    await this.pool.query(
      `INSERT INTO uploaded_files
         (user_id, file_key, folder, mime_type, size_bytes, entity_type, entity_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (file_key) DO NOTHING`,
      [userId, key, folder, file.mimetype, file.buffer.length,
       entity?.type ?? null, entity?.id ?? null],
    );

    await this.logSecurity(userId, 'file_upload', key, 'low', {
      folder, size: file.buffer.length,
    });

    return { key, url: `${this.publicBase}/${key}` };
  }

  async linkEntity(key: string, entityType: EntityType, entityId: string): Promise<void> {
    await this.pool.query(
      `UPDATE uploaded_files SET entity_type = $1, entity_id = $2 WHERE file_key = $3`,
      [entityType, entityId, key],
    );
  }

  // ═══════════════════════════════════════════════════════
  //  VALIDATION & OWNERSHIP
  // ═══════════════════════════════════════════════════════

  validateKey(key: string): boolean {
    if (!key || key.includes('..') || key.startsWith('/')) return false;
    return SAFE_KEY_RE.test(key);
  }

  async isOwnedByUser(key: string, userId: string): Promise<boolean> {
    const { rowCount } = await this.pool.query(
      `SELECT 1 FROM uploaded_files WHERE file_key = $1 AND user_id = $2 LIMIT 1`,
      [key, userId],
    );
    return (rowCount ?? 0) > 0;
  }

  // ═══════════════════════════════════════════════════════
  //  DELETE RATE LIMITING & AUTO-BLOCK
  // ═══════════════════════════════════════════════════════

  async isDeletionRateLimited(userId: string): Promise<boolean> {
    const { rows } = await this.pool.query(
      `SELECT count(*)::int AS cnt FROM deleted_files
       WHERE user_id = $1 AND deleted_at > now() - interval '1 minute'`,
      [userId],
    );
    return (rows[0]?.cnt ?? 0) >= 20;
  }

  async isDeleteBlocked(userId: string): Promise<boolean> {
    const { rows } = await this.pool.query(
      `SELECT delete_blocked_until FROM profiles WHERE user_id = $1`,
      [userId],
    );
    const until = rows[0]?.delete_blocked_until;
    return until ? new Date(until) > new Date() : false;
  }

  async checkAndAutoBlock(userId: string, ip?: string): Promise<boolean> {
    const { rows } = await this.pool.query(
      `SELECT count(*)::int AS cnt FROM deleted_files
       WHERE user_id = $1 AND deleted_at > now() - interval '5 minutes'`,
      [userId],
    );
    const cnt = rows[0]?.cnt ?? 0;

    if (cnt > DELETE_BLOCK_THRESHOLD) {
      await this.pool.query(
        `UPDATE profiles SET delete_blocked_until = now() + interval '${DELETE_BLOCK_DURATION}' WHERE user_id = $1`,
        [userId],
      );
      await this.logSecurity(userId, 'auto_block_delete', null, 'critical', {
        deletions_5min: cnt, blocked_for: DELETE_BLOCK_DURATION, ip,
      });
      this.log.warn(JSON.stringify({ alert: 'AUTO_BLOCK_DELETE', userId, cnt, ip }));
      return true;
    }
    if (cnt > 10) {
      await this.logSecurity(userId, 'suspicious_bulk_delete', null, 'high', {
        deletions_5min: cnt, ip,
      });
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════
  //  SOFT DELETE & SAFE PURGE
  // ═══════════════════════════════════════════════════════

  async softDelete(key: string, userId: string): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query(
        `SELECT folder FROM uploaded_files WHERE file_key = $1 AND user_id = $2`,
        [key, userId],
      );
      const folder = rows[0]?.folder ?? key.split('/')[0];

      await client.query(
        `INSERT INTO deleted_files (user_id, file_key, folder) VALUES ($1, $2, $3)`,
        [userId, key, folder],
      );
      await client.query(
        `DELETE FROM uploaded_files WHERE file_key = $1 AND user_id = $2`,
        [key, userId],
      );
      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
    this.log.log(JSON.stringify({ action: 'soft_delete', userId, key }));
  }

  async isFileInActiveUse(key: string): Promise<boolean> {
    const { rowCount: c1 } = await this.pool.query(
      `SELECT 1 FROM releases WHERE cover_url LIKE '%' || $1 LIMIT 1`, [key],
    );
    if ((c1 ?? 0) > 0) return true;
    const { rowCount: c2 } = await this.pool.query(
      `SELECT 1 FROM tracks WHERE audio_url LIKE '%' || $1 LIMIT 1`, [key],
    );
    if ((c2 ?? 0) > 0) return true;
    const { rowCount: c3 } = await this.pool.query(
      `SELECT 1 FROM uploaded_files WHERE file_key = $1 LIMIT 1`, [key],
    );
    return (c3 ?? 0) > 0;
  }

  async purgeExpired(): Promise<number> {
    const { rows } = await this.pool.query(
      `SELECT id, file_key FROM deleted_files
       WHERE NOT purged AND purge_after <= now()
       ORDER BY purge_after ASC LIMIT 100`,
    );

    let purged = 0;
    for (const row of rows) {
      if (await this.isFileInActiveUse(row.file_key)) {
        this.log.warn(`Purge skipped — still in use: ${row.file_key}`);
        await this.pool.query(
          `UPDATE deleted_files SET purge_after = now() + interval '24 hours' WHERE id = $1`,
          [row.id],
        );
        continue;
      }
      try {
        await this.s3.send(
          new DeleteObjectCommand({ Bucket: this.bucket, Key: row.file_key }),
        );
      } catch (e) {
        this.log.warn(`S3 purge failed for ${row.file_key}: ${e}`);
      }
      await this.pool.query(
        `UPDATE deleted_files SET purged = true WHERE id = $1`, [row.id],
      );
      purged++;
    }
    if (purged > 0) this.log.log(`Purged ${purged} expired files from S3`);
    return purged;
  }

  // ═══════════════════════════════════════════════════════
  //  SECURITY AUDIT LOG
  // ═══════════════════════════════════════════════════════

  async logSecurity(
    userId: string | null,
    action: string,
    resource: string | null,
    riskLevel: RiskLevel,
    detail?: Record<string, any>,
    ip?: string,
  ): Promise<void> {
    try {
      await this.pool.query(
        `INSERT INTO security_logs (user_id, ip, action, resource, risk_level, detail)
         VALUES ($1, $2::inet, $3, $4, $5, $6)`,
        [userId, ip ?? null, action, resource, riskLevel,
         detail ? JSON.stringify(detail) : null],
      );
    } catch (e) {
      this.log.error(`security_log write failed: ${e}`);
    }
  }

  // ═══════════════════════════════════════════════════════
  //  LEGACY / INTERNAL
  // ═══════════════════════════════════════════════════════

  async deleteFileFromS3(key: string): Promise<void> {
    try {
      await this.s3.send(
        new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
      );
    } catch (e) {
      this.log.warn(`S3 delete failed: ${key}: ${e}`);
    }
  }

  private guessExt(mime: string): string {
    if (mime.startsWith('image/')) return '.jpg';
    if (mime.startsWith('audio/')) return '.mp3';
    return '';
  }
}
