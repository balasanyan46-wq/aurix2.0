import { THEME, MAILER_CONFIG } from '../mailer.config';
import { emailLayout, heading, bodyText, mutedText, ctaButton, esc } from './layout';

export function buildReleaseRevisionTemplate(opts: {
  artistName: string;
  releaseTitle: string;
  reason: string;
}): string {
  const T = THEME;
  return emailLayout({
    title: 'Требуются исправления — AURIX',
    preheader: `Релиз «${opts.releaseTitle}» требует доработки`,
    body: `
      <div style="text-align:center;margin-bottom:20px;">
        <span style="font-size:48px;">⚠️</span>
      </div>
      ${heading('Релиз требует доработки')}
      ${bodyText(`<strong style="color:${T.textPrimary};">${esc(opts.artistName)}</strong>, ваш релиз <strong style="color:${T.accent};">«${esc(opts.releaseTitle)}»</strong> не прошёл модерацию и требует исправлений.`)}
      <div style="padding:16px 20px;background:rgba(210,164,90,0.08);border-radius:12px;border:1px solid rgba(210,164,90,0.15);margin-bottom:24px;">
        <p style="margin:0 0 8px;font-size:12px;color:${T.textMuted};text-transform:uppercase;letter-spacing:1px;font-weight:600;">Причина</p>
        <p style="margin:0;font-size:14px;color:${T.textPrimary};line-height:1.6;">${esc(opts.reason)}</p>
      </div>
      ${bodyText('Пожалуйста, исправьте указанные замечания и отправьте релиз повторно. Мы проверим его заново.')}
      ${ctaButton(`${MAILER_CONFIG.appUrl || 'https://aurixmusic.ru'}/releases`, 'Перейти к релизам')}
    `,
    footer: `${mutedText('© AURIX — платформа для независимых артистов')}`,
  });
}
