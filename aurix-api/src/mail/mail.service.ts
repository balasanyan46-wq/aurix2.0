import { Injectable, Logger } from '@nestjs/common';
import * as nodemailer from 'nodemailer';
import { MAILER_CONFIG } from './mailer.config';
import { buildVerifyEmailTemplate } from './templates/verify-email.template';
import { buildWelcomeTemplate } from './templates/welcome.template';
import { buildResetPasswordTemplate } from './templates/reset-password.template';
import { buildReleaseApprovedTemplate } from './templates/release-approved.template';
import { buildReleaseLiveTemplate } from './templates/release-live.template';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter;

  constructor() {
    const cfg = MAILER_CONFIG.smtp;
    this.transporter = nodemailer.createTransport({
      host: cfg.host,
      port: cfg.port,
      secure: cfg.secure,
      auth: { user: cfg.user, pass: cfg.pass },
    });

    this.logger.log(
      `SMTP transporter → ${cfg.host}:${cfg.port} (secure=${cfg.secure})`,
    );
  }

  private async send(to: string, subject: string, html: string) {
    await this.transporter.sendMail({
      from: MAILER_CONFIG.from,
      to,
      subject,
      html,
    });
  }

  // ───── 1. Verify email ─────

  async sendVerifyEmail(email: string, token: string): Promise<void> {
    const verifyUrl = `${MAILER_CONFIG.appUrl}/auth/verify-email?token=${token}`;
    await this.send(
      email,
      'Подтвердите email — AURIX',
      buildVerifyEmailTemplate(verifyUrl),
    );
    this.logger.log(`[verify-email] → ${email}`);
  }

  // ───── 2. Welcome (after verification) ─────

  async sendWelcomeEmail(email: string, name: string | null): Promise<void> {
    const loginUrl = MAILER_CONFIG.appUrl;
    await this.send(
      email,
      'Добро пожаловать в AURIX! 🎵',
      buildWelcomeTemplate(name, loginUrl),
    );
    this.logger.log(`[welcome] → ${email}`);
  }

  // ───── 3. Reset password ─────

  async sendResetPasswordEmail(email: string, token: string): Promise<void> {
    const resetUrl = `${MAILER_CONFIG.appUrl}/auth/reset-password?token=${token}`;
    await this.send(
      email,
      'Сброс пароля — AURIX',
      buildResetPasswordTemplate(resetUrl),
    );
    this.logger.log(`[reset-password] → ${email}`);
  }

  // ───── 4. Release approved ─────

  async sendReleaseApproved(
    email: string,
    artistName: string,
    releaseTitle: string,
  ): Promise<void> {
    await this.send(
      email,
      `Релиз «${releaseTitle}» одобрен — AURIX`,
      buildReleaseApprovedTemplate({ artistName, releaseTitle }),
    );
    this.logger.log(`[release-approved] "${releaseTitle}" → ${email}`);
  }

  // ───── 5. Release live ─────

  async sendReleaseLive(
    email: string,
    artistName: string,
    releaseTitle: string,
  ): Promise<void> {
    await this.send(
      email,
      `🚀 «${releaseTitle}» на площадках — AURIX`,
      buildReleaseLiveTemplate({ artistName, releaseTitle }),
    );
    this.logger.log(`[release-live] "${releaseTitle}" → ${email}`);
  }
}
