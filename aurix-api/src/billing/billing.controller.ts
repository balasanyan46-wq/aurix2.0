import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  Req,
  Param,
  UseGuards,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { CreditsService } from './credits.service';
import { NotificationsService } from '../notifications/notifications.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class BillingController {
  constructor(
    private readonly credits: CreditsService,
    private readonly notifications: NotificationsService,
  ) {}

  // ── USER ENDPOINTS ───────────────────────────────────────

  /** Get my balance. */
  @Get('billing/balance')
  async myBalance(@Req() req: any) {
    const balance = await this.credits.getBalance(req.user.id);
    return { balance };
  }

  /** Get my transactions. */
  @Get('billing/transactions')
  async myTransactions(
    @Req() req: any,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.credits.getTransactions(req.user.id, +(limit || 50), +(offset || 0));
  }

  /** Check if I can afford an action. */
  @Get('billing/check')
  async check(@Req() req: any, @Query('action') action: string) {
    if (!action) throw new HttpException('action query param required', HttpStatus.BAD_REQUEST);
    const result = await this.credits.canAfford(req.user.id, action);
    return result;
  }

  /** Create a purchase order (user-facing). */
  @Post('billing/create-order')
  async createOrder(@Req() req: any, @Body() body: { credits: number; price_label?: string }) {
    if (!body.credits || body.credits <= 0) {
      throw new HttpException('credits required (positive integer)', HttpStatus.BAD_REQUEST);
    }
    const result = await this.credits.createOrder(
      req.user.id,
      body.credits,
      body.price_label || `${body.credits} кредитов`,
    );
    return result;
  }

  /**
   * Confirm payment for an order.
   * SECURITY: only admin can confirm orders (payment verification happens externally).
   */
  @Post('billing/confirm')
  @UseGuards(AdminGuard)
  async confirmOrder(@Req() req: any, @Body() body: { orderId: string; userId?: number }) {
    if (!body.orderId) {
      throw new HttpException('orderId required', HttpStatus.BAD_REQUEST);
    }
    // Admin confirms on behalf of the order owner, not themselves
    const targetUserId = body.userId ?? req.user.id;
    const result = await this.credits.confirmOrder(targetUserId, body.orderId);
    if (!result.ok) {
      throw new HttpException(result.error || 'Payment confirmation failed', HttpStatus.BAD_REQUEST);
    }
    return result;
  }

  /** Get my orders. */
  @Get('billing/orders')
  async myOrders(@Req() req: any) {
    return this.credits.getOrders(req.user.id);
  }

  /** Get credit costs (public). */
  @Get('billing/costs')
  async costs() {
    return this.credits.getCosts();
  }

  /** Get plan credits (public). */
  @Get('billing/plans')
  async plans() {
    return this.credits.getPlanCredits();
  }

  // ── ADMIN ENDPOINTS ──────────────────────────────────────

  /** Admin: get user balance. */
  @Get('admin/billing/balance/:userId')
  @UseGuards(AdminGuard)
  async adminBalance(@Param('userId') userId: string) {
    const balance = await this.credits.getBalance(+userId);
    return { user_id: +userId, balance };
  }

  /** Admin: give bonus credits. */
  @Post('admin/billing/bonus')
  @UseGuards(AdminGuard)
  async adminBonus(@Req() req: any, @Body() body: { user_id: number; amount: number; reason?: string }) {
    if (!body.user_id || !body.amount) {
      throw new HttpException('user_id and amount required', HttpStatus.BAD_REQUEST);
    }
    const result = await this.credits.topup(body.user_id, body.amount, 'bonus', body.reason || `Бонус от админа`);

    // Log admin action
    await this.credits['pool'].query(
      `INSERT INTO admin_logs (admin_id, action, target_type, target_id, details)
       VALUES ($1, 'credit_bonus', 'user', $2, $3)`,
      [req.user.id, String(body.user_id), JSON.stringify({ amount: body.amount, reason: body.reason })],
    );

    // Notify user about bonus credits
    this.notifications.send({
      user_id: body.user_id,
      title: 'Начислены бонусные кредиты',
      message: `Вам начислено ${body.amount} кредитов${body.reason ? `: ${body.reason}` : ''}`,
      type: 'success',
      meta: { amount: body.amount, reason: body.reason },
    }).catch(() => {});

    return { ok: true, balance: result.balance, transactionId: result.transactionId };
  }

  /** Admin: grant plan credits manually. */
  @Post('admin/billing/grant-plan')
  @UseGuards(AdminGuard)
  async adminGrantPlan(@Body() body: { user_id: number; plan: string }) {
    if (!body.user_id || !body.plan) {
      throw new HttpException('user_id and plan required', HttpStatus.BAD_REQUEST);
    }
    const result = await this.credits.grantPlanCredits(body.user_id, body.plan);

    this.notifications.send({
      user_id: body.user_id,
      title: 'Начислены кредиты по плану',
      message: `Вам начислено ${result.granted} кредитов по плану «${body.plan}»`,
      type: 'success',
      meta: { plan: body.plan, granted: result.granted },
    }).catch(() => {});

    return { ok: true, balance: result.balance, granted: result.granted };
  }

  /** Admin: all transactions. */
  @Get('admin/billing/transactions')
  @UseGuards(AdminGuard)
  async adminTransactions(
    @Query('user_id') userId?: string,
    @Query('type') type?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.credits.allTransactions({
      userId: userId ? +userId : undefined,
      type,
      limit: +(limit || 100),
      offset: +(offset || 0),
    });
  }

  /** Admin: credit stats. */
  @Get('admin/billing/stats')
  @UseGuards(AdminGuard)
  async adminStats() {
    return this.credits.stats();
  }

  /** Admin: all orders. */
  @Get('admin/billing/orders')
  @UseGuards(AdminGuard)
  async adminOrders(
    @Query('status') status?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.credits.allOrders({ status, limit: +(limit || 50), offset: +(offset || 0) });
  }

  /** Admin: get/update costs config. */
  @Get('admin/billing/costs')
  @UseGuards(AdminGuard)
  async adminCosts() {
    return this.credits.getCosts();
  }

  @Post('admin/billing/costs')
  @UseGuards(AdminGuard)
  async adminUpdateCost(@Body() body: { action_key: string; cost: number }) {
    if (!body.action_key || body.cost == null) {
      throw new HttpException('action_key and cost required', HttpStatus.BAD_REQUEST);
    }
    await this.credits.updateCost(body.action_key, body.cost);
    return { ok: true };
  }

  /** Admin: set user balance directly (for support). */
  @Post('admin/billing/set-balance')
  @UseGuards(AdminGuard)
  async adminSetBalance(@Req() req: any, @Body() body: { user_id: number; credits: number }) {
    if (!body.user_id || body.credits == null) {
      throw new HttpException('user_id and credits required', HttpStatus.BAD_REQUEST);
    }

    const current = await this.credits.getBalance(body.user_id);
    const diff = body.credits - current;

    if (diff > 0) {
      await this.credits.topup(body.user_id, diff, 'bonus', `Админ установил баланс: ${body.credits}`);
    } else if (diff < 0) {
      // Direct set for decrease
      await this.credits['pool'].query(
        'UPDATE user_balance SET credits = $2, updated_at = now() WHERE user_id = $1',
        [body.user_id, body.credits],
      );
      await this.credits['pool'].query(
        `INSERT INTO credit_transactions (user_id, type, amount, balance_after, reason)
         VALUES ($1, 'spend', $2, $3, 'Админ установил баланс')`,
        [body.user_id, diff, body.credits],
      );
    }

    // Notify user about balance change
    this.notifications.send({
      user_id: body.user_id,
      title: 'Баланс изменён',
      message: `Ваш баланс установлен: ${body.credits} кредитов`,
      type: 'system',
      meta: { new_balance: body.credits },
    }).catch(() => {});

    return { ok: true, balance: body.credits };
  }
}
