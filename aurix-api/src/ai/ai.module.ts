import { Module } from '@nestjs/common';
import { AiController } from './ai.controller';
import { EdenAiService } from './eden-ai.service';
import { DnkService } from './dnk.service';
import { DnkTestsService } from './dnk-tests.service';
import { AiContextService } from './ai-context.service';
import { AiProfileService } from './ai-profile.service';
import { CoverService } from './cover.service';
import { AudioAnalysisService } from './audio-analysis.service';

@Module({
  controllers: [AiController],
  providers: [EdenAiService, DnkService, DnkTestsService, AiContextService, AiProfileService, CoverService, AudioAnalysisService],
  exports: [EdenAiService, DnkService, DnkTestsService, AiContextService, AiProfileService, CoverService, AudioAnalysisService],
})
export class AiModule {}
