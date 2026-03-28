import { Module } from '@nestjs/common';
import { AutoActionsController } from './auto-actions.controller';
import { AutoActionsService } from './auto-actions.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [AutoActionsController],
  providers: [AutoActionsService],
  exports: [AutoActionsService],
})
export class AutoActionsModule {}
