import { Module, Global } from '@nestjs/common';
import { GrowthService } from './growth.service';
import { GrowthController } from './growth.controller';
import { PublicProfileController } from './public-profile.controller';

@Global()
@Module({
  controllers: [GrowthController, PublicProfileController],
  providers: [GrowthService],
  exports: [GrowthService],
})
export class GrowthModule {}
