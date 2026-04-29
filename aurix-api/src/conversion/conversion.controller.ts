import { Controller, Get, Inject, UseGuards } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';

/**
 * Conversion Tracking — артистическая воронка с деньгами.
 *
 * Источник: view `v_conversion_funnel` (миграция 091).
 *
 * Возвращает по каждому шагу:
 *   - users_count          — уникальных юзеров
 *   - conversion_pct       — % от предыдущего шага
 *   - drop_off_pct         — % отвалившихся на этом шаге
 *   - revenue_generated    — суммарный revenue юзеров, дошедших сюда (₽)
 */
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller()
export class ConversionController {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  @Get('admin/conversion')
  async funnel() {
    // 1) Counts по шагам.
    const { rows } = await this.pool.query(`SELECT * FROM v_conversion_funnel`)
      .catch(() => ({ rows: [{}] as any[] }));
    const f = rows[0] ?? {};

    const counts = {
      register: Number(f.step1_register ?? 0),
      track_uploaded: Number(f.step2_track_uploaded ?? 0),
      ai_chat: Number(f.step3_ai_chat ?? 0),
      release_created: Number(f.step4_release_created ?? 0),
      payment: Number(f.step5_payment ?? 0),
      repeat: Number(f.step6_repeat ?? 0),
    };
    const totalRevenueKopecks = Number(f.total_revenue_kopecks ?? 0);

    // 2) Revenue по шагам (сколько денег у юзеров, дошедших до шага).
    const { rows: revRows } = await this.pool.query(
      `SELECT step, revenue_kopecks FROM v_conversion_revenue_by_step`,
    ).catch(() => ({ rows: [] as any[] }));
    const revByStep: Record<string, number> = {};
    for (const r of revRows as any[]) {
      revByStep[r.step] = Math.round(Number(r.revenue_kopecks ?? 0) / 100);
    }

    // 3) Сборка структурированного ответа.
    const order: Array<{ key: keyof typeof counts; label: string; revKey?: string }> = [
      { key: 'register', label: 'Регистрация', revKey: 'register' },
      { key: 'track_uploaded', label: 'Загрузил трек', revKey: 'track_uploaded' },
      { key: 'ai_chat', label: 'AI-анализ', revKey: 'ai_chat' },
      { key: 'release_created', label: 'Оформил релиз', revKey: 'release_created' },
      { key: 'payment', label: 'Оплатил' },
      { key: 'repeat', label: 'Вернулся повторно' },
    ];

    const steps = order.map((step, idx) => {
      const usersCount = counts[step.key];
      const prevCount = idx === 0 ? usersCount : counts[order[idx - 1].key];
      const conversionPct = prevCount > 0
        ? Math.round((usersCount / prevCount) * 1000) / 10
        : 0;
      const dropOffPct = idx === 0 ? 0 : Math.round((100 - conversionPct) * 10) / 10;
      return {
        step: step.key,
        label: step.label,
        users_count: usersCount,
        conversion_pct: conversionPct,
        drop_off_pct: dropOffPct,
        revenue_generated_rub: step.revKey ? (revByStep[step.revKey] ?? 0) : 0,
      };
    });

    return {
      ok: true,
      total_revenue_rub: Math.round(totalRevenueKopecks / 100),
      steps,
      generated_at: new Date().toISOString(),
    };
  }
}
