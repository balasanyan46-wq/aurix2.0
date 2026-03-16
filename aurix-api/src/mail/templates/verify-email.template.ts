import { THEME } from '../mailer.config';
import { emailLayout, ctaButton, heading, bodyText, mutedText } from './layout';

export function buildVerifyEmailTemplate(verifyUrl: string): string {
  const T = THEME;
  return emailLayout({
    title: 'Подтвердите email — AURIX',
    preheader: 'Подтвердите email, чтобы начать работу с AURIX',
    body: `
      ${heading('Подтвердите ваш email')}
      ${bodyText('Вы зарегистрировались на платформе <strong style="color:' + T.textPrimary + ';">AURIX</strong>. Чтобы завершить регистрацию и получить доступ ко всем инструментам, подтвердите ваш email.')}
      ${ctaButton(verifyUrl, 'Подтвердить email')}
      <div style="margin-top:24px;">
        ${mutedText('Или скопируйте ссылку:')}
        <p style="margin:4px 0 0;font-size:12px;word-break:break-all;color:${T.accent};">${verifyUrl}</p>
      </div>
    `,
    footer: `${mutedText('Если вы не регистрировались на AURIX — просто проигнорируйте это письмо.')}`,
  });
}
