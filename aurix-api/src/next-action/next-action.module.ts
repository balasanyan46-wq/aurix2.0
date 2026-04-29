import { Module } from '@nestjs/common';
import { NextActionService } from './next-action.service';
import { NextActionController } from './next-action.controller';

@Module({
  controllers: [NextActionController],
  providers: [NextActionService],
  exports: [NextActionService], // используется Action Center
})
export class NextActionModule {}
