import { Module } from '@nestjs/common';
import { TBankService } from './tbank.service';
import { PaymentsController } from './payments.controller';
import { SubscriptionCronService } from './subscription-cron.service';
import { PlanLimitGuard } from './plan-limit.guard';
import { NotificationsModule } from '../notifications/notifications.module';
import { ReferralModule } from '../referral/referral.module';

@Module({
  imports: [NotificationsModule, ReferralModule],
  controllers: [PaymentsController],
  providers: [TBankService, SubscriptionCronService, PlanLimitGuard],
  exports: [TBankService, PlanLimitGuard],
})
export class PaymentsModule {}
