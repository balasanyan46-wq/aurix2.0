import { Module } from '@nestjs/common';
import { StudioToolsController } from './studio-tools.controller';
import { StudioToolsService } from './studio-tools.service';
import { DatabaseModule } from '../database/database.module';

@Module({
  imports: [DatabaseModule],
  controllers: [StudioToolsController],
  providers: [StudioToolsService],
})
export class StudioToolsModule {}
