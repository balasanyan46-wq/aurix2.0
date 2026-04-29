import { Module, forwardRef } from '@nestjs/common';
import { LeadScoringService } from './lead-scoring.service';
import { LeadScoringController } from './lead-scoring.controller';
import { LeadsModule } from '../leads/leads.module';

// forwardRef: LeadsModule.imports → LeadScoringModule (для explainer),
// LeadScoringModule.imports → LeadsModule (для ensureLead). Цикл разруливаем.
@Module({
  imports: [forwardRef(() => LeadsModule)],
  controllers: [LeadScoringController],
  providers: [LeadScoringService],
  exports: [LeadScoringService],
})
export class LeadScoringModule {}
