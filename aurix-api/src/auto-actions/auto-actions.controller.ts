import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { AutoActionsService } from './auto-actions.service';

@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin/auto-actions')
export class AutoActionsController {
  constructor(private readonly svc: AutoActionsService) {}

  /** List all rules. */
  @Get()
  async list() {
    return this.svc.list();
  }

  /** Create a new rule. */
  @Post()
  async create(@Body() body: Record<string, any>) {
    return this.svc.create(body);
  }

  /** Update a rule. */
  @Put(':id')
  async update(@Param('id') id: string, @Body() body: Record<string, any>) {
    return this.svc.update(+id, body);
  }

  /** Delete a rule. */
  @Delete(':id')
  async remove(@Param('id') id: string) {
    await this.svc.delete(+id);
    return { success: true };
  }

  /** View execution log. */
  @Get('log')
  async log(
    @Query('action_id') actionId?: string,
    @Query('user_id') userId?: string,
    @Query('limit') limit?: string,
  ) {
    return this.svc.getLog({
      actionId: actionId ? +actionId : undefined,
      userId: userId ? +userId : undefined,
      limit: limit ? +limit : 50,
    });
  }

  /** Manually trigger inactivity check. */
  @Post('check-inactivity')
  async checkInactivity() {
    return this.svc.checkInactivity();
  }

  /** Reload rules from DB. */
  @Post('reload')
  async reload() {
    await this.svc.loadRules();
    return { success: true };
  }
}
