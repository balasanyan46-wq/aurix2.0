import { Controller, Get, Post, Put, Body, Param, Query, Req, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
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

  @Get('release-delete-requests')
  async getDeleteRequests(@Query('requester_id') requesterId?: string) {
    return this.svc.getDeleteRequests(requesterId ? +requesterId : undefined);
  }

  @Post('release-delete-requests')
  async createDeleteRequest(@Body() body: Record<string, any>) {
    return this.svc.createDeleteRequest(body);
  }

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
