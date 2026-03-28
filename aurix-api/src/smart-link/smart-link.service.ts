import { Injectable, Inject, Logger } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import * as crypto from 'crypto';

// ── Helpers ──────────────────────────────────────────────

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function clamp(v: number, min = 0, max = 100): number {
  return Math.max(min, Math.min(max, v));
}

function round2(v: number): number {
  return Math.round(v * 100) / 100;
}

const SUSPICIOUS_UA =
  /(bot|crawler|spider|headless|phantom|selenium|python|curl|wget|postman|insomnia)/i;

// ── Types ────────────────────────────────────────────────

interface ReleaseMeta {
  id: number;
  title: string;
  artist: string | null;
}

interface AaiScorePayload {
  impulseScore: number;
  conversionScore: number;
  engagementScore: number;
  geographyScore: number;
  totalScore: number;
  scorePrev: number;
  delta24h: number;
  delta48h: number;
  views48h: number;
  clicks48h: number;
  uniqueCountries48h: number;
}

// ── Service ──────────────────────────────────────────────

@Injectable()
export class SmartLinkService {
  private readonly logger = new Logger(SmartLinkService.name);

  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  // ── Release lookup ────────────────────────────────────

  async fetchReleaseMeta(releaseId: string): Promise<ReleaseMeta | null> {
    const { rows } = await this.pool.query(
      'SELECT id, title, artist FROM releases WHERE id = $1 LIMIT 1',
      [releaseId],
    );
    return rows[0] ?? null;
  }

  // ── Bot guard ─────────────────────────────────────────

  isSuspiciousUserAgent(ua: string | null): boolean {
    if (!ua || !ua.trim()) return true;
    return SUSPICIOUS_UA.test(ua);
  }

  hashIp(ip: string | null): string | null {
    if (!ip) return null;
    return crypto.createHash('sha256').update(ip).digest('hex');
  }

  async isAnomalousBurst(releaseId: string, sessionId: string): Promise<boolean> {
    const since = new Date(Date.now() - 60_000).toISOString();
    const { rows } = await this.pool.query(
      `SELECT count(*)::int AS cnt FROM release_page_views
       WHERE release_id = $1 AND session_id = $2 AND created_at >= $3`,
      [releaseId, sessionId, since],
    );
    return (rows[0]?.cnt ?? 0) > 30;
  }

  async isClickTooFrequent(
    releaseId: string,
    sessionId: string,
    platform: string,
    minSeconds: number,
  ): Promise<boolean> {
    const { rows } = await this.pool.query(
      `SELECT created_at FROM release_clicks
       WHERE release_id = $1 AND session_id = $2 AND platform = $3
       ORDER BY created_at DESC LIMIT 1`,
      [releaseId, sessionId, platform],
    );
    if (!rows[0]) return false;
    const diffMs = Date.now() - new Date(rows[0].created_at).getTime();
    return diffMs < minSeconds * 1000;
  }

  // ── Insert view / click ───────────────────────────────

  async insertView(payload: {
    releaseId: string;
    sessionId: string;
    country: string | null;
    referrer: string | null;
    userAgent: string | null;
    ipHash: string | null;
    eventType: 'view' | 'leave';
    engagedSeconds: number;
    isSuspicious: boolean;
    isFiltered: boolean;
  }): Promise<void> {
    await this.pool.query(
      `INSERT INTO release_page_views
       (release_id, session_id, country, referrer, user_agent, ip_hash,
        event_type, engaged_seconds, is_suspicious, is_filtered, created_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,NOW())`,
      [
        payload.releaseId,
        payload.sessionId,
        payload.country,
        payload.referrer,
        payload.userAgent,
        payload.ipHash,
        payload.eventType,
        payload.engagedSeconds,
        payload.isSuspicious,
        payload.isFiltered,
      ],
    );
  }

