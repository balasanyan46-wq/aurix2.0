import { Module } from '@nestjs/common';
import { PromoController } from './promo.controller';
import { PromoService } from './promo.service';
import { PromoVideoService } from './promo-video.service';
import { FfmpegService } from './ffmpeg.service';
import { UploadModule } from '../upload/upload.module';

@Module({
  imports: [UploadModule],
  controllers: [PromoController],
  providers: [PromoService, PromoVideoService, FfmpegService],
})
export class PromoModule {}
