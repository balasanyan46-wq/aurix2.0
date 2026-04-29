import { Module } from '@nestjs/common';
import { StudioToolsController } from './studio-tools.controller';
import { StudioToolsService } from './studio-tools.service';
import { DatabaseModule } from '../database/database.module';
import { AiModule } from '../ai/ai.module';
import { UserEventsModule } from '../user-events/user-events.module';

@Module({
  imports: [DatabaseModule, AiModule, UserEventsModule],
  controllers: [StudioToolsController],
  providers: [StudioToolsService],
})
export class StudioToolsModule {}
