import { Injectable, Inject } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Pool } from 'pg';
import * as crypto from 'crypto';
import { UsersService, UserRow } from '../users/users.service';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class AuthService {
  constructor(
    private readonly jwtService: JwtService,
    private readonly usersService: UsersService,
    @Inject(PG_POOL) private readonly pool: Pool,
  ) {}

  /** Short-lived access token (15 min). */
  generateToken(user: Pick<UserRow, 'id' | 'email' | 'role'>): string {
    return this.jwtService.sign({
      id: user.id,
      email: user.email,
      role: user.role,
    });
  }

  /** Long-lived opaque refresh token (90 days). Stored hashed in DB. */
  async createRefreshToken(
    userId: number,
    userAgent?: string,
  ): Promise<string> {
    const raw = crypto.randomBytes(48).toString('base64url');
    const hash = crypto.createHash('sha256').update(raw).digest('hex');
    const expiresAt = new Date(Date.now() + 90 * 24 * 60 * 60 * 1000); // 90 days

    await this.pool.query(
      `INSERT INTO refresh_tokens (user_id, token_hash, expires_at, user_agent)
       VALUES ($1, $2, $3, $4)`,
      [userId, hash, expiresAt, userAgent || null],
    );

    return raw;
  }

  /** Validate refresh token, return user if valid. */
  async validateRefreshToken(
    rawToken: string,
  ): Promise<UserRow | null> {
    const hash = crypto.createHash('sha256').update(rawToken).digest('hex');

    const { rows } = await this.pool.query(
      `SELECT user_id, expires_at
       FROM refresh_tokens
       WHERE token_hash = $1`,
      [hash],
    );

    if (!rows[0]) return null;

    const { user_id, expires_at } = rows[0];

    if (new Date() > new Date(expires_at)) {
      // Clean up expired token
      await this.pool.query(
        `DELETE FROM refresh_tokens WHERE token_hash = $1`,
        [hash],
      );
      return null;
    }

    return this.usersService.findById(user_id);
  }

  /** Rotate: revoke old token, issue new one (prevents reuse). */
  async rotateRefreshToken(
    oldRawToken: string,
    userId: number,
    userAgent?: string,
  ): Promise<string> {
    const oldHash = crypto
      .createHash('sha256')
      .update(oldRawToken)
      .digest('hex');

    // Revoke old
    await this.pool.query(
      `DELETE FROM refresh_tokens WHERE token_hash = $1`,
      [oldHash],
    );

    // Issue new
    return this.createRefreshToken(userId, userAgent);
  }

  /** Revoke a single refresh token (logout from one device). */
  async revokeRefreshToken(rawToken: string): Promise<void> {
    const hash = crypto.createHash('sha256').update(rawToken).digest('hex');
    await this.pool.query(
      `DELETE FROM refresh_tokens WHERE token_hash = $1`,
      [hash],
    );
  }

  /** Revoke ALL refresh tokens for a user (logout everywhere / password change). */
  async revokeAllTokens(userId: number): Promise<void> {
    await this.pool.query(
      `DELETE FROM refresh_tokens WHERE user_id = $1`,
      [userId],
    );
  }

  async validateUser(
    email: string,
    password: string,
  ): Promise<UserRow | null> {
    const user = await this.usersService.findByEmail(email);
    if (!user) return null;

    const valid = await this.usersService.verifyPassword(
      password,
      user.password,
    );
    if (!valid) return null;

    return user;
  }
}
