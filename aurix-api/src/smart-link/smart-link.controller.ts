import {
  Controller,
  Get,
  Post,
  Param,
  Query,
  Body,
  Req,
  Res,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import * as express from 'express';
import { randomUUID } from 'crypto';
import { SmartLinkService } from './smart-link.service';

/**
 * Public AAI endpoints — NO auth required.
 * Handles smart links, visit/click tracking, and top pages.
 */
@Controller()
export class SmartLinkController {
  constructor(private readonly svc: SmartLinkService) {}

  // ── Helpers ────────────────────────────────────────────

  private clientIp(req: express.Request): string | null {
    const xff = req.headers['x-forwarded-for'];
    if (typeof xff === 'string') return xff.split(',')[0].trim();
    return req.ip ?? null;
  }

  private getSessionId(req: express.Request): { sessionId: string; isNew: boolean } {
    const cookie = req.headers['cookie'] ?? '';
    const match = cookie.match(/(?:^|;\s*)aai_sid=([^;]+)/);
    if (match) return { sessionId: decodeURIComponent(match[1]), isNew: false };
    return { sessionId: randomUUID(), isNew: true };
  }

  // ── GET /s/:id — Smart link page ──────────────────────

  @Get('s/:id')
  async smartLink(
    @Param('id') releaseId: string,
    @Req() req: express.Request,
    @Res() res: express.Response,
  ): Promise<void> {
    const release = await this.svc.fetchReleaseMeta(releaseId);
    if (!release) {
      res.status(404).type('html').send('<h1>Release not found</h1>');
      return;
    }

    const { sessionId, isNew } = this.getSessionId(req);
    const userAgent = req.headers['user-agent'] ?? null;
    const suspiciousUa = this.svc.isSuspiciousUserAgent(userAgent);
    const ipHash = this.svc.hashIp(this.clientIp(req));
    const burst = await this.svc.isAnomalousBurst(releaseId, sessionId);
    const filtered = suspiciousUa || burst;

    // Fire-and-forget: don't block response
    this.svc
      .insertView({
        releaseId,
        sessionId,
        country: (req.headers['cf-ipcountry'] as string) ?? null,
        referrer: req.headers['referer'] ?? null,
        userAgent,
        ipHash,
        eventType: 'view',
        engagedSeconds: 0,
        isSuspicious: suspiciousUa || burst,
        isFiltered: filtered,
      })
      .catch(() => {});
    this.svc.recalcAndPersist(releaseId).catch(() => {});

    const html = this.svc.renderSmartLinkPage(release, sessionId, releaseId);

    if (isNew) {
      res.cookie('aai_sid', sessionId, {
        maxAge: 30 * 24 * 60 * 60 * 1000, // 30 days
        httpOnly: true,
        secure: true,
        sameSite: 'lax',
        path: '/',
      });
    }

    res.status(200).type('html').header('Cache-Control', 'no-store').send(html);
  }

  // ── POST /aai/visit — Track page view / leave event ───

  @Post('aai/visit')
  async visit(@Req() req: express.Request, @Body() body: Record<string, any>) {
    const releaseId = String(body.release_id ?? '').trim();
    if (!releaseId) throw new HttpException('release_id required', HttpStatus.BAD_REQUEST);

    const { sessionId } = this.getSessionId(req);
    const bodySessionId = String(body.session_id ?? '').trim();
    const sid = bodySessionId || sessionId;

    const userAgent = req.headers['user-agent'] ?? null;
    const suspiciousUa = this.svc.isSuspiciousUserAgent(userAgent);
    const ipHash = this.svc.hashIp(this.clientIp(req));
    const eventType = body.event_type === 'leave' ? 'leave' : 'view';
    const engagedSeconds = Math.max(0, Number(body.engaged_seconds ?? 0) || 0);

    await this.svc.insertView({
      releaseId,
      sessionId: sid,
      country: (req.headers['cf-ipcountry'] as string) ?? null,
      referrer: req.headers['referer'] ?? null,
      userAgent,
      ipHash,
      eventType: eventType as 'view' | 'leave',
      engagedSeconds,
      isSuspicious: suspiciousUa,
      isFiltered: suspiciousUa,
    });

    this.svc.recalcAndPersist(releaseId).catch(() => {});
    return { ok: true, session_id: sid };
  }

  // ── GET /aai/click — Track click + redirect ───────────

  @Get('aai/click')
  async clickGet(
    @Query('release_id') releaseId: string,
    @Query('platform') platform: string,
    @Query('to') target: string,
    @Req() req: express.Request,
    @Res() res: express.Response,
  ): Promise<void> {
    if (!releaseId || !platform) {
      res.status(400).json({ error: 'release_id and platform required' });
      return;
    }

    const { sessionId } = this.getSessionId(req);
    const userAgent = req.headers['user-agent'] ?? null;
    const suspiciousUa = this.svc.isSuspiciousUserAgent(userAgent);
    const ipHash = this.svc.hashIp(this.clientIp(req));
    const tooFast = await this.svc.isClickTooFrequent(releaseId, sessionId, platform, 5);
    const burst = await this.svc.isAnomalousBurst(releaseId, sessionId);
    const filtered = suspiciousUa || tooFast || burst;

    // Fire-and-forget
    this.svc
      .insertClick({
        releaseId,
        platform: platform.toLowerCase(),
        redirectUrl: target || null,
        sessionId,
        country: (req.headers['cf-ipcountry'] as string) ?? null,
        referrer: req.headers['referer'] ?? null,
        userAgent,
        ipHash,
        isSuspicious: suspiciousUa || tooFast || burst,
        isFiltered: filtered,
      })
      .catch(() => {});
    this.svc.recalcAndPersist(releaseId).catch(() => {});

    if (target && /^https?:\/\//i.test(target) && !target.includes('javascript:')) {
      res.redirect(302, target);
    } else if (target) {
      res.status(400).json({ error: 'invalid redirect URL' });
      return;
    } else {
      res.json({ ok: true, filtered, session_id: sessionId });
    }
  }

  // ── POST /aai/click — Track click (beacon) ────────────

  @Post('aai/click')
  async clickPost(@Req() req: express.Request, @Body() body: Record<string, any>) {
    const releaseId = String(body.release_id ?? '').trim();
    const platform = String(body.platform ?? '').trim().toLowerCase();
    if (!releaseId || !platform) {
      throw new HttpException('release_id and platform required', HttpStatus.BAD_REQUEST);
    }

    const { sessionId } = this.getSessionId(req);
    const bodySessionId = String(body.session_id ?? '').trim();
    const sid = bodySessionId || sessionId;
    const target = String(body.to ?? '').trim();

    const userAgent = req.headers['user-agent'] ?? null;
    const suspiciousUa = this.svc.isSuspiciousUserAgent(userAgent);
    const ipHash = this.svc.hashIp(this.clientIp(req));
    const tooFast = await this.svc.isClickTooFrequent(releaseId, sid, platform, 5);
    const burst = await this.svc.isAnomalousBurst(releaseId, sid);
    const filtered = suspiciousUa || tooFast || burst;

    await this.svc.insertClick({
      releaseId,
      platform,
      redirectUrl: target || null,
      sessionId: sid,
      country: (req.headers['cf-ipcountry'] as string) ?? null,
      referrer: req.headers['referer'] ?? null,
      userAgent,
      ipHash,
      isSuspicious: suspiciousUa || tooFast || burst,
      isFiltered: filtered,
    });

    this.svc.recalcAndPersist(releaseId).catch(() => {});
    return { ok: true, filtered, session_id: sid };
  }

  // ── GET /aai/top10 — JSON top 10 ─────────────────────

  @Get('aai/top10')
  async top10() {
    const top = await this.svc.getTop10();
    return { top };
  }

  // ── GET /aai/top — HTML top page ──────────────────────

  @Get('aai/top')
  async topPage(@Res() res: express.Response) {
    const top = await this.svc.getTop10();
    const html = this.svc.renderTopPage(top);
    res.status(200).type('html').header('Cache-Control', 'no-store').send(html);
  }
}
