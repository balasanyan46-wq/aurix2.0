import { Controller, Get, Post, Body, Query, Param, Req, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { NotificationsService } from './notifications.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class NotificationsController {
  constructor(private readonly svc: NotificationsService) {}

  // ── User endpoints ─────────────────────────────────────

  /** Get my notifications. */
  @Get('notifications/my')
  async getMyNotifications(@Req() req: any, @Query('unread') unread?: string) {
    return this.svc.forUser(req.user.id, 50, unread === 'true');
  }

  /** Unread count. */
  @Get('notifications/unread-count')
  async unreadCount(@Req() req: any) {
    const count = await this.svc.unreadCount(req.user.id);
    return { count };
  }

  /** Mark as read (single or all). */
  @Post('notifications/mark-read')
  async markRead(@Req() req: any, @Body() body: { id?: number }) {
    await this.svc.markRead(req.user.id, body.id);
    return { success: true };
  }

  // ── Admin endpoints ────────────────────────────────────

  /** Admin: send notification to a user. */
  @UseGuards(AdminGuard)
  @Post('admin/notifications/send')
  async adminSend(@Body() body: { user_id: number; title: string; message: string; type?: string }) {
    if (!body.user_id || !body.title || !body.message) {
      throw new HttpException('user_id, title, message required', HttpStatus.BAD_REQUEST);
    }
    return this.svc.send(body);
  }

  /** Admin: broadcast to multiple users. */
  @UseGuards(AdminGuard)
  @Post('admin/notifications/broadcast')
  async adminBroadcast(@Body() body: { user_ids: number[]; title: string; message: string; type?: string }) {
    if (!body.user_ids?.length || !body.title || !body.message) {
      throw new HttpException('user_ids, title, message required', HttpStatus.BAD_REQUEST);
    }
    const count = await this.svc.sendBulk(body.user_ids, body.title, body.message, body.type);
    return { success: true, sent: count };
  }

  /** Admin: list all notifications. */
  @UseGuards(AdminGuard)
  @Get('admin/notifications')
  async adminList(
    @Query('user_id') userId?: string,
    @Query('type') type?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.svc.listAll({
      userId: userId ? +userId : undefined,
      type,
      limit: limit ? +limit : 50,
      offset: offset ? +offset : 0,
    });
  }
}
