import { Controller, Get, Post, Put, Body, Param, Query, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TeamMembersService } from './team-members.service';

@UseGuards(JwtAuthGuard)
@Controller('team-members')
export class TeamMembersController {
  constructor(private readonly svc: TeamMembersService) {}

  @Get()
  async list(@Query('owner_id') ownerId: string, @Query('status_neq') statusNeq?: string) {
    if (!ownerId) throw new HttpException('owner_id required', HttpStatus.BAD_REQUEST);
    const rows = await this.svc.findByOwner(+ownerId, statusNeq);
    return rows;
  }

  @Post()
  async create(@Body() body: Record<string, any>) {
    if (!body.owner_id || !body.member_name) throw new HttpException('owner_id and member_name required', HttpStatus.BAD_REQUEST);
    const row = await this.svc.create(body);
    return row;
  }

  @Put(':id')
  async update(@Param('id') id: string, @Body() body: Record<string, any>) {
    const row = await this.svc.update(+id, body);
    if (!row) throw new HttpException('not found', HttpStatus.NOT_FOUND);
    return row;
  }
}
