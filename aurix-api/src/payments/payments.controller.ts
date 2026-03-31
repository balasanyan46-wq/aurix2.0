import {
  Controller,
  Get,
  Post,
  Body,
  Req,
  Res,
  Query,
  UseGuards,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Response } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { TBankService } from './tbank.service';

@Controller()
export class PaymentsController {
  private readonly log = new Logger('Payments');

  constructor(private readonly tbank: TBankService) {}

  // ── USER ENDPOINTS ──────────────────────────────────

  /**
   * Create a subscription payment and return T-Bank payment URL.
   */
  @Post('payments/create')
  @UseGuards(JwtAuthGuard)
  async createPayment(
    @Req() req: any,
    @Body() body: { plan: string; billingPeriod?: string },
  ) {
    const userId = req.user.id;
    const plan = body.plan?.trim();
    const billingPeriod = body.billingPeriod || 'monthly';

    if (!plan || !['start', 'breakthrough', 'empire'].includes(plan)) {
      throw new HttpException('Invalid plan. Must be: start, breakthrough, or empire', HttpStatus.BAD_REQUEST);
    }

    if (!['monthly', 'yearly'].includes(billingPeriod)) {
      throw new HttpException('Invalid billingPeriod. Must be: monthly or yearly', HttpStatus.BAD_REQUEST);
    }

    const result = await this.tbank.createPayment(userId, plan, billingPeriod);

    if (!result.success) {
      return { success: false, error: result.error };
    }

    return {
      success: true,
      data: {
        paymentUrl: result.paymentUrl,
        orderId: result.orderId,
      },
    };
  }

  /**
   * Alias for Flutter's existing BillingService call.
   */
  @Post('tools/billing-create-checkout-session')
  @UseGuards(JwtAuthGuard)
  async createCheckoutSession(
    @Req() req: any,
    @Body() body: { plan: string; billingPeriod?: string },
  ) {
    const userId = req.user.id;
    const plan = body.plan?.trim();
    const billingPeriod = body.billingPeriod || 'monthly';

    if (!plan || !['start', 'breakthrough', 'empire'].includes(plan)) {
      return { ok: false, error: 'Invalid plan' };
    }

    const result = await this.tbank.createPayment(userId, plan, billingPeriod);

    if (!result.success) {
      return { ok: false, error: result.error };
    }

    return { ok: true, url: result.paymentUrl };
  }

  /**
   * Purchase a credit package (small / medium / large).
   */
  @Post('payments/credits')
  @UseGuards(JwtAuthGuard)
  async purchaseCredits(
    @Req() req: any,
    @Body() body: { package: string },
  ) {
    const userId = req.user.id;
    const packageId = body.package?.trim();

    if (!packageId || !['small', 'medium', 'large'].includes(packageId)) {
      throw new HttpException('Invalid package. Must be: small, medium, or large', HttpStatus.BAD_REQUEST);
    }

    const result = await this.tbank.createCreditsPurchase(userId, packageId);

    if (!result.success) {
      return { success: false, error: result.error };
    }

    return {
      success: true,
      data: {
        paymentUrl: result.paymentUrl,
        orderId: result.orderId,
      },
    };
  }

  /**
   * Cancel subscription at period end.
   */
  @Post('subscription/cancel')
  @UseGuards(JwtAuthGuard)
  async cancelSubscription(@Req() req: any) {
    const result = await this.tbank.cancelSubscription(req.user.id);

    if (!result.success) {
      throw new HttpException(result.error || 'Cannot cancel', HttpStatus.BAD_REQUEST);
    }

    return {
      success: true,
      data: { expiresAt: result.expiresAt },
    };
  }

  /**
   * Reactivate a cancelled subscription (before it expires).
   */
  @Post('subscription/reactivate')
  @UseGuards(JwtAuthGuard)
  async reactivateSubscription(@Req() req: any) {
    const result = await this.tbank.reactivateSubscription(req.user.id);
    return { success: true, data: result };
  }

