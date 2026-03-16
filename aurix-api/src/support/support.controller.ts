import { Controller, Get, Post, Put, Body, Param, Query, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { SupportService } from './support.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class SupportController {
  constructor(private readonly svc: SupportService) {}

  @Get('support-tickets')
  async listTickets(@Query('user_id') userId?: string, @Query('status') status?: string) {
    return this.svc.getTickets(userId, status);
  }

  @Post('support-tickets')
  async createTicket(@Body() body: Record<string, any>) {
    if (!body.user_id || !body.subject) throw new HttpException('user_id and subject required', HttpStatus.BAD_REQUEST);
    return this.svc.createTicket(body);
  }

  @Put('support-tickets/:id')
  async updateTicket(@Param('id') id: string, @Body() body: Record<string, any>) {
    const row = await this.svc.updateTicket(+id, body);
    if (!row) throw new HttpException('not found', HttpStatus.NOT_FOUND);
    return row;
  }

  @Get('support-messages')
  async listMessages(@Query('ticket_id') ticketId: string) {
    if (!ticketId) throw new HttpException('ticket_id required', HttpStatus.BAD_REQUEST);
    return this.svc.getMessages(+ticketId);
  }

  @Post('support-messages')
  async addMessage(@Body() body: Record<string, any>) {
    if (!body.ticket_id || !body.body) throw new HttpException('ticket_id and body required', HttpStatus.BAD_REQUEST);
    return this.svc.addMessage(body);
  }
}
