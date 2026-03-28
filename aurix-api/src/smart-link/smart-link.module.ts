import { Module } from '@nestjs/common';
import { SmartLinkController } from './smart-link.controller';
import { SmartLinkService } from './smart-link.service';

@Module({
  controllers: [SmartLinkController],
  providers: [SmartLinkService],
})
export class SmartLinkModule {}
