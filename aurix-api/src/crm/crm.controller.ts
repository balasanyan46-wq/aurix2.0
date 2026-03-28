import { Controller, Get, Post, Put, Body, Param, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { CrmService } from './crm.service';

@UseGuards(JwtAuthGuard, AdminGuard)
@Controller()
export class CrmController {
  constructor(private readonly svc: CrmService) {}

  @Get('crm-leads') async getLeads(@Query() q: Record<string, any>) { return this.svc.getLeads(q); }
  @Put('crm-leads/:id') async updateLead(@Param('id') id: string, @Body() body: Record<string, any>) { return this.svc.updateLead(+id, body); }

  @Get('crm-deals') async getDeals(@Query() q: Record<string, any>) { return this.svc.getDeals(q); }
  @Post('crm-deals') async createDeal(@Body() body: Record<string, any>) { return this.svc.createDeal(body); }
  @Put('crm-deals/:id') async updateDeal(@Param('id') id: string, @Body() body: Record<string, any>) { return this.svc.updateDeal(+id, body); }

  @Get('crm-tasks') async getTasks(@Query() q: Record<string, any>) { return this.svc.getTasks(q); }
  @Post('crm-tasks') async createTask(@Body() body: Record<string, any>) { return this.svc.createTask(body); }
  @Put('crm-tasks/:id') async updateTask(@Param('id') id: string, @Body() body: Record<string, any>) { return this.svc.updateTask(+id, body); }

  @Get('crm-notes') async getNotes(@Query() q: Record<string, any>) { return this.svc.getNotes(q); }
  @Post('crm-notes') async addNote(@Body() body: Record<string, any>) { return this.svc.addNote(body); }

  @Get('crm-events') async getEvents(@Query() q: Record<string, any>) { return this.svc.getEvents(q); }
  @Post('crm-events') async addEvent(@Body() body: Record<string, any>) { return this.svc.addEvent(body); }

  @Get('crm-invoices') async getInvoices(@Query() q: Record<string, any>) { return this.svc.getInvoices(q); }
  @Put('crm-invoices') async upsertInvoice(@Body() body: Record<string, any>) { return this.svc.upsertInvoice(body); }

  @Get('crm-transactions') async getTransactions(@Query() q: Record<string, any>) { return this.svc.getTransactions(q); }
  @Post('crm-transactions') async addTransaction(@Body() body: Record<string, any>) { return this.svc.addTransaction(body); }
}
