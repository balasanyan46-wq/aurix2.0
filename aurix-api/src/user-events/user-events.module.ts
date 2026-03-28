import { Module, forwardRef } from '@nestjs/common';
import { UserEventsController } from './user-events.controller';
import { UserEventsService } from './user-events.service';
import { AutoActionsModule } from '../auto-actions/auto-actions.module';

@Module({
  imports: [forwardRef(() => AutoActionsModule)],
  controllers: [UserEventsController],
  providers: [UserEventsService],
  exports: [UserEventsService],
})
export class UserEventsModule {}
