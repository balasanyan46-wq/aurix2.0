import { Module } from '@nestjs/common';
import { AiController } from './ai.controller';
import { AiGatewayService } from './ai-gateway.service';
import { DnkService } from './dnk.service';
import { DnkTestsService } from './dnk-tests.service';
import { AiContextService } from './ai-context.service';
import { AiProfileService } from './ai-profile.service';
import { CoverService } from './cover.service';
import { AudioAnalysisService } from './audio-analysis.service';
import { ImprovedTrackService } from './analysis/improved-track.service';

@Module({
  controllers: [AiController],
  providers: [AiGatewayService, DnkService, DnkTestsService, AiContextService, AiProfileService, CoverService, AudioAnalysisService, ImprovedTrackService],
  exports: [AiGatewayService, DnkService, DnkTestsService, AiContextService, AiProfileService, CoverService, AudioAnalysisService, ImprovedTrackService],
})
export class AiModule {}
