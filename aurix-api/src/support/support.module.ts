import { Module } from '@nestjs/common';
import { SupportController } from './support.controller';
import { SupportService } from './support.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { TelegramModule } from '../telegram/telegram.module';

@Module({
  imports: [NotificationsModule, TelegramModule],
  controllers: [SupportController],
  providers: [SupportService],
})
export class SupportModule {}
