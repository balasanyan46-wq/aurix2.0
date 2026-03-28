import { Module } from '@nestjs/common';
import { ReleaseMetadataController } from './release-metadata.controller';
import { ReleaseMetadataService } from './release-metadata.service';
import { ReleasesModule } from '../releases/releases.module';
import { ArtistsModule } from '../artists/artists.module';
import { DatabaseModule } from '../database/database.module';

@Module({
  imports: [ReleasesModule, ArtistsModule, DatabaseModule],
  controllers: [ReleaseMetadataController],
  providers: [ReleaseMetadataService],
  exports: [ReleaseMetadataService],
})
export class ReleaseMetadataModule {}
