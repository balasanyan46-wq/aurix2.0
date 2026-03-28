import { Controller, Post, Get, Body, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { MailService } from './mail.service';

@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('mail')
export class MailController {
  constructor(private readonly mailService: MailService) {}

  /** POST /mail/test — admin only, send test email */
  @Post('test')
  async testEmail(@Body() body: { email: string }) {
    if (!body.email) {
      throw new HttpException('email is required', HttpStatus.BAD_REQUEST);
    }

    const result = await this.mailService.sendTestEmail(body.email);
    return result;
  }

  /** GET /mail/verify — admin only, verify SMTP connection */
  @Get('verify')
  async verifySmtp() {
    return this.mailService.verifyConnection();
  }
}
