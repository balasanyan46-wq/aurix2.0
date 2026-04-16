import { Module, forwardRef } from '@nestjs/common';
import { UsersController, AuthController } from './users.controller';
import { UsersService } from './users.service';
import { AuthModule } from '../auth/auth.module';
import { UserEventsModule } from '../user-events/user-events.module';
import { ReferralModule } from '../referral/referral.module';

@Module({
  imports: [forwardRef(() => AuthModule), UserEventsModule, ReferralModule],
  controllers: [UsersController, AuthController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
