import {
  Controller,
  Post,
  Param,
  Body,
  Req,
  UseGuards,
  HttpException,
  HttpStatus,
  Inject,
} from '@nestjs/common';
import { Pool } from 'pg';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreditGuard, CreditAction } from '../billing/credit.guard';
import { StudioToolsService } from './studio-tools.service';
import { PG_POOL } from '../database/database.module';

@UseGuards(JwtAuthGuard)
@Controller('tools')
export class StudioToolsController {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly svc: StudioToolsService,
  ) {}

  @Throttle({ default: { ttl: 60000, limit: 10 } })
  @Post(':toolName')
  @CreditAction('ai_chat')
  @UseGuards(CreditGuard)
  async runTool(
    @Param('toolName') toolName: string,
    @Body() body: { releaseId?: string; inputs?: Record<string, any> },
    @Req() req: any,
  ) {
    const releaseId = String(body.releaseId ?? '');
    const inputs = body.inputs ?? {};

    if (releaseId) {
      const { rows } = await this.pool.query(
        'SELECT r.id FROM releases r JOIN artists a ON a.id = r.artist_id WHERE r.id = $1 AND a.user_id = $2',
        [releaseId, req.user.id],
      );
      if (!rows.length) {
        throw new HttpException('not your release', HttpStatus.FORBIDDEN);
      }
    }

    const result = await this.svc.generate(toolName, releaseId, inputs);

    if (!result.ok) {
      throw new HttpException(
        { error: result.error, ok: false },
        HttpStatus.BAD_GATEWAY,
      );
    }

    return {
      ok: true,
      data: result.data,
      is_demo: result.is_demo ?? false,
      credits: req.creditSpend,
    };
  }
}
