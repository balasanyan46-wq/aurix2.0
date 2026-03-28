import { Module, Global } from '@nestjs/common';
import { CreditsService } from './credits.service';
import { CreditGuard } from './credit.guard';
import { BillingController } from './billing.controller';

@Global() // Global so CreditGuard and CreditsService are available everywhere
@Module({
  controllers: [BillingController],
  providers: [CreditsService, CreditGuard],
  exports: [CreditsService, CreditGuard],
})
export class BillingModule {}
