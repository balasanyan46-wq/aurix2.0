import {
  Injectable,
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { CreditsService } from './credits.service';

export const CREDIT_ACTION_KEY = 'credit_action';

/**
 * Decorator: mark an endpoint with a credit cost.
 * Usage: @CreditAction('ai_cover')
 */
export const CreditAction = (actionKey: string) =>
  SetMetadata(CREDIT_ACTION_KEY, actionKey);

/**
 * Guard that checks and deducts credits before allowing the request.
 * Attach the @CreditAction('key') decorator to the handler.
 * After deduction, sets req.creditSpend with { cost, balance, transactionId }.
 */
@Injectable()
export class CreditGuard implements CanActivate {
  constructor(
    private readonly credits: CreditsService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const actionKey = this.reflector.get<string>(
      CREDIT_ACTION_KEY,
      context.getHandler(),
    );
    if (!actionKey) return true; // No credit action = pass through

    const req = context.switchToHttp().getRequest();
    const userId = req.user?.id;
    if (!userId) {
      throw new HttpException('Unauthorized', HttpStatus.UNAUTHORIZED);
    }

    const result = await this.credits.spend(userId, actionKey);

    if (!result.ok) {
      throw new HttpException(
        {
          code: 'NO_CREDITS',
          message: 'Недостаточно кредитов. Пополните баланс или обновите тариф.',
          balance: result.balance,
          cost: result.cost,
        },
        HttpStatus.PAYMENT_REQUIRED, // 402
      );
    }

    // Attach spend info to request for downstream use
    req.creditSpend = {
      cost: result.cost,
      balance: result.balance,
      transactionId: result.transactionId,
    };

    return true;
  }
}
