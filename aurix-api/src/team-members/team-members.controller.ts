import { Controller, Get, Post, Put, Body, Param, Query, Req, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TeamMembersService } from './team-members.service';

@UseGuards(JwtAuthGuard)
@Controller('team-members')
export class TeamMembersController {
  constructor(private readonly svc: TeamMembersService) {}

  @Get()
  async list(@Req() req: any, @Query('status_neq') statusNeq?: string) {
    // SECURITY: always scope to the authenticated user
    const rows = await this.svc.findByOwner(req.user.id, statusNeq);
    return rows;
  }

  @Post()
  async create(@Req() req: any, @Body() body: Record<string, any>) {
    if (!body.member_name) throw new HttpException('member_name required', HttpStatus.BAD_REQUEST);
    // SECURITY: always use authenticated user's ID as owner
    const row = await this.svc.create({ ...body, owner_id: req.user.id });
    return row;
  }

  @Put(':id')
  async update(@Req() req: any, @Param('id') id: string, @Body() body: Record<string, any>) {
    const row = await this.svc.updateForOwner(+id, req.user.id, body);
    if (!row) throw new HttpException('not found', HttpStatus.NOT_FOUND);
    return row;
  }
}
