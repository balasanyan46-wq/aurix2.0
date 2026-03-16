import { Controller, Get, Post, Delete, Body, Param, Query, Req, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AiToolsService } from './ai-tools.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class AiToolsController {
  constructor(private readonly svc: AiToolsService) {}

  @Get('ai-tool-results/latest')
  async getLatest(@Req() req: any, @Query('tool_id') toolId: string, @Query('resource_type') rt?: string, @Query('resource_id') ri?: string) {
    if (!toolId) throw new HttpException('tool_id required', HttpStatus.BAD_REQUEST);
    return this.svc.getLatestResult(req.user.id, toolId, rt, ri);
  }

  @Post('ai-tool-results')
  async save(@Req() req: any, @Body() body: Record<string, any>) {
    return this.svc.saveResult(req.user.id, body);
  }

  @Get('ai-studio-messages')
  async getMessages(@Req() req: any, @Query('limit') limit?: string) {
    return this.svc.getMessages(req.user.id, +(limit || 50));
  }

  @Post('ai-studio-messages')
  async addMessage(@Req() req: any, @Body() body: { role: string; content: string }) {
    return this.svc.addMessage(req.user.id, body.role, body.content);
  }

  @Delete('ai-studio-messages')
  async clearMessages(@Req() req: any) {
    await this.svc.clearMessages(req.user.id);
    return { success: true };
  }

  @Get('release-tools/latest')
  async getReleaseTool(@Req() req: any, @Query('release_id') releaseId: string, @Query('tool_key') toolKey: string) {
    if (!releaseId || !toolKey) throw new HttpException('release_id and tool_key required', HttpStatus.BAD_REQUEST);
    const r = await this.svc.getLatestReleaseTool(req.user.id, +releaseId, toolKey);
    return r || {};
  }

  @Delete('release-tools/:releaseId/:toolKey')
  async deleteReleaseTool(@Req() req: any, @Param('releaseId') rid: string, @Param('toolKey') tk: string) {
    await this.svc.deleteReleaseTool(req.user.id, +rid, tk);
    return { success: true };
  }

  @Get('release-growth-plans/latest')
  async getGrowthPlan(@Req() req: any, @Query('release_id') releaseId: string) {
    if (!releaseId) throw new HttpException('release_id required', HttpStatus.BAD_REQUEST);
    return this.svc.getLatestGrowthPlan(req.user.id, +releaseId) || {};
  }

  @Get('release-budgets/latest')
  async getBudget(@Req() req: any, @Query('release_id') releaseId: string) {
    if (!releaseId) throw new HttpException('release_id required', HttpStatus.BAD_REQUEST);
    return this.svc.getLatestBudget(req.user.id, +releaseId) || {};
  }
}
