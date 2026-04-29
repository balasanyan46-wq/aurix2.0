import { Injectable, Inject, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { LeadScoringService } from '../lead-scoring/lead-scoring.service';
import { LeadsService } from '../leads/leads.service';
import { AiSalesService } from '../ai-sales/ai-sales.service';

/**
 * Sales-Cron — расписание регулярных задач sales-pipeline.
 *
 * Все cron'ы пишут результат в admin_logs с action='cron_<task>' и details
 * в JSON, чтобы последующий аудит мог посмотреть «когда что отработало».
 *
 * Важно: каждый cron поглощает свои ошибки — один сбой не должен ронять
 * весь процесс. Запускаем последовательно (не параллельно), чтобы не
 * перегружать DB и AI-квоты.
 */
@Injectable()
export class SalesCronService {
  private readonly log = new Logger(SalesCronService.name);

  // Простые in-memory locks: защита от наложения, если предыдущий запуск
  // ещё не завершился (например, recalc большой базы > 30 минут).
  private locks = {
    leadScoring: false,
    leadsSweep: false,
    aiSales: false,
  };

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly leadScoring: LeadScoringService,
    private readonly leads: LeadsService,
    private readonly aiSales: AiSalesService,
  ) {}

  /**
   * Lead Scoring: каждые 30 минут пересчитывает активных за 30 дней.
   * `recalculateAll` уже фильтрует по активности.
   *
   * Cron-выражение: 0,30 * * * * (каждые 30 минут на 0-й и 30-й секунде).
   * NestJS @nestjs/schedule поддерживает 5- и 6-полевые выражения; здесь
   * 6-полевое для точности.
   */
  @Cron('0 */30 * * * *', { name: 'lead_scoring_recalc' })
  async cronLeadScoringRecalc() {
    if (this.locks.leadScoring) {
      this.log.warn('cronLeadScoringRecalc: previous run still in progress, skipping');
      return;
    }
    this.locks.leadScoring = true;
    const startedAt = Date.now();
    try {
      const result = await this.leadScoring.recalculateAll('cron_30m');
      const durationMs = Date.now() - startedAt;
      this.log.log(`Lead scoring recalc: ${result.recalculated} users in ${durationMs}ms`);
      await this.writeAuditLog('cron_lead_scoring_recalc', {
        recalculated: result.recalculated,
        duration_ms: durationMs,
        errors: 0,
      });
    } catch (e: any) {
      this.log.error(`cronLeadScoringRecalc failed: ${e.message}`);
      await this.writeAuditLog('cron_lead_scoring_recalc', {
        error: e.message,
        duration_ms: Date.now() - startedAt,
      });
    } finally {
      this.locks.leadScoring = false;
    }
  }

  /**
   * Leads Sweep Stale: ежедневно в 03:00.
   * Помечает 'lost' все leads без активности 14+ дней.
   */
  @Cron(CronExpression.EVERY_DAY_AT_3AM, { name: 'leads_sweep_stale' })
  async cronLeadsSweepStale() {
    if (this.locks.leadsSweep) return;
    this.locks.leadsSweep = true;
    const startedAt = Date.now();
    try {
      const result = await this.leads.sweepStale();
      const durationMs = Date.now() - startedAt;
      this.log.log(`Leads sweep: ${result.lost} lost in ${durationMs}ms`);
      await this.writeAuditLog('cron_leads_sweep_stale', {
        lost: result.lost,
        duration_ms: durationMs,
      });
    } catch (e: any) {
      this.log.error(`cronLeadsSweepStale failed: ${e.message}`);
      await this.writeAuditLog('cron_leads_sweep_stale', {
        error: e.message,
        duration_ms: Date.now() - startedAt,
      });
    } finally {
      this.locks.leadsSweep = false;
    }
  }

  /**
   * AI Sales Refresh: каждые 4 часа.
   * Анализирует top-30 active/hot users с cooldown'ом 24 часа.
   * Дорогая операция — крутим аккуратно.
   */
  @Cron(CronExpression.EVERY_4_HOURS, { name: 'ai_sales_refresh' })
  async cronAiSalesRefresh() {
    if (this.locks.aiSales) {
      this.log.warn('cronAiSalesRefresh: previous run still in progress, skipping');
      return;
    }
    this.locks.aiSales = true;
    const startedAt = Date.now();
    try {
      const result = await this.aiSales.refreshTopActiveWithCooldown();
      const durationMs = Date.now() - startedAt;
      this.log.log(
        `AI sales refresh: ${result.analyzed} analyzed, ${result.skipped_cooldown} skipped (cooldown), ${result.errors} errors in ${durationMs}ms`,
      );
      await this.writeAuditLog('cron_ai_sales_refresh', {
        analyzed: result.analyzed,
        skipped_cooldown: result.skipped_cooldown,
        errors: result.errors,
        duration_ms: durationMs,
      });
    } catch (e: any) {
      this.log.error(`cronAiSalesRefresh failed: ${e.message}`);
      await this.writeAuditLog('cron_ai_sales_refresh', {
        error: e.message,
        duration_ms: Date.now() - startedAt,
      });
    } finally {
      this.locks.aiSales = false;
    }
  }

  /**
   * Утилита: запись результата cron в admin_logs.
   *
   * admin_id = NULL (это системный исполнитель, не админ).
   * action = 'cron_*' — фильтруется на странице логов.
   * details = JSON с метриками.
   */
  private async writeAuditLog(action: string, details: Record<string, any>): Promise<void> {
    try {
      await this.pool.query(
        `INSERT INTO admin_logs (admin_id, action, target_type, details)
         VALUES (NULL, $1, 'system', $2)`,
        [action, JSON.stringify(details)],
      );
    } catch (e: any) {
      // admin_logs может быть недоступен — не критично для cron.
      this.log.warn(`writeAuditLog(${action}) failed: ${e.message}`);
    }
  }
}
