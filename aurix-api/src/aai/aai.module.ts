import { Module } from '@nestjs/common';
import { AaiController } from './aai.controller';
import { AaiService } from './aai.service';

@Module({
  controllers: [AaiController],
  providers: [AaiService],
})
export class AaiModule {}
