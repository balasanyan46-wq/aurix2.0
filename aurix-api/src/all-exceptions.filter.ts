import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

/**
 * Global exception filter — always returns JSON, never HTML.
 * Catches every unhandled error (HttpException, DB errors, etc.).
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('ExceptionFilter');

  catch(exception: unknown, host: ArgumentsHost) {
    // SECURITY: handle WebSocket context without crashing
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
      // DB-specific errors
      if ((exception as any).code === '23505') {
        status = HttpStatus.CONFLICT;
        message = 'Duplicate entry';
      } else if ((exception as any).code === '23503') {
        status = HttpStatus.BAD_REQUEST;
        message = 'Referenced record not found';
      } else if ((exception as any).code === '42P01') {
        status = HttpStatus.INTERNAL_SERVER_ERROR;
        message = 'Database table not found';
      }
    }

    // Log 5xx errors
    if (status >= 500) {
      this.logger.error(
        `${req.method} ${req.url} → ${status}: ${message}`,
        exception instanceof Error ? exception.stack : undefined,
      );
    }

    res.status(status).json({
      statusCode: status,
      message: Array.isArray(message) ? message : String(message),
      ...(details ? { details } : {}),
      timestamp: new Date().toISOString(),
      path: req.url,
    });
  }
}
