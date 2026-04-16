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
import { UserEventsService } from '../user-events/user-events.service';
import { ReferralService } from '../referral/referral.service';

// ═══════════════════════════════════════════════════════
//  UsersController — /users/*
// ═══════════════════════════════════════════════════════

@Controller('users')
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly authService: AuthService,
    private readonly mailService: MailService,
    private readonly events: UserEventsService,
    private readonly referralService: ReferralService,
  ) {}

  // ───── POST /users/register ─────
  @Throttle({ default: { ttl: 60000, limit: 5 } })
  @Post('register')
  async register(
    @Req() req: any,
    @Body() body: { email: string; password: string; name?: string; phone?: string; ref?: string },
  ) {
    const { email, password, name, phone } = body;

    if (!email || !password) {
      throw new HttpException(
        'email and password are required',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email) || email.length > 254) {
      throw new HttpException('invalid email format', HttpStatus.BAD_REQUEST);
    }

    // Validate password strength
    if (password.length < 8) {
      throw new HttpException(
        'Пароль должен быть не менее 8 символов',
        HttpStatus.BAD_REQUEST,
      );
    }
    if (password.length > 128) {
      throw new HttpException(
        'Пароль слишком длинный',
        HttpStatus.BAD_REQUEST,
      );
    }

    const existing = await this.usersService.findByEmail(email);
    if (existing) {
      throw new HttpException('email already registered', HttpStatus.CONFLICT);
    }

    const user = await this.usersService.createUser(email, password, name, phone);

    // Send verification email (non-blocking — don't fail registration if SMTP is down)
    this.mailService.sendVerifyEmail(user.email, user.verification_token).catch((err) => {
      console.error(`[Register] Failed to send verification email to ${email}: ${err.message}`);
    });

    // Apply referral code if provided
    if (body.ref && typeof body.ref === 'string' && body.ref.trim()) {
      this.referralService.applyReferralCode(user.id, body.ref.trim()).catch((err) => {
        console.error(`[Register] Referral apply failed: ${err.message}`);
      });
    }

    // Log registration event
    this.events.log({ user_id: user.id, event: 'register', ip: req?.ip, user_agent: req?.headers?.['user-agent'] }).catch(() => {});

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

    // Log login event
    this.events.log({ user_id: user.id, event: 'login', ip: req?.ip, user_agent: req?.headers?.['user-agent'] }).catch(() => {});

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
  async getMe(@Req() req: any) {
    const user = await this.usersService.findById(req.user.id);
    if (!user) {
      throw new HttpException('user not found', HttpStatus.NOT_FOUND);
    }
    return { success: true, user };
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

  // ───── GET /auth/reset-password — HTML form ─────
  @Get('reset-password')
  @Header('Content-Type', 'text/html')
  async resetPasswordPage(@Query('token') token: string) {
    if (!token) {
      return this.buildResetHtml('', 'Недействительная ссылка. Запросите сброс пароля заново.');
    }

    const user = await this.usersService.findByResetToken(token);
    if (!user) {
      return this.buildResetHtml('', 'Ссылка недействительна или истекла. Запросите новую.');
    }

    if (new Date() > new Date(user.reset_token_expires)) {
      return this.buildResetHtml('', 'Ссылка для сброса пароля истекла. Запросите новую.');
    }

    return this.buildResetHtml(token);
  }

  private buildResetHtml(token: string, error?: string): string {
    const appUrl = process.env.APP_URL || 'https://aurixmusic.ru';
    return `<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Сброс пароля — AURIX</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0a0a0f;color:#e8e6f0;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}
.card{background:#14141f;border:1px solid rgba(255,255,255,.08);border-radius:16px;padding:40px;max-width:400px;width:100%}
.logo{text-align:center;margin-bottom:24px;font-size:20px;font-weight:800;letter-spacing:3px;color:#ff8c42}
h1{font-size:18px;font-weight:600;margin-bottom:8px;text-align:center}
.sub{color:#8b8a99;font-size:13px;text-align:center;margin-bottom:24px}
label{display:block;font-size:12px;color:#8b8a99;margin-bottom:4px;font-weight:600}
input{width:100%;padding:10px 14px;background:#1a1a2e;border:1px solid rgba(255,255,255,.1);border-radius:8px;color:#e8e6f0;font-size:14px;margin-bottom:16px;outline:none}
input:focus{border-color:#ff8c42}
button{width:100%;padding:12px;background:#ff8c42;color:#0a0a0f;border:none;border-radius:8px;font-size:14px;font-weight:700;cursor:pointer}
button:hover{background:#ff9f5a}
button:disabled{opacity:.5;cursor:not-allowed}
.error{background:rgba(220,38,38,.15);border:1px solid rgba(220,38,38,.3);color:#f87171;padding:10px 14px;border-radius:8px;font-size:13px;margin-bottom:16px;text-align:center}
.success{background:rgba(34,197,94,.15);border:1px solid rgba(34,197,94,.3);color:#4ade80;padding:14px;border-radius:8px;font-size:14px;text-align:center}
.link{display:block;text-align:center;margin-top:16px;color:#ff8c42;text-decoration:none;font-size:13px}
</style>
</head>
<body>
<div class="card">
<div class="logo">AURIX</div>
${error ? `<div class="error">${error}</div><a href="${appUrl}" class="link">Вернуться в AURIX</a>` : `
<h1>Новый пароль</h1>
<p class="sub">Введите новый пароль для вашего аккаунта</p>
<div id="msg"></div>
<form id="f" onsubmit="return go(event)">
<label>Новый пароль</label>
<input type="password" id="pw" minlength="8" required placeholder="Минимум 8 символов">
<label>Повторите пароль</label>
<input type="password" id="pw2" minlength="8" required placeholder="Повторите пароль">
<button type="submit" id="btn">Сменить пароль</button>
</form>
<a href="${appUrl}" class="link">Вернуться в AURIX</a>
<script>
async function go(e){
  e.preventDefault();
  var pw=document.getElementById('pw').value,pw2=document.getElementById('pw2').value,
      btn=document.getElementById('btn'),msg=document.getElementById('msg');
  if(pw!==pw2){msg.innerHTML='<div class="error">Пароли не совпадают</div>';return}
  if(pw.length<8){msg.innerHTML='<div class="error">Минимум 8 символов</div>';return}
  btn.disabled=true;btn.textContent='Сохраняем...';
  try{
    var r=await fetch('${appUrl}/auth/reset-password',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token:'${token}',password:pw})});
    var d=await r.json();
    if(r.ok){msg.innerHTML='<div class="success">✓ Пароль успешно изменён! Войдите в приложение с новым паролем.</div>';document.getElementById('f').style.display='none'}
    else{msg.innerHTML='<div class="error">'+(d.message||'Ошибка')+'</div>';btn.disabled=false;btn.textContent='Сменить пароль'}
  }catch(ex){msg.innerHTML='<div class="error">Ошибка сети</div>';btn.disabled=false;btn.textContent='Сменить пароль'}
}
</script>
`}
</div>
</body>
</html>`;
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
