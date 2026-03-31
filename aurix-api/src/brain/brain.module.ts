import { Module } from '@nestjs/common';
import { BrainController } from './brain.controller';
import { BrainService } from './brain.service';
import { AiModule } from '../ai/ai.module';

@Module({
  imports: [AiModule],
  controllers: [BrainController],
  providers: [BrainService],
  exports: [BrainService],
})
export class BrainModule {}
