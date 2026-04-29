import { Module, Global } from '@nestjs/common';
import { SalesAlertsService } from './sales-alerts.service';
import { TelegramModule } from '../telegram/telegram.module';

// @Global, чтобы TBankService мог инжектить SalesAlertsService через @Optional
// без явного import — payments.module.ts не импортирует sales-alerts напрямую.
@Global()
@Module({
  imports: [TelegramModule],
  providers: [SalesAlertsService],
  exports: [SalesAlertsService],
})
export class SalesAlertsModule {}
