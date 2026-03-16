import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Inject,
} from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class AdminGuard implements CanActivate {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const userId = request.user?.id;

    if (!userId) {
      throw new ForbiddenException('authentication required');
    }

    // Always verify role from DB, never trust JWT claim alone
    const { rows } = await this.pool.query(
      `SELECT role FROM users WHERE id = $1`,
      [userId],
    );

    if (!rows[0] || rows[0].role !== 'admin') {
      throw new ForbiddenException('admin access required');
    }

    return true;
  }
}
