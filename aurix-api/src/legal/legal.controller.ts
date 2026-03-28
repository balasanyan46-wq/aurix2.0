import { Controller, Get, Post, Put, Body, Param, Query, Req, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { LegalService } from './legal.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class LegalController {
  constructor(private readonly svc: LegalService) {}

  @Get('legal-templates')
  async listTemplates(@Query('category') cat?: string) { return this.svc.getTemplates(cat); }

  @Get('legal-templates/:id')
  async getTemplate(@Param('id') id: string) {
    const t = await this.svc.getTemplateById(+id);
    if (!t) throw new HttpException('not found', HttpStatus.NOT_FOUND);
    return t;
  }

  @Get('legal-documents/my')
  async myDocs(@Req() req: any) { return this.svc.getMyDocuments(req.user.id); }

  @Post('legal-documents')
  async createDoc(@Req() req: any, @Body() body: Record<string, any>) {
    return this.svc.createDocument(req.user.id, body);
  }

  @Put('legal-documents/:id')
  async updateDoc(@Req() req: any, @Param('id') id: string, @Body() body: Record<string, any>) {
    // SECURITY: ownership check
    return this.svc.updateDocument(+id, req.user.id, body);
  }

  @Get('legal-documents/signed-url')
  async signedUrl(@Query('path') path: string) {
    // SECURITY: validate path to prevent traversal
    if (!path || path.includes('..') || /[^a-zA-Z0-9\-_./]/.test(path)) {
      throw new HttpException('invalid path', HttpStatus.BAD_REQUEST);
    }
    const base = process.env.APP_URL || 'http://localhost:3000';
    return { url: `${base}/storage/${path}` };
  }

  @Post('legal-acceptances/batch')
  async batchAccept(@Req() req: any, @Body() body: any[]) {
    return this.svc.batchAcceptances(req.user.id, body);
  }

  @Get('cookie-consents')
  async getCookies(@Req() req: any) { return this.svc.getCookieConsent(req.user.id); }

  @Put('cookie-consents')
  async updateCookies(@Req() req: any, @Body() body: Record<string, any>) {
    return this.svc.upsertCookieConsent(req.user.id, body);
  }
}
