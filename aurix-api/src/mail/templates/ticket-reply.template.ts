import { THEME } from '../mailer.config';
import { emailLayout, heading, bodyText, ctaButton, mutedText } from './layout';

export function buildTicketReplyTemplate(opts: {
  subject: string;
  replyText: string;
  ticketId: number;
}): string {
  const T = THEME;
  return emailLayout({
    title: 'Ответ от поддержки — AURIX',
    preheader: `Новый ответ по обращению «${opts.subject}»`,
    body: `
      <div style="text-align:center;margin-bottom:20px;">
        <span style="font-size:48px;">💬</span>
      </div>
      ${heading('Ответ от поддержки')}
      ${bodyText(`По вашему обращению <strong style="color:${T.accent};">«${opts.subject}»</strong> получен ответ:`)}
      <div style="padding:16px 20px;background:rgba(255,106,26,0.08);border-radius:12px;border:1px solid rgba(255,106,26,0.15);margin-bottom:24px;">
        <p style="margin:0;font-size:14px;line-height:1.7;color:${T.textPrimary};white-space:pre-line;">${opts.replyText}</p>
      </div>
      ${ctaButton('https://aurixmusic.ru', 'Открыть AURIX')}
    `,
    footer: `${mutedText('Обращение #' + opts.ticketId + ' · © AURIX — платформа для независимых артистов')}`,
  });
}