  async insertClick(payload: {
    releaseId: string;
    platform: string;
    redirectUrl: string | null;
    sessionId: string;
    country: string | null;
    referrer: string | null;
    userAgent: string | null;
    ipHash: string | null;
    isSuspicious: boolean;
    isFiltered: boolean;
  }): Promise<void> {
    await this.pool.query(
      `INSERT INTO release_clicks
       (release_id, platform, redirect_url, session_id, country, referrer,
        user_agent, ip_hash, is_suspicious, is_filtered, created_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,NOW())`,
      [
        payload.releaseId,
        payload.platform,
        payload.redirectUrl,
        payload.sessionId,
        payload.country,
        payload.referrer,
        payload.userAgent,
        payload.ipHash,
        payload.isSuspicious,
        payload.isFiltered,
      ],
    );
  }

  // ── Score recalculation ───────────────────────────────

  async recalcAndPersist(releaseId: string): Promise<void> {
    const since = new Date(Date.now() - 48 * 3600 * 1000).toISOString();

    const [viewsRes, clicksRes] = await Promise.all([
      this.pool.query(
        `SELECT created_at, session_id, country, event_type, engaged_seconds, is_filtered
         FROM release_page_views
         WHERE release_id = $1 AND created_at >= $2`,
        [releaseId, since],
      ),
      this.pool.query(
        `SELECT created_at, session_id, platform, country, is_filtered
         FROM release_clicks
         WHERE release_id = $1 AND created_at >= $2`,
        [releaseId, since],
      ),
    ]);

    const views = viewsRes.rows.filter((v: any) => !v.is_filtered);
    const clicks = clicksRes.rows.filter((c: any) => !c.is_filtered);
    const score = this.calculateAttentionIndex(views, clicks);

    await this.pool.query(
      `INSERT INTO release_attention_index
       (release_id, impulse_score, conversion_score, engagement_score, geography_score,
        total_score, status_code, score_prev, delta_24h, delta_48h,
        views_48h, clicks_48h, unique_countries_48h, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,NOW())
       ON CONFLICT (release_id)
       DO UPDATE SET
        impulse_score=$2, conversion_score=$3, engagement_score=$4, geography_score=$5,
        total_score=$6, status_code=$7, score_prev=$8, delta_24h=$9, delta_48h=$10,
        views_48h=$11, clicks_48h=$12, unique_countries_48h=$13, updated_at=NOW()`,
      [
        releaseId,
        score.impulseScore,
        score.conversionScore,
        score.engagementScore,
        score.geographyScore,
        score.totalScore,
        this.classifyStatus(score.totalScore),
        score.scorePrev,
        score.delta24h,
        score.delta48h,
        score.views48h,
        score.clicks48h,
        score.uniqueCountries48h,
      ],
    );
  }

  classifyStatus(score: number): string {
    if (score >= 80) return 'hot';
    if (score >= 60) return 'accelerating';
    if (score >= 40) return 'watching';
    return 'quiet';
  }

  scoreToLabel(score: number): string {
    if (score >= 80) return 'Горящий';
    if (score >= 60) return 'Разгоняется';
    if (score >= 40) return 'Наблюдают';
    return 'Тихий';
  }

