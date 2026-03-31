import {
  Injectable,
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { TBankService } from './tbank.service';

export const LIMIT_TYPE_KEY = 'plan_limit_type';

/**
 * Decorator: @PlanLimit('ai_requests') / @PlanLimit('video_gen') / @PlanLimit('analytics_q')
 * Attach to controller methods that consume a limited resource.
 */
export const PlanLimit = (limitType: 'ai_requests' | 'video_gen' | 'analytics_q') =>
  SetMetadata(LIMIT_TYPE_KEY, limitType);

@Injectable()
export class PlanLimitGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly tbank: TBankService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const limitType = this.reflector.getAllAndOverride<string>(LIMIT_TYPE_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!limitType) return true; // No limit annotation — allow

    const request = context.switchToHttp().getRequest();
    const userId = request.user?.id;
    if (!userId) return true; // No auth — let JwtAuthGuard handle

    const check = await this.tbank.checkUsageLimit(
      userId,
      limitType as 'ai_requests' | 'video_gen' | 'analytics_q',
    );

    if (!check.allowed) {
      throw new HttpException(
        {
          error: 'plan_limit_exceeded',
          message: `Лимит плана исчерпан: ${limitType}`,
          used: check.used,
          limit: check.limit,
          remaining: 0,
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // Increment usage counter
    await this.tbank.incrementUsage(
      userId,
      limitType as 'ai_requests' | 'video_gen' | 'analytics_q',
    );

    return true;
  }
}
