import { THEME } from '../mailer.config';
import { emailLayout, ctaButton, heading, bodyText, mutedText } from './layout';

export function buildResetPasswordTemplate(resetUrl: string): string {
  const T = THEME;
  return emailLayout({
    title: 'Сброс пароля — AURIX',
    preheader: 'Запрос на сброс пароля AURIX',
    body: `
      ${heading('Сброс пароля')}
      ${bodyText('Мы получили запрос на сброс пароля для вашего аккаунта <strong style="color:' + T.textPrimary + ';">AURIX</strong>. Нажмите кнопку ниже, чтобы задать новый пароль.')}
      ${ctaButton(resetUrl, 'Сбросить пароль')}
      <div style="margin-top:24px;">
        ${mutedText('Или скопируйте ссылку:')}
        <p style="margin:4px 0 0;font-size:12px;word-break:break-all;color:${T.accent};">${resetUrl}</p>
      </div>
      <div style="margin-top:20px;padding:12px 16px;background:rgba(255,106,26,0.08);border-radius:8px;border:1px solid rgba(255,106,26,0.15);">
        <p style="margin:0;font-size:13px;color:${T.textSecondary};">⏱ Ссылка действительна <strong style="color:${T.textPrimary};">1 час</strong></p>
      </div>
    `,
    footer: `${mutedText('Если вы не запрашивали сброс пароля — проигнорируйте это письмо. Ваш пароль не изменится.')}`,
  });
}
