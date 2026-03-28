import { Controller, Get, Post, Put, Body, Param, Req, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { AccountService } from './account.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class AccountController {
  constructor(private readonly svc: AccountService) {}

  @Post('account-deletion-requests')
  async requestDeletion(@Req() req: any, @Body() body: Record<string, any>) {
    return this.svc.requestDeletion(req.user.id, body.reason);
  }

  @Get('account-deletion-requests/latest-status')
  async latestStatus(@Req() req: any) {
    return this.svc.getLatestStatus(req.user.id);
  }

  // User: see own delete requests. Admin: see all.
  @Get('release-delete-requests')
  async getDeleteRequests(@Req() req: any) {
    // SECURITY: check admin role from DB, not JWT (JWT role can be stale)
    const { rows } = await this.svc['pool'].query('SELECT role FROM users WHERE id = $1', [req.user.id]);
    if (rows[0]?.role === 'admin') {
      return this.svc.getDeleteRequests();
    }
    return this.svc.getDeleteRequests(req.user.id);
  }

  // User creates — requester_id always from JWT
  @Post('release-delete-requests')
  async createDeleteRequest(@Req() req: any, @Body() body: Record<string, any>) {
    if (body.release_id) {
      const { rows } = await this.svc['pool'].query(
        'SELECT r.id FROM releases r JOIN artists a ON a.id = r.artist_id WHERE r.id = $1 AND a.user_id = $2',
        [body.release_id, req.user.id],
      );
      if (!rows.length) {
        throw new HttpException('not your release', HttpStatus.FORBIDDEN);
      }
    }
    return this.svc.createDeleteRequest({ ...body, requester_id: req.user.id });
  }

  // Admin only: update status
  @UseGuards(AdminGuard)
  @Put('release-delete-requests/:id')
  async updateDeleteRequest(@Param('id') id: string, @Body() body: Record<string, any>) {
    return this.svc.updateDeleteRequest(+id, body);
  }

  @Post('rpc/admin_process_release_delete_request')
  @UseGuards(AdminGuard)
  async processDeleteRequest(@Body() body: { p_request_id: number; p_decision: string; p_comment?: string }) {
    return this.svc.processDeleteRequest(body.p_request_id, body.p_decision, body.p_comment);
  }
}
