import { Module } from '@nestjs/common';
import { AdminLogsController } from './admin-logs.controller';
import { AdminLogsService } from './admin-logs.service';
import { SystemModule } from '../system/system.module';

@Module({
  imports: [SystemModule],
  controllers: [AdminLogsController],
  providers: [AdminLogsService],
})
export class AdminLogsModule {}
