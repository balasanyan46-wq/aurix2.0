import { Module } from '@nestjs/common';
import { AiSalesService } from './ai-sales.service';
import { AiSalesController } from './ai-sales.controller';
import { AiModule } from '../ai/ai.module';

@Module({
  imports: [AiModule], // нужен AiGatewayService
  controllers: [AiSalesController],
  providers: [AiSalesService],
  exports: [AiSalesService], // используется Action Center
})
export class AiSalesModule {}
