import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { CastingController } from './casting.controller';
import { CastingService } from './casting.service';

@Module({
  imports: [DatabaseModule],
  controllers: [CastingController],
  providers: [CastingService],
  exports: [CastingService],
})
export class CastingModule {}
