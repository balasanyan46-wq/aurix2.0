import { Module } from '@nestjs/common';
import { SalesCronService } from './sales-cron.service';
import { LeadScoringModule } from '../lead-scoring/lead-scoring.module';
import { AiSalesModule } from '../ai-sales/ai-sales.module';
import { NextActionModule } from '../next-action/next-action.module';
// LeadsModule подключен глобально

@Module({
  imports: [LeadScoringModule, AiSalesModule, NextActionModule],
  providers: [SalesCronService],
})
export class SalesCronModule {}