  private calculateAttentionIndex(views: any[], clicks: any[]): AaiScorePayload {
    const nowMs = Date.now();
    const t24 = nowMs - 24 * 3600 * 1000;
    const t48 = nowMs - 48 * 3600 * 1000;

    const v48 = views.filter((v) => new Date(v.created_at).getTime() >= t48);
    const c48 = clicks.filter((c) => new Date(c.created_at).getTime() >= t48);

    const views48 = v48.length;
    const clicks48 = c48.length;

    const clicksLast24 = c48.filter((c) => new Date(c.created_at).getTime() >= t24).length;
    const clicksPrev24 = clicks48 - clicksLast24;

    // 1) Impulse 40%
    const activityScore = clamp((clicks48 / 180) * 100);
    const growthRatio = (clicksLast24 - clicksPrev24) / Math.max(clicksPrev24, 1);
    const growthScore = clamp((growthRatio + 1) * 50);
    const impulseScore = round2(activityScore * 0.65 + growthScore * 0.35);

    // 2) Conversion 25%
    const conversion = views48 > 0 ? clicks48 / views48 : 0;
    const conversionScore = round2(clamp((conversion / 0.35) * 100));

    // 3) Engagement 20%
    const sessions = new Map<string, number>();
    for (const v of v48) sessions.set(v.session_id, (sessions.get(v.session_id) ?? 0) + 1);
    const uniqueSessions = sessions.size;
    const repeatSessions = [...sessions.values()].filter((n) => n > 1).length;
    const repeatRatio = uniqueSessions > 0 ? repeatSessions / uniqueSessions : 0;
    const repeatScore = clamp(repeatRatio * 100);

    const leaveEvents = v48.filter((v: any) => v.event_type === 'leave' && v.engaged_seconds > 0);
    const avgEngaged =
      leaveEvents.length > 0
        ? leaveEvents.reduce((sum: number, v: any) => sum + v.engaged_seconds, 0) / leaveEvents.length
        : 0;
    const dwellScore = clamp((avgEngaged / 120) * 100);
    const engagementScore = round2(repeatScore * 0.55 + dwellScore * 0.45);

    // 4) Geography 15%
    const countryCounts = new Map<string, number>();
    for (const v of v48) {
      const c = (v.country ?? '').trim();
      if (!c) continue;
      countryCounts.set(c, (countryCounts.get(c) ?? 0) + 1);
    }
    const uniqueCountries = countryCounts.size;
    const diversityScore = clamp((uniqueCountries / 10) * 100);
    const totalGeo = [...countryCounts.values()].reduce((a, b) => a + b, 0);
    let hhi = 0;
    if (totalGeo > 0) {
      for (const cnt of countryCounts.values()) {
        const p = cnt / totalGeo;
        hhi += p * p;
      }
    }
    const balanceScore = totalGeo > 0 ? clamp((1 - hhi) * 130) : 0;
    const geographyScore = round2(diversityScore * 0.6 + balanceScore * 0.4);

    const totalScore = round2(
      impulseScore * 0.4 +
        conversionScore * 0.25 +
        engagementScore * 0.2 +
        geographyScore * 0.15,
    );

    const prevActivity = clamp((clicksPrev24 / 180) * 100);
    const scorePrev = round2(
      prevActivity * 0.4 +
        conversionScore * 0.25 +
        engagementScore * 0.2 +
        geographyScore * 0.15,
    );

    return {
      impulseScore,
      conversionScore,
      engagementScore,
      geographyScore,
      totalScore,
      scorePrev,
      delta24h: round2(totalScore - scorePrev),
      delta48h: round2(totalScore - scorePrev),
      views48h: views48,
      clicks48h: clicks48,
      uniqueCountries48h: uniqueCountries,
    };
  }

  // ── Top 10 ────────────────────────────────────────────

  async getTop10(): Promise<any[]> {
    const { rows: idxRows } = await this.pool.query(
      `SELECT release_id, total_score, status_code, updated_at
       FROM release_attention_index
       ORDER BY total_score DESC LIMIT 10`,
    );
    if (idxRows.length === 0) return [];

    const ids = idxRows.map((r: any) => r.release_id);
    const { rows: metas } = await this.pool.query(
      `SELECT id, title, artist, cover_url FROM releases WHERE id = ANY($1)`,
      [ids],
    );
    const byId = new Map(metas.map((m: any) => [m.id, m]));

    return idxRows.map((r: any) => {
      const m: any = byId.get(r.release_id);
      const score = Number(r.total_score ?? 0);
      return {
        release_id: r.release_id,
        title: String(m?.title ?? 'Unknown release'),
        artist: String(m?.artist ?? 'Unknown artist'),
        cover_url: m?.cover_url ?? null,
        total_score: score,
        status_code: r.status_code,
        status_label: this.scoreToLabel(score),
        updated_at: r.updated_at,
      };
    });
  }

  // ── Platform search URLs ──────────────────────────────

  platformTarget(platform: string, artist: string, title: string): string {
    const q = encodeURIComponent(`${artist} ${title}`.trim());
    switch (platform) {
      case 'spotify':
        return `https://open.spotify.com/search/${q}`;
      case 'apple':
        return `https://music.apple.com/search?term=${q}`;
      case 'yandex':
        return `https://music.yandex.ru/search?text=${q}`;
      case 'youtube':
        return `https://music.youtube.com/search?q=${q}`;
      default:
        return `https://www.google.com/search?q=${q}`;
    }
  }

