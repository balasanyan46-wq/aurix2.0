import { Module } from '@nestjs/common';
import { NavigatorController } from './navigator.controller';
import { NavigatorService } from './navigator.service';

@Module({
  controllers: [NavigatorController],
  providers: [NavigatorService],
})
export class NavigatorModule {}
