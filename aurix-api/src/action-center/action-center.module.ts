import { Module } from '@nestjs/common';
import { ActionCenterController } from './action-center.controller';
import { LeadScoringModule } from '../lead-scoring/lead-scoring.module';
import { NextActionModule } from '../next-action/next-action.module';
import { AiSalesModule } from '../ai-sales/ai-sales.module';

@Module({
  imports: [
    LeadScoringModule,    // hot leads from profiles.lead_bucket
    NextActionModule,     // next_action engine для users_with_next_action
    AiSalesModule,        // ai_sales_signals = high
    // LeadsModule подключен глобально
  ],
  controllers: [ActionCenterController],
})
export class ActionCenterModule {}
