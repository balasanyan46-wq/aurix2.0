import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { PG_POOL } from '../database/database.module';

export interface UserRow {
  id: number;
  email: string;
  name: string | null;
  role: string;
  verified: boolean;
  created_at: Date;
}

@Injectable()
export class UsersService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  // ───── Registration ─────

  async createUser(
    email: string,
    password: string,
    name?: string,
    phone?: string,
  ): Promise<UserRow & { verification_token: string }> {
    const hash = await bcrypt.hash(password, 12);
    const token = crypto.randomBytes(32).toString('hex');
    const { rows } = await this.pool.query(
      `INSERT INTO users (email, password, name, phone, verification_token, verified)
       VALUES ($1, $2, $3, $4, $5, false)
       RETURNING id, email, name, phone, role, verified, verification_token, created_at`,
      [email, hash, name || null, phone || null, token],
    );
    return rows[0];
  }

  // ───── Lookup ─────

  async findByEmail(
    email: string,
  ): Promise<(UserRow & { password: string }) | null> {
    const { rows } = await this.pool.query(
      `SELECT id, email, password, name, role, verified, created_at
       FROM users WHERE email = $1`,
      [email],
    );
    return rows[0] || null;
  }

  async findById(id: number): Promise<UserRow | null> {
    const { rows } = await this.pool.query(
      `SELECT id, email, name, phone, role, verified, created_at
       FROM users WHERE id = $1`,
      [id],
    );
    return rows[0] || null;
  }

  // ───── Email verification ─────

  async findByVerificationToken(token: string): Promise<UserRow | null> {
    const { rows } = await this.pool.query(
      `SELECT id, email, name, role, verified, created_at
       FROM users WHERE verification_token = $1`,
      [token],
    );
    return rows[0] || null;
  }

  async markEmailVerified(userId: number): Promise<void> {
    await this.pool.query(
      `UPDATE users SET verified = true, verification_token = NULL WHERE id = $1`,
      [userId],
    );
  }

  // ───── Password reset ─────

  async setResetToken(userId: number): Promise<string> {
    const token = crypto.randomBytes(32).toString('hex');
    const expires = new Date(Date.now() + 60 * 60 * 1000); // +1 hour
    await this.pool.query(
      `UPDATE users SET reset_token = $1, reset_token_expires = $2 WHERE id = $3`,
      [token, expires, userId],
    );
    return token;
  }

  async findByResetToken(
    token: string,
  ): Promise<(UserRow & { reset_token_expires: Date }) | null> {
    const { rows } = await this.pool.query(
      `SELECT id, email, name, role, verified, reset_token_expires, created_at
       FROM users WHERE reset_token = $1`,
      [token],
    );
    return rows[0] || null;
  }

  async resetPassword(userId: number, newPassword: string): Promise<void> {
    const hash = await bcrypt.hash(newPassword, 10);
    await this.pool.query(
      `UPDATE users SET password = $1, reset_token = NULL, reset_token_expires = NULL WHERE id = $2`,
      [hash, userId],
    );
  }

  // ───── Password check ─────

  async verifyPassword(plain: string, hash: string): Promise<boolean> {
    return bcrypt.compare(plain, hash);
  }
}
