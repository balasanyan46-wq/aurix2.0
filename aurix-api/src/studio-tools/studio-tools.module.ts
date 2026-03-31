import { Module } from '@nestjs/common';
import { StudioToolsController } from './studio-tools.controller';
import { StudioToolsService } from './studio-tools.service';
import { DatabaseModule } from '../database/database.module';
import { AiModule } from '../ai/ai.module';

@Module({
  imports: [DatabaseModule, AiModule],
  controllers: [StudioToolsController],
  providers: [StudioToolsService],
})
export class StudioToolsModule {}
