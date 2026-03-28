import { Controller, Get, Post, Body, Param, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { SessionsService } from './sessions.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class SessionsController {
  constructor(private readonly svc: SessionsService) {}

  // ── User endpoints ─────────────────────────────────────

  /** Start a session (called on app open). */
  @Post('sessions/start')
  async start(@Req() req: any, @Body() body: { device?: string }) {
    return this.svc.start(
      req.user.id,
      body.device,
      req.ip,
      req.headers?.['user-agent'],
    );
  }

  /** End a session (called on app close / background). */
  @Post('sessions/end')
  async end(@Req() req: any, @Body() body: { session_id: number }) {
    return this.svc.end(body.session_id, req.user.id);
  }

  /** Log session event (screen views, actions). */
  @Post('sessions/event')
  async logEvent(@Req() req: any, @Body() body: { session_id: number; event_type: string; screen?: string; action?: string; meta?: any }) {
    return this.svc.logEvent(body.session_id, req.user.id, body.event_type, body.screen, body.action, body.meta);
  }

  // ── Admin endpoints ────────────────────────────────────

  /** Admin: sessions for a user. */
  @UseGuards(AdminGuard)
  @Get('admin/sessions/user/:userId')
  async userSessions(@Param('userId') userId: string, @Query('limit') limit?: string) {
    return this.svc.forUser(+userId, limit ? +limit : 20);
  }

  /** Admin: session replay (full event timeline). */
  @UseGuards(AdminGuard)
  @Get('admin/sessions/:id/replay')
  async replay(@Param('id') id: string) {
    return this.svc.replay(+id);
  }

  /** Admin: recent sessions. */
  @UseGuards(AdminGuard)
  @Get('admin/sessions/recent')
  async recent(@Query('limit') limit?: string) {
    return this.svc.recent(limit ? +limit : 30);
  }

  /** Admin: session stats. */
  @UseGuards(AdminGuard)
  @Get('admin/sessions/stats')
  async stats(@Query('days') days?: string) {
    return this.svc.stats(days ? +days : 7);
  }
}
