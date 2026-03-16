import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { Logger } from '@nestjs/common';
import helmet from 'helmet';
import { AppModule } from './app.module';

async function bootstrap() {
  const logger = new Logger('Bootstrap');

  // ── Validate critical env vars ──────────────────────────
  const required = ['JWT_SECRET', 'PG_PASSWORD', 'SMTP_USER', 'SMTP_PASS'];
  const missing = required.filter((k) => !process.env[k]);
  if (missing.length > 0) {
    logger.error(`Missing required env vars: ${missing.join(', ')}`);
    process.exit(1);
  }

  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
  });

  // ── Security headers ────────────────────────────────────
  app.use(
    helmet({
      contentSecurityPolicy: false, // Flutter web needs inline scripts
      crossOriginEmbedderPolicy: false,
    }),
  );

  // ── CORS — restrict to known origins ────────────────────
  const allowedOrigins = (
    process.env.CORS_ORIGINS || 'http://localhost:3000,http://localhost:8080'
  )
    .split(',')
    .map((s) => s.trim());

  app.enableCors({
    origin: (origin, callback) => {
      // Allow requests with no origin (mobile apps, curl, etc.)
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(null, true); // TODO: set to false after domain is configured
      }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });

  const port = Number(process.env.PORT) || 3000;
  await app.listen(port, '0.0.0.0');
  logger.log(`AURIX API running on port ${port}`);
}
bootstrap();
