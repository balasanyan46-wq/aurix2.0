import { Controller, Get, Post, Put, Body, Param, Query, Req, UseGuards, HttpException, HttpStatus, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { SupportService } from './support.service';
import { NotificationsService } from '../notifications/notifications.service';
import { MailService } from '../mail/mail.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class SupportController {
  constructor(
    private readonly svc: SupportService,
    private readonly notifications: NotificationsService,
    private readonly mail: MailService,
    @Inject(PG_POOL) private readonly pool: Pool,
  ) {}

  /** Check admin role from DB — never trust JWT claim */
  private async isAdmin(userId: number | string): Promise<boolean> {
    const { rows } = await this.pool.query(
      'SELECT role FROM users WHERE id = $1',
      [userId],
    );
    return rows[0]?.role === 'admin';
  }

  // User: list own tickets only. Admin: all tickets.
  @Get('support-tickets')
  async listTickets(@Req() req: any, @Query('status') status?: string) {
    const admin = await this.isAdmin(req.user.id);
    const userId = admin ? undefined : req.user.id;
    return this.svc.getTickets(userId, status);
  }

  // Admin: list all tickets (with optional filters)
  @UseGuards(AdminGuard)
  @Get('support-tickets/all')
  async listAllTickets(@Query('user_id') userId?: string, @Query('status') status?: string) {
    return this.svc.getTickets(userId, status);
  }

  // User creates ticket — user_id always from JWT
  @Post('support-tickets')
  async createTicket(@Req() req: any, @Body() body: Record<string, any>) {
    if (!body.subject) throw new HttpException('subject required', HttpStatus.BAD_REQUEST);
    return this.svc.createTicket({ ...body, user_id: req.user.id });
  }

  // Admin only: update ticket status
  @UseGuards(AdminGuard)
  @Put('support-tickets/:id')
  async updateTicket(@Param('id') id: string, @Body() body: Record<string, any>) {
    const row = await this.svc.updateTicket(+id, body);
    if (!row) throw new HttpException('not found', HttpStatus.NOT_FOUND);
    return row;
  }

  // Messages: user can only see messages for their own tickets
  @Get('support-messages')
  async listMessages(@Req() req: any, @Query('ticket_id') ticketId: string) {
    if (!ticketId) throw new HttpException('ticket_id required', HttpStatus.BAD_REQUEST);

    // Verify ticket ownership (check admin from DB, not JWT)
    const admin = await this.isAdmin(req.user.id);
    if (!admin) {
      const tickets = await this.svc.getTickets(req.user.id);
      const owns = (tickets as any[]).some((t: any) => String(t.id) === ticketId);
      if (!owns) throw new HttpException('not your ticket', HttpStatus.FORBIDDEN);
    }

    return this.svc.getMessages(+ticketId);
  }

  // User/Admin adds message — sender_id from JWT
  @Post('support-messages')
  async addMessage(@Req() req: any, @Body() body: Record<string, any>) {
    if (!body.ticket_id || !body.body) throw new HttpException('ticket_id and body required', HttpStatus.BAD_REQUEST);

    const admin = await this.isAdmin(req.user.id);
    if (!admin) {
      const tickets = await this.svc.getTickets(req.user.id);
      const owns = (tickets as any[]).some((t: any) => String(t.id) === String(body.ticket_id));
      if (!owns) throw new HttpException('not your ticket', HttpStatus.FORBIDDEN);
    }

    // SECURITY: override sender_role based on DB check, not user-supplied value
    const message = await this.svc.addMessage({
      ...body,
      sender_id: req.user.id,
      sender_role: admin ? 'admin' : 'user',
    });

    // If admin replied — send in-app notification to ticket owner
    if (admin) {
      try {
        const ticket = await this.svc.getTicketById(+body.ticket_id);
        if (ticket?.user_id) {
          await this.notifications.send({
            user_id: ticket.user_id,
            title: 'Ответ от поддержки',
            message: `По обращению «${ticket.subject}» получен ответ`,
            type: 'system',
            meta: { ticket_id: ticket.id },
          });
        }
      } catch (e) {
        console.error('[Support] Failed to send notification:', e);
      }
    }

    return message;
  }

  // Admin: send email notification to ticket owner
  @UseGuards(AdminGuard)
  @Post('support-tickets/:id/notify-email')
  async notifyByEmail(@Param('id') id: string, @Body() body: { message_text?: string }) {
    const ticket = await this.svc.getTicketById(+id);
    if (!ticket) throw new HttpException('ticket not found', HttpStatus.NOT_FOUND);

    // Get user email
    const { rows } = await this.pool.query('SELECT email FROM users WHERE id = $1', [ticket.user_id]);
    const email = rows[0]?.email;
    if (!email) throw new HttpException('user email not found', HttpStatus.NOT_FOUND);

    const replyText = body.message_text || 'У вас новый ответ от поддержки. Зайдите в AURIX чтобы прочитать.';

    await this.mail.sendTicketReplyEmail(email, ticket.subject, replyText, ticket.id);

    return { success: true, email };
  }
}