  /**
   * T-Bank webhook handler.
   * NO auth guard — T-Bank sends server-to-server POST.
   * Signature is verified inside the service.
   */
  @Post('payments/webhook')
  async webhook(@Body() body: Record<string, any>) {
    this.log.log(`Webhook incoming: ${JSON.stringify(body).slice(0, 500)}`);
    const result = await this.tbank.handleWebhook(body);
    return result.ok ? 'OK' : 'ERROR';
  }

  @Post('api/payments/webhook')
  async webhookAlt(@Body() body: Record<string, any>) {
    return this.webhook(body);
  }

  /**
   * Get my subscription status.
   */
  @Get('me/subscription')
  @UseGuards(JwtAuthGuard)
  async mySubscription(@Req() req: any) {
    const sub = await this.tbank.getSubscription(req.user.id);
    return { success: true, data: sub };
  }

  /**
   * Get my usage limits for the current billing period.
   */
  @Get('me/usage')
  @UseGuards(JwtAuthGuard)
  async myUsage(@Req() req: any) {
    const [ai, video, analytics] = await Promise.all([
      this.tbank.checkUsageLimit(req.user.id, 'ai_requests'),
      this.tbank.checkUsageLimit(req.user.id, 'video_gen'),
      this.tbank.checkUsageLimit(req.user.id, 'analytics_q'),
    ]);
    return {
      success: true,
      data: { ai_requests: ai, video_gen: video, analytics_q: analytics },
    };
  }

  /**
   * Get my payment history.
   */
  @Get('payments/history')
  @UseGuards(JwtAuthGuard)
  async myHistory(@Req() req: any) {
    const history = await this.tbank.getPaymentHistory(req.user.id);
    return { success: true, data: history };
  }

  /**
   * Check a specific payment status by orderId.
   */
  @Get('payments/check')
  @UseGuards(JwtAuthGuard)
  async checkPayment(@Req() req: any, @Query('orderId') orderId: string) {
    if (!orderId) {
      throw new HttpException('orderId is required', HttpStatus.BAD_REQUEST);
    }

    const payment = await this.tbank.checkPaymentStatus(orderId);
    if (!payment) {
      throw new HttpException('Payment not found', HttpStatus.NOT_FOUND);
    }

    // Ensure user can only see their own payments
    if (payment.user_id !== req.user.id) {
      throw new HttpException('Payment not found', HttpStatus.NOT_FOUND);
    }

    // If still pending, try to sync from T-Bank
    if (payment.status === 'pending') {
      const sync = await this.tbank.syncPendingPayment(orderId);
      if (sync.synced) {
        const updated = await this.tbank.checkPaymentStatus(orderId);
        return { success: true, data: updated };
      }
    }

    return { success: true, data: payment };
  }

  /**
   * Get available credit packages.
   */
  @Get('payments/packages')
  async getCreditPackages() {
    return { success: true, data: this.tbank.getCreditPackages() };
  }

  /**
   * Fallback: old T-Bank SuccessURL/FailURL pointed here.
   * Redirect to the Flutter frontend payment-result page.
   */
  @Get('subscription')
  async subscriptionRedirect(
    @Res() res: Response,
    @Query('payment') payment?: string,
    @Query('orderId') orderId?: string,
  ) {
    const appUrl = process.env.APP_URL || 'https://aurixmusic.ru';
    const status = payment === 'success' ? 'success' : 'fail';
    const qs = orderId ? `orderId=${orderId}&status=${status}` : `status=${status}`;
    return res.redirect(302, `${appUrl}/payment-result?${qs}`);
  }

  // ── ADMIN ENDPOINTS ─────────────────────────────────

  @Get('admin/payments')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async adminPayments(
    @Query('status') status?: string,
    @Query('type') type?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.tbank.allPayments({
      status,
      type,
      limit: +(limit || 50),
      offset: +(offset || 0),
    });
  }

  @Get('admin/payments/stats')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async adminStats() {
    return this.tbank.paymentStats();
  }
}
