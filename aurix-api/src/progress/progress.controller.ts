import { Controller, Get, Post, Put, Delete, Body, Param, Query, Req, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ProgressService } from './progress.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class ProgressController {
  constructor(private readonly svc: ProgressService) {}

  @Get('progress-habits')
  async getHabits(@Req() req: any, @Query('is_active') isActive?: string) {
    return this.svc.getHabits(req.user.id, isActive);
  }

  @Post('progress-habits')
  async createHabit(@Req() req: any, @Body() body: Record<string, any>) {
    if (!body.title) throw new HttpException('title required', HttpStatus.BAD_REQUEST);
    return this.svc.createHabit(req.user.id, body);
  }

  @Put('progress-habits/:id')
  async updateHabit(@Param('id') id: string, @Body() body: Record<string, any>) {
    return this.svc.updateHabit(+id, body);
  }

  @Delete('progress-habits/:id')
  async deleteHabit(@Param('id') id: string) {
    await this.svc.deleteHabit(+id);
    return { success: true };
  }

  @Get('progress-checkins')
  async getCheckins(@Req() req: any, @Query('start_day') startDay: string, @Query('end_day') endDay: string) {
    if (!startDay || !endDay) throw new HttpException('start_day and end_day required', HttpStatus.BAD_REQUEST);
    return this.svc.getCheckins(req.user.id, startDay, endDay);
  }

  @Post('progress-checkins')
  async createCheckin(@Req() req: any, @Body() body: Record<string, any>) {
    return this.svc.createCheckin(req.user.id, body);
  }

  @Delete('progress-checkins/:habitId/:day')
  async deleteCheckin(@Param('habitId') habitId: string, @Param('day') day: string) {
    await this.svc.deleteCheckin(+habitId, day);
    return { success: true };
  }

  @Get('progress-daily-notes')
  async getDailyNote(@Req() req: any, @Query('day') day: string) {
    if (!day) throw new HttpException('day required', HttpStatus.BAD_REQUEST);
    return this.svc.getDailyNote(req.user.id, day);
  }

  @Post('progress-daily-notes')
  async upsertDailyNote(@Req() req: any, @Body() body: Record<string, any>) {
    if (!body.day) throw new HttpException('day required', HttpStatus.BAD_REQUEST);
    return this.svc.upsertDailyNote(req.user.id, body);
  }

  @Delete('progress-daily-notes/:day')
  async deleteDailyNote(@Req() req: any, @Param('day') day: string) {
    await this.svc.deleteDailyNote(req.user.id, day);
    return { success: true };
  }
}
