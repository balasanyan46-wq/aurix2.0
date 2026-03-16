import { Injectable, Logger } from '@nestjs/common';
import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { randomUUID } from 'crypto';
import * as path from 'path';

@Injectable()
export class UploadService {
  private readonly logger = new Logger(UploadService.name);
  private readonly s3: S3Client;
  private readonly bucket = process.env.MINIO_BUCKET || 'aurix';
  private readonly endpoint = process.env.MINIO_ENDPOINT || 'http://localhost:9000';
  // Public URL base for returned file URLs (proxied via nginx /storage/)
  private readonly publicBase = process.env.APP_URL
    ? `${process.env.APP_URL}/storage`
    : 'http://localhost:9000/aurix';

  constructor() {
    this.s3 = new S3Client({
      endpoint: this.endpoint,
      region: 'us-east-1',
      forcePathStyle: true,
      credentials: {
        accessKeyId: process.env.MINIO_ACCESS_KEY || '',
        secretAccessKey: process.env.MINIO_SECRET_KEY || '',
      },
    });
    this.logger.log('S3/MinIO client initialized');
  }

  async uploadFile(
    file: Express.Multer.File,
    folder: 'covers' | 'tracks' | 'production',
  ): Promise<string> {
    const ext = path.extname(file.originalname) || this.guessExt(file.mimetype);
    // Sanitize filename — only allow safe characters
    const key = `${folder}/${randomUUID()}${ext.replace(/[^a-zA-Z0-9.]/g, '')}`;

    await this.s3.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: file.buffer,
        ContentType: file.mimetype,
      }),
    );

    return `${this.publicBase}/${key}`;
  }

  async deleteFile(key: string): Promise<void> {
    try {
      await this.s3.send(
        new DeleteObjectCommand({
          Bucket: this.bucket,
          Key: key,
        }),
      );
    } catch (e) {
      this.logger.warn(`Failed to delete ${key}: ${e}`);
    }
  }

  private guessExt(mime: string): string {
    if (mime.startsWith('image/')) return '.jpg';
    if (mime.startsWith('audio/')) return '.mp3';
    return '';
  }
}
