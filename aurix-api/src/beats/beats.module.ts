import { Module } from '@nestjs/common';
import { BeatsController } from './beats.controller';
import { BeatsService } from './beats.service';
import { ReferralModule } from '../referral/referral.module';

@Module({
  imports: [ReferralModule],
  controllers: [BeatsController],
  providers: [BeatsService],
  exports: [BeatsService],
})
export class BeatsModule {}
