import { Injectable, Logger } from '@nestjs/common';
import * as nodemailer from 'nodemailer';
import { MAILER_CONFIG } from './mailer.config';
import { buildVerifyEmailTemplate } from './templates/verify-email.template';
import { buildWelcomeTemplate } from './templates/welcome.template';
import { buildResetPasswordTemplate } from './templates/reset-password.template';
import { buildReleaseApprovedTemplate } from './templates/release-approved.template';
import { buildReleaseLiveTemplate } from './templates/release-live.template';
import { buildTicketReplyTemplate } from './templates/ticket-reply.template';
import { buildReleaseRevisionTemplate } from './templates/release-revision.template';
import { buildReleaseRejectedTemplate } from './templates/release-rejected.template';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter;

  constructor() {
    const cfg = MAILER_CONFIG.smtp;

    this.logger.log(
      `SMTP config: host=${cfg.host} port=${cfg.port} secure=${cfg.secure} user=${cfg.user ? cfg.user.slice(0, 4) + '***' : 'MISSING'}`,
    );

    if (!cfg.user || !cfg.pass) {
      this.logger.error('SMTP_USER or SMTP_PASS is missing — emails will NOT be sent');
    }

    this.transporter = nodemailer.createTransport({
      host: cfg.host,
      port: cfg.port,
      secure: cfg.secure,
      auth: { user: cfg.user, pass: cfg.pass },
      connectionTimeout: 10000,
      greetingTimeout: 10000,
      socketTimeout: 15000,
    });
  }

  private async send(to: string, subject: string, html: string): Promise<{ success: boolean; messageId?: string; error?: string }> {
    const from = MAILER_CONFIG.from;
    this.logger.log(`[send] to=${to} subject="${subject}" from=${from}`);

    try {
      const info = await this.transporter.sendMail({ from, to, subject, html });
      this.logger.log(`[send] OK messageId=${info.messageId} response="${info.response}"`);
      return { success: true, messageId: info.messageId };
    } catch (err: any) {
      this.logger.error(`[send] FAILED to=${to} error=${err.message}`, err.stack);
      return { success: false, error: err.message };
    }
  }

  // ───── 1. Verify email ─────

  async sendVerifyEmail(email: string, token: string): Promise<void> {
    const verifyUrl = `${MAILER_CONFIG.appUrl}/auth/verify-email?token=${token}`;
    const result = await this.send(
      email,
      'Подтвердите email — AURIX',
      buildVerifyEmailTemplate(verifyUrl),
    );
    if (!result.success) {
      this.logger.error(`[verify-email] Failed for ${email}: ${result.error}`);
      throw new Error(`Email delivery failed: ${result.error}`);
    }
    this.logger.log(`[verify-email] → ${email}`);
  }

  // ───── 2. Welcome (after verification) ─────

  async sendWelcomeEmail(email: string, name: string | null): Promise<void> {
    const loginUrl = MAILER_CONFIG.appUrl;
    const result = await this.send(
      email,
      'Добро пожаловать в AURIX!',
      buildWelcomeTemplate(name, loginUrl),
    );
    if (!result.success) {
      this.logger.error(`[welcome] Failed for ${email}: ${result.error}`);
    }
    this.logger.log(`[welcome] → ${email}`);
  }

  // ───── 3. Reset password ─────

  async sendResetPasswordEmail(email: string, token: string): Promise<void> {
    const resetUrl = `${MAILER_CONFIG.appUrl}/auth/reset-password?token=${token}`;
    this.logger.log(`[reset-password] Sending to ${email}, resetUrl=${resetUrl}`);
    const result = await this.send(
      email,
      'Сброс пароля — AURIX',
      buildResetPasswordTemplate(resetUrl),
    );
    if (!result.success) {
      this.logger.error(`[reset-password] Failed for ${email}: ${result.error}`);
      throw new Error(`Email delivery failed: ${result.error}`);
    }
    this.logger.log(`[reset-password] → ${email}`);
  }

  // ───── 4. Release approved ─────

  async sendReleaseApproved(
    email: string,
    artistName: string,
    releaseTitle: string,
  ): Promise<void> {
    const result = await this.send(
      email,
      `Релиз «${releaseTitle}» одобрен — AURIX`,
      buildReleaseApprovedTemplate({ artistName, releaseTitle }),
    );
    if (!result.success) {
      this.logger.error(`[release-approved] Failed for ${email}: ${result.error}`);
    }
    this.logger.log(`[release-approved] "${releaseTitle}" → ${email}`);
  }

  // ───── 5. Release live ─────

  async sendReleaseLive(
    email: string,
    artistName: string,
    releaseTitle: string,
  ): Promise<void> {
    const result = await this.send(
      email,
      `«${releaseTitle}» на площадках — AURIX`,
      buildReleaseLiveTemplate({ artistName, releaseTitle }),
    );
    if (!result.success) {
      this.logger.error(`[release-live] Failed for ${email}: ${result.error}`);
    }
    this.logger.log(`[release-live] "${releaseTitle}" → ${email}`);
  }

  // ───── 6. Ticket reply ─────

  async sendTicketReplyEmail(
    email: string,
    subject: string,
    replyText: string,
    ticketId: number,
  ): Promise<void> {
    const result = await this.send(
      email,
      `Ответ по обращению «${subject}» — AURIX`,
      buildTicketReplyTemplate({ subject, replyText, ticketId }),
    );
    if (!result.success) {
      this.logger.error(`[ticket-reply] Failed for ${email}: ${result.error}`);
    }
    this.logger.log(`[ticket-reply] ticket #${ticketId} → ${email}`);
  }

  // ───── 7. Release revision (needs fixes) ─────

  async sendReleaseRevision(
    email: string,
    artistName: string,
    releaseTitle: string,
    reason: string,
  ): Promise<void> {
    const result = await this.send(
      email,
      `Релиз «${releaseTitle}» — нужны исправления — AURIX`,
      buildReleaseRevisionTemplate({ artistName, releaseTitle, reason }),
    );
    if (!result.success) {
      this.logger.error(`[release-revision] Failed for ${email}: ${result.error}`);
    }
    this.logger.log(`[release-revision] "${releaseTitle}" → ${email}`);
  }

  // ───── 8. Release rejected ─────

  async sendReleaseRejected(
    email: string,
    artistName: string,
    releaseTitle: string,
    reason?: string,
  ): Promise<void> {
    const result = await this.send(
      email,
      `Релиз «${releaseTitle}» отклонён — AURIX`,
      buildReleaseRejectedTemplate({ artistName, releaseTitle, reason }),
    );
    if (!result.success) {
      this.logger.error(`[release-rejected] Failed for ${email}: ${result.error}`);
    }
    this.logger.log(`[release-rejected] "${releaseTitle}" → ${email}`);
  }

  // ───── Test: verify SMTP connection ─────

  async verifyConnection(): Promise<{ ok: boolean; error?: string }> {
    try {
      await this.transporter.verify();
      this.logger.log('[verify] SMTP connection OK');
      return { ok: true };
    } catch (err: any) {
      this.logger.error(`[verify] SMTP connection FAILED: ${err.message}`);
      return { ok: false, error: err.message };
    }
  }

  // ───── Test: send test email ─────

  async sendTestEmail(to: string): Promise<{ success: boolean; messageId?: string; error?: string }> {
    return this.send(
      to,
      'Тестовое письмо — AURIX',
      `<div style="font-family:sans-serif;padding:20px;background:#0d0d0d;color:#eee;">
        <h2 style="color:#FF6A1A;">AURIX — тест SMTP</h2>
        <p>Если вы видите это письмо, SMTP работает корректно.</p>
        <p style="color:#888;">Отправлено: ${new Date().toISOString()}</p>
      </div>`,
    );
  }
}
