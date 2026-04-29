import { Module, Global, forwardRef } from '@nestjs/common';
import { LeadsService } from './leads.service';
import { LeadsController } from './leads.controller';
import { LeadScoringModule } from '../lead-scoring/lead-scoring.module';
import { NextActionModule } from '../next-action/next-action.module';

// @Global — LeadsService используется из payments/lead-scoring/action-center/
// next-action/ai-sales. Глобальная регистрация избавляет от @Optional + явных
// импортов в каждом модуле.
//
// forwardRef для LeadScoringModule, потому что lead-scoring импортирует Leads
// (для ensureLead) — образуется цикл, который Nest резолвит через forwardRef.
@Global()
@Module({
  imports: [
    forwardRef(() => LeadScoringModule),
    NextActionModule,
  ],
  controllers: [LeadsController],
  providers: [LeadsService],
  exports: [LeadsService],
})
export class LeadsModule {}
