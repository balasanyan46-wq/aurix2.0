import { Module } from '@nestjs/common';
import { AdminLogsController } from './admin-logs.controller';
import { AdminLogsService } from './admin-logs.service';
import { SystemModule } from '../system/system.module';
import { AiModule } from '../ai/ai.module';

@Module({
  imports: [SystemModule, AiModule],
  controllers: [AdminLogsController],
  providers: [AdminLogsService],
})
export class AdminLogsModule {}
