import { Module } from '@nestjs/common';
import { ReleasesController } from './releases.controller';
import { ReleasesService } from './releases.service';
import { ArtistsModule } from '../artists/artists.module';
import { UsersModule } from '../users/users.module';
import { UserEventsModule } from '../user-events/user-events.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [ArtistsModule, UsersModule, UserEventsModule, NotificationsModule],
  controllers: [ReleasesController],
  providers: [ReleasesService],
  exports: [ReleasesService],
})
export class ReleasesModule {}
