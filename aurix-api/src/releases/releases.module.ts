import { Module } from '@nestjs/common';
import { ReleasesController } from './releases.controller';
import { ReleasesService } from './releases.service';
import { ArtistsModule } from '../artists/artists.module';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [ArtistsModule, UsersModule],
  controllers: [ReleasesController],
  providers: [ReleasesService],
  exports: [ReleasesService],
})
export class ReleasesModule {}
