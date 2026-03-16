import {
  Controller,
  Post,
  Get,
  Body,
  Query,
  Req,
  Header,
  UseGuards,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { UsersService } from './users.service';
import { AuthService } from '../auth/auth.service';
import { MailService } from '../mail/mail.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

// ═══════════════════════════════════════════════════════
//  UsersController — /users/*
// ═══════════════════════════════════════════════════════

@Controller('users')
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly authService: AuthService,
    private readonly mailService: MailService,
  ) {}

  // ───── POST /users/register ─────
  @Throttle({ default: { ttl: 60000, limit: 5 } })
  @Post('register')
  async register(
    @Body() body: { email: string; password: string; name?: string; phone?: string },
  ) {
    const { email, password, name, phone } = body;

    if (!email || !password) {
      throw new HttpException(
        'email and password are required',
        HttpStatus.BAD_REQUEST,
      );
    }

    const existing = await this.usersService.findByEmail(email);
    if (existing) {
      throw new HttpException('email already registered', HttpStatus.CONFLICT);
    }

    const user = await this.usersService.createUser(email, password, name, phone);

    // Send verification email
    await this.mailService.sendVerifyEmail(
      user.email,
      user.verification_token,
    );

    return {
      success: true,
      message: 'Письмо для подтверждения отправлено',
    };
  }

  // ───── POST /users/login ─────
  @Throttle({ default: { ttl: 60000, limit: 10 } })
  @Post('login')
  async login(@Req() req: any, @Body() body: { email: string; password: string }) {
    const { email, password } = body;

    if (!email || !password) {
      throw new HttpException(
        'email and password are required',
        HttpStatus.BAD_REQUEST,
      );
    }

    const user = await this.authService.validateUser(email, password);
    if (!user) {
      throw new HttpException('invalid credentials', HttpStatus.UNAUTHORIZED);
    }

    // STEP 7 — Block unverified users
    if (!user.verified) {
      throw new HttpException(
        'Подтвердите email перед входом',
        HttpStatus.UNAUTHORIZED,
      );
    }

    const token = this.authService.generateToken(user);
    const refreshToken = await this.authService.createRefreshToken(
      user.id,
      req?.headers?.['user-agent'],
    );

    return {
      success: true,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
      },
      token,
      refreshToken,
    };
  }

  // ───── GET /users/me ─────
  @UseGuards(JwtAuthGuard)
  @Get('me')
  getMe(@Req() req: any) {
    return {
      success: true,
      user: req.user,
    };
  }
}

// ═══════════════════════════════════════════════════════
//  AuthController — /auth/*
// ═══════════════════════════════════════════════════════

@Controller('auth')
export class AuthController {
  constructor(
    private readonly usersService: UsersService,
    private readonly mailService: MailService,
    private readonly authService: AuthService,
  ) {}

  // ───── POST /auth/refresh ─────
  @Throttle({ default: { ttl: 60000, limit: 30 } })
  @Post('refresh')
  async refresh(@Req() req: any, @Body('refreshToken') refreshToken: string) {
    if (!refreshToken) {
      throw new HttpException('refreshToken is required', HttpStatus.BAD_REQUEST);
    }

    const user = await this.authService.validateRefreshToken(refreshToken);
    if (!user) {
      throw new HttpException('invalid or expired refresh token', HttpStatus.UNAUTHORIZED);
    }

    // Rotate: old token is revoked, new one issued
    const newAccessToken = this.authService.generateToken(user);
    const newRefreshToken = await this.authService.rotateRefreshToken(
      refreshToken,
      user.id,
      req?.headers?.['user-agent'],
    );

    return {
      success: true,
      token: newAccessToken,
      refreshToken: newRefreshToken,
    };
  }

  // ───── POST /auth/logout ─────
  @Post('logout')
  async logout(@Body('refreshToken') refreshToken: string) {
    if (refreshToken) {
      await this.authService.revokeRefreshToken(refreshToken);
    }
    return { success: true };
  }

  // ───── GET /auth/verify-email?token=XXXX ─────
  @Get('verify-email')
  @Header('Content-Type', 'text/html')
  async verifyEmail(@Query('token') token: string) {
    if (!token) {
      throw new HttpException('Token is required', HttpStatus.BAD_REQUEST);
    }

    const user = await this.usersService.findByVerificationToken(token);
    if (!user) {
      throw new HttpException(
        'Недействительная или истёкшая ссылка',
        HttpStatus.BAD_REQUEST,
      );
    }

    await this.usersService.markEmailVerified(user.id);

    // Send welcome email (non-blocking)
    this.mailService
      .sendWelcomeEmail(user.email, user.name)
      .catch((err) => console.error('Welcome email failed:', err));

    return `<!DOCTYPE html>
<html lang="ru">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Email подтверждён — AURIX</title>
<style>
  body{margin:0;background:#0d0d0d;font-family:'Segoe UI',Roboto,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh}
  .card{background:#1a1a1a;border:1px solid #2a2a2a;border-radius:16px;padding:48px 40px;text-align:center;max-width:420px}
  h1{color:#ff8800;font-size:28px;font-weight:800;letter-spacing:1px;margin:0 0 24px}
  .icon{font-size:64px;margin-bottom:16px}
  h2{color:#fff;font-size:20px;font-weight:700;margin:0 0 12px}
  p{color:#999;font-size:15px;line-height:1.6;margin:0}
</style>
</head>
<body>
  <div class="card">
    <h1>AURIX</h1>
    <div class="icon">✅</div>
    <h2>Email подтверждён!</h2>
    <p>Теперь вы можете войти в приложение AURIX.</p>
  </div>
</body>
</html>`;
  }

  // ───── POST /auth/request-password-reset ─────
  @Throttle({ default: { ttl: 60000, limit: 3 } })
  @Post('request-password-reset')
  async requestPasswordReset(@Body('email') email: string) {
    if (!email) {
      throw new HttpException('email is required', HttpStatus.BAD_REQUEST);
    }

    const user = await this.usersService.findByEmail(email);
    if (!user) {
      // Don't leak whether the email exists
      return {
        success: true,
        message: 'Если аккаунт существует, письмо отправлено',
      };
    }

    const resetToken = await this.usersService.setResetToken(user.id);
    await this.mailService.sendResetPasswordEmail(user.email, resetToken);

    return {
      success: true,
      message: 'Если аккаунт существует, письмо отправлено',
    };
  }

  // ───── POST /auth/reset-password ─────
  @Post('reset-password')
  async resetPassword(
    @Body() body: { token: string; password: string },
  ) {
    const { token, password } = body;

    if (!token || !password) {
      throw new HttpException(
        'token and password are required',
        HttpStatus.BAD_REQUEST,
      );
    }

    if (password.length < 8) {
      throw new HttpException(
        'Пароль должен быть не менее 8 символов',
        HttpStatus.BAD_REQUEST,
      );
    }

    const user = await this.usersService.findByResetToken(token);
    if (!user) {
      throw new HttpException(
        'Недействительная или истёкшая ссылка',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Check expiration
    if (new Date() > new Date(user.reset_token_expires)) {
      throw new HttpException(
        'Ссылка для сброса пароля истекла. Запросите новую.',
        HttpStatus.BAD_REQUEST,
      );
    }

    await this.usersService.resetPassword(user.id, password);

    return {
      success: true,
      message: 'Пароль успешно изменён',
    };
  }
}
