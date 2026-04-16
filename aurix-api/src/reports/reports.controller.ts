import { Controller, Get, Post, Put, Delete, Body, Param, Query, Req, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { ReportsService } from './reports.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class ReportsController {
  constructor(private readonly svc: ReportsService) {}

  // ── User-scoped: own report rows ───────────────────────
  @Get('report-rows/my')
  async getMyRows(@Req() req: any, @Query() query: Record<string, any>) {
    return this.svc.getRows({ ...query, user_id: req.user.id });
  }

  // ── Admin-only endpoints ───────────────────────────────
  @Get('reports')
  @UseGuards(AdminGuard)
  async list() { return this.svc.list(); }

  @Get('reports/:id')
  @UseGuards(AdminGuard)
  async getOne(@Param('id') id: string) {
    const r = await this.svc.findById(+id);
    if (!r) throw new HttpException('not found', HttpStatus.NOT_FOUND);
    return r;
  }

  @Post('reports')
  @UseGuards(AdminGuard)
  async create(@Body() body: Record<string, any>) { return this.svc.create(body); }

  @Put('reports/:id')
  @UseGuards(AdminGuard)
  async update(@Param('id') id: string, @Body() body: Record<string, any>) {
    const r = await this.svc.update(+id, body);
    if (!r) throw new HttpException('not found', HttpStatus.NOT_FOUND);
    return r;
  }

  @Delete('reports/:id')
  @UseGuards(AdminGuard)
  async delete(@Param('id') id: string) {
    await this.svc.delete(+id);
    return { success: true };
  }

  @Get('report-rows')
  @UseGuards(AdminGuard)
  async getRows(@Query() query: Record<string, any>) { return this.svc.getRows(query); }

  @Post('report-rows/batch')
  @UseGuards(AdminGuard)
  async batchRows(@Body() body: any[]) { return this.svc.batchInsertRows(body); }

  @Put('report-rows/:id')
  @UseGuards(AdminGuard)
  async updateRow(@Param('id') id: string, @Body() body: Record<string, any>) {
    return this.svc.updateRow(+id, body);
  }

  @Delete('report-rows/by-report/:reportId')
  @UseGuards(AdminGuard)
  async deleteRows(@Param('reportId') reportId: string) {
    await this.svc.deleteRowsByReport(+reportId);
    return { success: true };
  }

  // Одним SQL-запросом проставляет track_id всем строкам отчёта по ISRC.
  // Триггер report_rows_fill_scope() автоматически заполняет user_id/release_id.
  @Post('report-rows/match-isrc/:reportId')
  @UseGuards(AdminGuard)
  async matchIsrcBulk(@Param('reportId') reportId: string) {
    return this.svc.matchRowsByIsrcBulk(+reportId);
  }

}
