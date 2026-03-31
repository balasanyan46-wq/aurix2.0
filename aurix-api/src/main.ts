import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { Logger, ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './all-exceptions.filter';

async function bootstrap() {
  const logger = new Logger('Bootstrap');

  // ── Validate critical env vars ──────────────────────────
  const required = ['JWT_SECRET', 'PG_PASSWORD', 'SMTP_USER', 'SMTP_PASS', 'EDEN_AI_API_KEY'];
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
        callback(new Error(`Origin ${origin} not allowed by CORS`));
      }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });

  // ── Global exception filter (always JSON, never HTML) ──
  app.useGlobalFilters(new AllExceptionsFilter());

  // ── Global validation pipe ─────────────────────────────
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,        // Strip unknown properties
      forbidNonWhitelisted: false, // Don't throw on extra props (backwards compat)
      transform: true,        // Auto-transform payloads to DTO instances
    }),
  );

  const port = Number(process.env.PORT) || 3000;
  await app.listen(port, '0.0.0.0');
  logger.log(`AURIX API running on port ${port}`);
}
bootstrap();
