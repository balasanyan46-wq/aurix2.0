import { Module, forwardRef } from '@nestjs/common';
import { UsersController, AuthController } from './users.controller';
import { UsersService } from './users.service';
import { AuthModule } from '../auth/auth.module';
import { UserEventsModule } from '../user-events/user-events.module';

@Module({
  imports: [forwardRef(() => AuthModule), UserEventsModule],
  controllers: [UsersController, AuthController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
