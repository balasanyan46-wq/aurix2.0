import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Pool } from 'pg';
import axios from 'axios';

/**
 * Global exception filter — catches all errors, logs to DB, sends Telegram alerts.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('ExceptionFilter');
  private readonly tgToken = process.env.TELEGRAM_BOT_TOKEN || '';
  private readonly tgChatId = process.env.TELEGRAM_CHAT_ID || '';
  private lastTgAlert = 0; // Rate limit: max 1 alert per 30s
  private errorCounts = new Map<number, number>(); // Track error frequency
  private lastCountReset = Date.now();

  constructor(private readonly pool: Pool) {}

  catch(exception: unknown, host: ArgumentsHost) {
    // WebSocket errors
    if (host.getType() === 'ws') {
      this.logger.error(
        `WS error: ${exception instanceof Error ? exception.message : String(exception)}`,
        exception instanceof Error ? exception.stack : undefined,
      );
      return;
    }

    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();
    const startTime = (req as any)._startTime || Date.now();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';
    let details: any = undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const body = exception.getResponse();
      if (typeof body === 'string') {
        message = body;
      } else if (typeof body === 'object' && body !== null) {
        message = (body as any).message || (body as any).error || message;
        details = (body as any).details;
      }
    } else if (exception instanceof Error) {
      message = exception.message;
      if ((exception as any).code === '23505') { status = HttpStatus.CONFLICT; message = 'Duplicate entry'; }
      else if ((exception as any).code === '23503') { status = HttpStatus.BAD_REQUEST; message = 'Referenced record not found'; }
      else if ((exception as any).code === '42P01') { status = HttpStatus.INTERNAL_SERVER_ERROR; message = 'Database table not found'; }
    }

    // Log 4xx and 5xx to console
    if (status >= 400) {
      this.logger.error(`${req.method} ${req.url} → ${status}: ${message}`);
    }

    // Save errors to DB + alert on 5xx
    if (status >= 400) {
      this.saveErrorLog(req, status, message, exception, startTime).catch(() => {});
    }
    if (status >= 500) {
      this.sendTelegramAlert(req, status, message).catch(() => {});
    }

    // Track 4xx frequency — alert if spike detected
    if (status >= 400 && status < 500 && status !== 401 && status !== 404) {
      this.trackErrorSpike(req, status, message);
    }

    res.status(status).json({
      statusCode: status,
      message: Array.isArray(message) ? message : String(message),
      ...(details ? { details } : {}),
      timestamp: new Date().toISOString(),
      path: req.url,
    });
  }

  private async saveErrorLog(
    req: Request,
    status: number,
    message: string,
    exception: unknown,
    startTime: number,
  ) {
    try {
      const stack = exception instanceof Error ? exception.stack?.slice(0, 2000) : null;
      const userId = (req as any).user?.id || null;
      const duration = Date.now() - startTime;

      // Don't log common expected errors (auth, validation, not found)
      if (status === 401 || status === 404) return;

      await this.pool.query(
        `INSERT INTO error_logs (path, method, status_code, error_message, error_stack, user_id, ip, user_agent, request_body, duration_ms, service)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'api')`,
        [
          req.url?.slice(0, 500),
          req.method,
          status,
          String(message).slice(0, 1000),
          stack,
          userId ? String(userId) : null,
          req.ip || req.headers['x-real-ip'] || null,
          req.headers['user-agent']?.slice(0, 500) || null,
          req.body && Object.keys(req.body).length > 0
            ? JSON.stringify(this.redactSensitive(req.body)).slice(0, 2000)
            : null,
          duration,
        ],
      );
    } catch {
      // Silently fail — don't cause cascading errors
    }
  }

  private redactSensitive(body: any): any {
    if (!body || typeof body !== 'object') return body;
    const redacted = { ...body };
    const sensitiveKeys = ['password', 'token', 'secret', 'refreshToken', 'refresh_token', 'accessToken', 'access_token', 'creditCard', 'card_number', 'cvv'];
    for (const key of sensitiveKeys) {
      if (key in redacted) redacted[key] = '[REDACTED]';
    }
    return redacted;
  }

  private trackErrorSpike(req: Request, status: number, message: string) {
    // Reset counts every 5 minutes
    const now = Date.now();
    if (now - this.lastCountReset > 300_000) {
      this.errorCounts.clear();
      this.lastCountReset = now;
    }
    const count = (this.errorCounts.get(status) || 0) + 1;
    this.errorCounts.set(status, count);

    // Alert if 5+ same status errors in 5 min window
    if (count === 5) {
      this.sendTelegramAlert(req, status, `⚠️ Spike: ${count}x ${status} errors in 5 min. Latest: ${message}`, true).catch(() => {});
    }
  }

  private async sendTelegramAlert(req: Request, status: number, message: string, force = false) {
    const gwUrl = process.env.AI_GATEWAY_URL;
    const gwSecret = process.env.AI_GATEWAY_SECRET;
    if (!gwUrl) return;

    // Rate limit: 1 alert per 30 seconds (unless forced)
    const now = Date.now();
    if (!force && now - this.lastTgAlert < 30_000) return;
    this.lastTgAlert = now;

    const text = [
      `🔴 *AURIX Error ${status}*`,
      `\`${req.method} ${req.url?.slice(0, 80)}\``,
      `${message.slice(0, 200)}`,
      `🕐 ${new Date().toLocaleTimeString('ru-RU', { timeZone: 'Europe/Moscow' })}`,
    ].join('\n');

    try {
      await axios.post(`${gwUrl}/telegram/send`, { text, parse_mode: 'Markdown' }, {
        headers: { 'X-Gateway-Secret': gwSecret || '', 'Content-Type': 'application/json' },
        timeout: 10000,
      });
    } catch {}
  }
}
