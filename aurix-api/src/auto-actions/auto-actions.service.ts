import { Injectable, Inject, Logger } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { NotificationsService } from '../notifications/notifications.service';

interface AutoAction {
  id: number;
  name: string | null;
  description: string | null;
  trigger_type: string;
  event_type: string | null;
  condition: Record<string, any>;
  action_type: string;
  payload: Record<string, any>;
  is_active: boolean;
}

@Injectable()
export class AutoActionsService {
  private readonly log = new Logger('AutoActions');
  private rules: AutoAction[] = [];

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly notifications: NotificationsService,
  ) {
    this.loadRules();
  }

  /** Reload rules from DB. */
  async loadRules() {
    const { rows } = await this.pool.query(
      'SELECT * FROM auto_actions WHERE is_active = true ORDER BY id',
    );
    this.rules = rows;
    this.log.log(`Loaded ${this.rules.length} active auto-action rules`);
  }

  // ── EVENT HANDLER — called from UserEventsService ──────

  /**
   * Process a new user event against all active rules.
   * Called fire-and-forget from event logging.
   */
  async processEvent(userId: number, event: string, meta?: Record<string, any>) {
    for (const rule of this.rules) {
      try {
        if (await this.matches(rule, userId, event, meta)) {
          await this.execute(rule, userId, event);
        }
      } catch (err) {
        this.log.error(`Rule ${rule.id} error: ${err}`);
        await this.logExecution(rule.id, userId, event, 'error', { error: String(err) });
      }
    }
  }

  /** Check if a rule matches the current event. */
  private async matches(rule: AutoAction, userId: number, event: string, meta?: Record<string, any>): Promise<boolean> {
    // Event type match
    if (rule.event_type && rule.event_type !== event) return false;

    switch (rule.trigger_type) {
      case 'event':
      case 'success':
        // Direct event match — just fire
        return true;

      case 'error':
        if (event !== 'error' && !event.includes('error')) return false;
        // Check error count threshold
        const minErrors = rule.condition.min_errors || 3;
        const windowH = rule.condition.window_hours || 1;
        const { rows: errRows } = await this.pool.query(
          `SELECT count(*)::int AS c FROM user_events
           WHERE user_id = $1 AND event LIKE '%error%'
           AND created_at >= now() - ($2 || ' hours')::interval`,
          [userId, windowH],
        );
        return errRows[0].c >= minErrors;

      case 'inactivity':
        // This is handled by the cron check, not by event processing
        return false;

      case 'drop_off':
        // Check if user has events on specific screen but didn't complete
        const screen = rule.condition.screen;
        if (!screen) return false;
        if (meta?.screen !== screen) return false;
        // If the event is a "leave" or "abandon" type, trigger
        return event === 'screen_leave' || event === 'session_end';

      default:
        return false;
    }
  }

  /** Execute the rule's action. */
  private async execute(rule: AutoAction, userId: number, triggerEvent: string) {
    switch (rule.action_type) {
      case 'notify':
        await this.notifications.send({
          user_id: userId,
          title: rule.payload.title || 'Уведомление',
          message: rule.payload.message || '',
          type: rule.payload.type || 'system',
          meta: { auto_action_id: rule.id },
        });
        break;

      case 'create_ticket':
        await this.pool.query(
          `INSERT INTO support_tickets (user_id, subject, message, priority)
           VALUES ($1, $2, $3, $4)`,
          [userId, rule.payload.subject || 'Автотикет', rule.payload.message || `Триггер: ${triggerEvent}`, rule.payload.priority || 'medium'],
        );
        break;

      case 'bonus':
        // Log bonus — actual credit system can be added later
        await this.notifications.send({
          user_id: userId,
          title: rule.payload.title || 'Бонус!',
          message: rule.payload.message || 'Вам начислен бонус.',
          type: 'success',
          meta: { auto_action_id: rule.id, bonus: rule.payload.bonus },
        });
        break;

      case 'email':
        // Future: integrate with MailService
        this.log.log(`[email action] Would send email to user ${userId}: ${rule.payload.subject}`);
        break;

      case 'assign_operator':
        this.log.log(`[assign_operator] Would assign operator to user ${userId}`);
        break;
    }

    // Update execution count
    await this.pool.query(
      'UPDATE auto_actions SET executions = executions + 1, last_fired_at = now() WHERE id = $1',
      [rule.id],
    );

    await this.logExecution(rule.id, userId, triggerEvent, 'ok');
    this.log.log(`Rule ${rule.id} (${rule.name}) fired for user ${userId}`);
  }

  /** Log rule execution. */
  private async logExecution(actionId: number, userId: number, event: string, result: string, details?: any) {
    await this.pool.query(
      `INSERT INTO auto_action_log (action_id, user_id, trigger_event, result, details)
       VALUES ($1,$2,$3,$4,$5)`,
      [actionId, userId, event, result, details ? JSON.stringify(details) : null],
    );
  }

  // ── INACTIVITY CHECK (called periodically or from admin) ──

  /** Check all users for inactivity and fire rules. */
  async checkInactivity() {
    const inactiveRules = this.rules.filter(r => r.trigger_type === 'inactivity');
    if (!inactiveRules.length) return { checked: 0, fired: 0 };

    let fired = 0;
    for (const rule of inactiveRules) {
      const hours = rule.condition.inactive_hours || 24;
      // Find users who have events but none in the last N hours
      // AND haven't already been notified by this rule in the last 48h
      const { rows } = await this.pool.query(`
        SELECT DISTINCT ue.user_id
        FROM user_events ue
        WHERE ue.user_id NOT IN (
          SELECT DISTINCT user_id FROM user_events WHERE created_at >= now() - ($1 || ' hours')::interval
        )
        AND ue.user_id NOT IN (
          SELECT user_id FROM auto_action_log WHERE action_id = $2 AND created_at >= now() - interval '48 hours'
        )
        AND ue.created_at >= now() - interval '30 days'
        LIMIT 100
      `, [hours, rule.id]);

      for (const row of rows) {
        await this.execute(rule, row.user_id, 'inactivity');
        fired++;
      }
    }

    return { checked: inactiveRules.length, fired };
  }

  // ── CRUD for admin ────────────────────────────────────────

  async list() {
    const { rows } = await this.pool.query('SELECT * FROM auto_actions ORDER BY id');
    return rows;
  }

  async getLog(opts: { actionId?: number; userId?: number; limit?: number }) {
    let q = 'SELECT * FROM auto_action_log WHERE 1=1';
    const p: any[] = [];
    if (opts.actionId) { p.push(opts.actionId); q += ` AND action_id = $${p.length}`; }
    if (opts.userId) { p.push(opts.userId); q += ` AND user_id = $${p.length}`; }
    q += ' ORDER BY created_at DESC';
    p.push(opts.limit || 50); q += ` LIMIT $${p.length}`;
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async create(data: Partial<AutoAction>) {
    const { rows } = await this.pool.query(
      `INSERT INTO auto_actions (trigger_type, event_type, condition, action_type, payload, name, description, is_active)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [data.trigger_type, data.event_type || null, JSON.stringify(data.condition || {}), data.action_type, JSON.stringify(data.payload || {}), (data as any).name || null, (data as any).description || null, data.is_active !== false],
    );
    await this.loadRules();
    return rows[0];
  }

  async update(id: number, data: Partial<AutoAction>) {
    const sets: string[] = [];
    const vals: any[] = [];
    let i = 1;
    const allowed = ['trigger_type', 'event_type', 'action_type', 'name', 'description', 'is_active'];
    for (const [k, v] of Object.entries(data)) {
      if (allowed.includes(k)) { sets.push(`${k} = $${i++}`); vals.push(v); }
    }
    if (data.condition) { sets.push(`condition = $${i++}`); vals.push(JSON.stringify(data.condition)); }
    if (data.payload) { sets.push(`payload = $${i++}`); vals.push(JSON.stringify(data.payload)); }
    if (!sets.length) return null;
    vals.push(id);
    const { rows } = await this.pool.query(
      `UPDATE auto_actions SET ${sets.join(', ')} WHERE id = $${i} RETURNING *`, vals,
    );
    await this.loadRules();
    return rows[0];
  }

  async delete(id: number) {
    await this.pool.query('DELETE FROM auto_actions WHERE id = $1', [id]);
    await this.loadRules();
  }
}