  // ── HTML rendering ────────────────────────────────────

  renderSmartLinkPage(release: ReleaseMeta, sessionId: string, releaseId: string): string {
    const artist = release.artist ?? 'Unknown Artist';
    const links = [
      { platform: 'spotify', label: 'Spotify' },
      { platform: 'apple', label: 'Apple Music' },
      { platform: 'yandex', label: 'Яндекс Музыка' },
      { platform: 'youtube', label: 'YouTube Music' },
    ];
    const linksHtml = links
      .map((l) => {
        const url = this.platformTarget(l.platform, artist, release.title);
        return `<a class="btn" href="/aai/click?release_id=${encodeURIComponent(
          String(releaseId),
        )}&platform=${encodeURIComponent(l.platform)}&to=${encodeURIComponent(url)}">${escapeHtml(l.label)}</a>`;
      })
      .join('');

    return `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapeHtml(release.title)} · AURIX</title>
<style>
body{margin:0;background:#07080b;color:#f5f5f5;font-family:Inter,system-ui,sans-serif}
.wrap{max-width:540px;margin:0 auto;padding:24px}
.card{background:#11131a;border:1px solid #232633;border-radius:16px;padding:18px}
.title{font-size:26px;font-weight:800;margin:0 0 4px}
.artist{color:#9ea3b8;margin-bottom:14px}
.grid{display:grid;gap:10px}
.btn{display:block;padding:12px 14px;background:#ff8f00;color:#111;text-decoration:none;border-radius:10px;font-weight:700;text-align:center}
.hint{font-size:12px;color:#7f8498;margin-top:14px}
</style></head>
<body><div class="wrap"><div class="card">
<div class="title">${escapeHtml(release.title)}</div>
<div class="artist">${escapeHtml(artist)}</div>
<div class="grid">${linksHtml}</div>
<div class="hint">Powered by AURIX Attention Index</div>
</div></div>
<script>
const sid=${JSON.stringify(sessionId)};
const releaseId=${JSON.stringify(releaseId)};
window.addEventListener("pagehide", () => {
  const ts=Math.round(performance.now()/1000);
  navigator.sendBeacon("/aai/visit", new Blob([JSON.stringify({
    release_id: releaseId, session_id: sid, event_type: "leave", engaged_seconds: ts
  })], {type:"application/json"}));
});
</script>
</body></html>`;
  }

  renderTopPage(top: any[]): string {
    const rows = top
      .map((x, i) => {
        const score = Number(x.total_score ?? 0).toFixed(1);
        return `<li class="row"><span class="num">${i + 1}</span><span class="meta"><b>${escapeHtml(String(x.title))}</b><small>${escapeHtml(String(x.artist))}</small></span><span class="score">${score}</span><span class="badge">${escapeHtml(String(x.status_label))}</span></li>`;
      })
      .join('');

    return `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>AURIX AAI Top-10</title>
<style>
body{margin:0;background:#07080b;color:#f6f7fb;font-family:Inter,system-ui,sans-serif}
.wrap{max-width:760px;margin:0 auto;padding:24px}
.card{background:#11131a;border:1px solid #232633;border-radius:16px;padding:18px}
h1{margin:0 0 6px;font-size:28px}
.sub{color:#8f94ab;margin-bottom:14px}
ul{list-style:none;padding:0;margin:0;display:grid;gap:10px}
.row{display:grid;grid-template-columns:36px 1fr auto auto;gap:10px;align-items:center;background:#171a23;border:1px solid #252a38;border-radius:12px;padding:10px}
.num{color:#ff8f00;font-weight:800}
.meta{display:flex;flex-direction:column}
.meta small{color:#9da3b7}
.score{font-weight:800}
.badge{font-size:12px;color:#ff8f00}
</style></head><body><div class="wrap"><div class="card">
<h1>AURIX Attention Index</h1><div class="sub">Топ-10 релизов по интересу аудитории</div>
<ul>${rows || '<li>Пока нет данных</li>'}</ul>
</div></div></body></html>`;
  }
}
