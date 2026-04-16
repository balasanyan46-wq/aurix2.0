import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class AiToolsService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  // AI Tool Results
  async getLatestResult(userId: number, toolId: string, resourceType?: string, resourceId?: string) {
    let q = 'SELECT * FROM ai_tool_results WHERE user_id=$1 AND tool_id=$2';
    const p: any[] = [userId, toolId];
    if (resourceType) { p.push(resourceType); q += ` AND resource_type=$${p.length}`; }
    if (resourceId) { p.push(resourceId); q += ` AND resource_id=$${p.length}`; }
    q += ' ORDER BY created_at DESC LIMIT 1';
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async saveResult(userId: number, data: Record<string, any>) {
    const { rows } = await this.pool.query(
      `INSERT INTO ai_tool_results (user_id, tool_id, resource_type, resource_id, input, quick_prompt, result_markdown, error_text)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [userId, data.tool_id, data.resource_type||null, data.resource_id||null,
       data.input?JSON.stringify(data.input):null, data.quick_prompt||null, data.result_markdown||null, data.error_text||null],
    );
    return rows[0];
  }

  // AI Studio Messages
  async getMessages(userId: number, limit = 50, generativeType?: string) {
    if (generativeType) {
      // Filter by tool type; 'chat' also matches messages with no generativeType
      const isChat = generativeType === 'chat';
      const { rows } = await this.pool.query(
        `SELECT * FROM ai_studio_messages WHERE user_id=$1
         AND (meta->>'generativeType' = $3${isChat ? " OR meta->>'generativeType' IS NULL OR meta IS NULL" : ''})
         ORDER BY created_at ASC LIMIT $2`,
        [userId, limit, generativeType],
      );
      return rows;
    }
    const { rows } = await this.pool.query(
      'SELECT * FROM ai_studio_messages WHERE user_id=$1 ORDER BY created_at ASC LIMIT $2', [userId, limit],
    );
    return rows;
  }

  async addMessage(userId: number, role: string, content: string, meta?: Record<string, unknown>) {
    const { rows } = await this.pool.query(
      'INSERT INTO ai_studio_messages (user_id, role, content, meta) VALUES ($1,$2,$3,$4) RETURNING *',
      [userId, role, content, meta ? JSON.stringify(meta) : null],
    );
    return rows[0];
  }

  async clearMessages(userId: number, generativeType?: string) {
    if (generativeType) {
      const isChat = generativeType === 'chat';
      await this.pool.query(
        `DELETE FROM ai_studio_messages WHERE user_id=$1
         AND (meta->>'generativeType' = $2${isChat ? " OR meta->>'generativeType' IS NULL OR meta IS NULL" : ''})`,
        [userId, generativeType],
      );
    } else {
      await this.pool.query('DELETE FROM ai_studio_messages WHERE user_id=$1', [userId]);
    }
  }

  // Release Tools
  async getLatestReleaseTool(userId: number, releaseId: number, toolKey: string) {
    const { rows } = await this.pool.query(
      'SELECT * FROM release_tools WHERE user_id=$1 AND release_id=$2 AND tool_key=$3 ORDER BY created_at DESC LIMIT 1',
      [userId, releaseId, toolKey],
    );
    return rows[0] || null;
  }

  async deleteReleaseTool(userId: number, releaseId: number, toolKey: string) {
    await this.pool.query(
      'DELETE FROM release_tools WHERE user_id=$1 AND release_id=$2 AND tool_key=$3',
      [userId, releaseId, toolKey],
    );
  }

  // Growth Plans
  async getLatestGrowthPlan(userId: number, releaseId: number) {
    const { rows } = await this.pool.query(
      'SELECT * FROM release_growth_plans WHERE user_id=$1 AND release_id=$2 ORDER BY created_at DESC LIMIT 1',
      [userId, releaseId],
    );
    return rows[0] || null;
  }

  // Budget Plans
  async getLatestBudget(userId: number, releaseId: number) {
    const { rows } = await this.pool.query(
      'SELECT * FROM release_budgets WHERE user_id=$1 AND release_id=$2 ORDER BY created_at DESC LIMIT 1',
      [userId, releaseId],
    );
    return rows[0] || null;
  }
}
