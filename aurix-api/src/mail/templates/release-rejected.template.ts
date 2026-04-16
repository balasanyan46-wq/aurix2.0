import { THEME } from '../mailer.config';
import { emailLayout, heading, bodyText, mutedText, esc } from './layout';

export function buildReleaseRejectedTemplate(opts: {
  artistName: string;
  releaseTitle: string;
  reason?: string;
}): string {
  const T = THEME;
  return emailLayout({
    title: 'Релиз отклонён — AURIX',
    preheader: `Релиз «${opts.releaseTitle}» отклонён`,
    body: `
      <div style="text-align:center;margin-bottom:20px;">
        <span style="font-size:48px;">❌</span>
      </div>
      ${heading('Релиз отклонён')}
      ${bodyText(`<strong style="color:${T.textPrimary};">${esc(opts.artistName)}</strong>, ваш релиз <strong style="color:${T.accent};">«${esc(opts.releaseTitle)}»</strong> был отклонён модерацией.`)}
      ${opts.reason ? `
      <div style="padding:16px 20px;background:rgba(201,113,113,0.08);border-radius:12px;border:1px solid rgba(201,113,113,0.15);margin-bottom:24px;">
        <p style="margin:0 0 8px;font-size:12px;color:${T.textMuted};text-transform:uppercase;letter-spacing:1px;font-weight:600;">Причина</p>
        <p style="margin:0;font-size:14px;color:${T.textPrimary};line-height:1.6;">${esc(opts.reason)}</p>
      </div>` : ''}
      ${bodyText('Вы можете создать новый релиз с учётом замечаний. Если у вас есть вопросы — обратитесь в поддержку.')}
    `,
    footer: `${mutedText('© AURIX — платформа для независимых артистов')}`,
  });
}
