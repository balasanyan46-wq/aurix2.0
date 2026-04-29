import { Body, Controller, Delete, Param, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { PushService } from './push.service';

/**
 * Endpoints для регистрации и отзыва push-токенов.
 *
 * Под JwtAuthGuard (не AdminGuard) — это user-side, любой авторизованный
 * пользователь регистрирует свой токен.
 *
 * POST /push/register   — после получения FCM/APNS токена клиентом
 * DELETE /push/:token   — при logout / выключении уведомлений
 */
@UseGuards(JwtAuthGuard)
@Controller('push')
export class PushController {
  constructor(private readonly service: PushService) {}

  @Post('register')
  async register(
    @Req() req: any,
    @Body() body: { platform: 'fcm' | 'apns' | 'web'; token: string; device_info?: Record<string, any> },
  ) {
    if (!body.platform || !body.token) {
      return { ok: false, error: 'platform and token required' };
    }
    await this.service.registerToken(req.user.id, body.platform, body.token, body.device_info);
    return { ok: true };
  }

  @Delete(':token')
  async unregister(@Param('token') token: string) {
    await this.service.unregisterToken(token);
    return { ok: true };
  }
}
