import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  Req,
  UseGuards,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { ProfilesService } from './profiles.service';
import { UsersService } from '../users/users.service';
import { CreditsService } from '../billing/credits.service';

@UseGuards(JwtAuthGuard)
@Controller('profiles')
export class ProfilesController {
  constructor(
    private readonly profilesService: ProfilesService,
    private readonly usersService: UsersService,
    private readonly creditsService: CreditsService,
  ) {}

  @Get('me')
  async getMe(@Req() req: any) {
    const userId = req.user.id.toString();
    let profile = await this.profilesService.findByUserId(userId);

    if (!profile) {
      // Pull full user data (including phone) from users table
      const fullUser = await this.usersService.findById(req.user.id);
      profile = await this.profilesService.create(userId, {
        email: req.user.email,
        name: fullUser?.name || req.user.name || undefined,
        phone: (fullUser as any)?.phone || undefined,
      });
    }

    // Attach credit balance
    const balance = await this.creditsService.getBalance(req.user.id);
    return { success: true, profile, credits: balance };
  }

  @Put('me')
  async updateMe(@Req() req: any, @Body() body: Record<string, any>) {
    const userId = req.user.id.toString();

    let profile = await this.profilesService.findByUserId(userId);
    if (!profile) {
      profile = await this.profilesService.create(userId, {
        email: req.user.email,
        ...body,
      });
    } else {
      profile = await this.profilesService.update(userId, body);
    }

    return { success: true, profile };
  }

  @Get(':id')
  @UseGuards(AdminGuard)
  async getById(@Param('id') id: string) {
    let profile = await this.profilesService.findByUserId(id);
    if (!profile) {
      // id might be an artist_id — resolve via artists table
      const artist = await this.profilesService.findArtistById(+id);
      if (artist?.user_id) {
        profile = await this.profilesService.findByUserId(String(artist.user_id));
      }
    }
    return { success: true, profile: profile || null };
  }

  @Get()
  @UseGuards(AdminGuard)
  async getAll() {
    const profiles = await this.profilesService.getAll();
    return { success: true, profiles };
  }

  @Put(':userId/role')
  @UseGuards(AdminGuard)
  async updateRole(
    @Param('userId') userId: string,
    @Body('role') role: string,
  ) {
    if (!role) {
      throw new HttpException('role is required', HttpStatus.BAD_REQUEST);
    }

    const profile = await this.profilesService.updateRole(userId, role);
    if (!profile) {
      throw new HttpException('profile not found', HttpStatus.NOT_FOUND);
    }

    return { success: true, profile };
  }

  @Put(':userId/subscription')
  @UseGuards(AdminGuard)
  async updateSubscription(
    @Param('userId') userId: string,
    @Body() body: { plan_id: string; subscription_status: string; subscription_end: string },
  ) {
    const { plan_id, subscription_status, subscription_end } = body;
    if (!plan_id || !subscription_status) {
      throw new HttpException(
        'plan_id and subscription_status are required',
        HttpStatus.BAD_REQUEST,
      );
    }

    const profile = await this.profilesService.updateSubscription(userId, {
      plan: plan_id,
      plan_id,
      subscription_status,
      subscription_end,
    });
    if (!profile) {
      throw new HttpException('profile not found', HttpStatus.NOT_FOUND);
    }

    // Auto-grant credits when plan is activated
    let creditsGranted = 0;
    if (subscription_status === 'active') {
      const grant = await this.creditsService.grantPlanCredits(+userId, plan_id);
      creditsGranted = grant.granted;
    }

    return { success: true, profile, credits_granted: creditsGranted };
  }

  @Put(':userId/status')
  @UseGuards(AdminGuard)
  async updateAccountStatus(
    @Param('userId') userId: string,
    @Body('account_status') status: string,
  ) {
    if (!status) {
      throw new HttpException(
        'account_status is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    const profile = await this.profilesService.updateAccountStatus(
      userId,
      status,
    );
    if (!profile) {
      throw new HttpException('profile not found', HttpStatus.NOT_FOUND);
    }

    return { success: true, profile };
  }

  @Post('bulk-status')
  @UseGuards(AdminGuard)
  async bulkStatus(
    @Body() body: { user_ids: string[]; account_status: string },
  ) {
    const results: any[] = [];
    for (const uid of body.user_ids) {
      const p = await this.profilesService.updateAccountStatus(
        uid,
        body.account_status,
      );
      if (p) results.push(p);
    }
    return { success: true, updated: results.length };
  }
}
