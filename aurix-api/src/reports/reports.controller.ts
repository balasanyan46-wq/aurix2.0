import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ReportsService } from './reports.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class ReportsController {
  constructor(private readonly svc: ReportsService) {}

  @Get('reports')
  async list() { return this.svc.list(); }

  @Get('reports/:id')
  async getOne(@Param('id') id: string) {
    const r = await this.svc.findById(+id);
    if (!r) throw new HttpException('not found', HttpStatus.NOT_FOUND);
    return r;
  }

  @Post('reports')
  async create(@Body() body: Record<string, any>) { return this.svc.create(body); }

  @Put('reports/:id')
  async update(@Param('id') id: string, @Body() body: Record<string, any>) {
    const r = await this.svc.update(+id, body);
    if (!r) throw new HttpException('not found', HttpStatus.NOT_FOUND);
    return r;
  }

  @Delete('reports/:id')
  async delete(@Param('id') id: string) {
    await this.svc.delete(+id);
    return { success: true };
  }

  @Get('report-rows')
  async getRows(@Query() query: Record<string, any>) { return this.svc.getRows(query); }

  @Post('report-rows/batch')
  async batchRows(@Body() body: any[]) { return this.svc.batchInsertRows(body); }

  @Put('report-rows/:id')
  async updateRow(@Param('id') id: string, @Body() body: Record<string, any>) {
    return this.svc.updateRow(+id, body);
  }

  @Delete('report-rows/by-report/:reportId')
  async deleteRows(@Param('reportId') reportId: string) {
    await this.svc.deleteRowsByReport(+reportId);
    return { success: true };
  }
}
