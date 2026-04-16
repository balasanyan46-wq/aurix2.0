import { THEME } from '../mailer.config';
import { emailLayout, heading, bodyText, mutedText, esc } from './layout';

export function buildReleaseApprovedTemplate(opts: {
  artistName: string;
  releaseTitle: string;
}): string {
  const T = THEME;
  return emailLayout({
    title: 'Релиз одобрен — AURIX',
    preheader: `Ваш релиз «${esc(opts.releaseTitle)}» одобрен!`,
    body: `
      <div style="text-align:center;margin-bottom:20px;">
        <span style="font-size:48px;">✅</span>
      </div>
      ${heading('Релиз одобрен!')}
      ${bodyText(`<strong style="color:${T.textPrimary};">${esc(opts.artistName)}</strong>, ваш релиз <strong style="color:${T.accent};">«${esc(opts.releaseTitle)}»</strong> прошёл проверку и одобрен командой AURIX.`)}
      ${bodyText('Мы начинаем процесс дистрибуции. Вы получите уведомление, когда релиз станет доступен на площадках.')}
      <div style="padding:16px 20px;background:rgba(255,106,26,0.08);border-radius:12px;border:1px solid rgba(255,106,26,0.15);">
        <table cellpadding="0" cellspacing="0" role="presentation">
          <tr>
            <td style="padding:4px 0;font-size:14px;color:${T.textMuted};width:100px;">Релиз:</td>
            <td style="padding:4px 0;font-size:14px;color:${T.textPrimary};font-weight:600;">${esc(opts.releaseTitle)}</td>
          </tr>
          <tr>
            <td style="padding:4px 0;font-size:14px;color:${T.textMuted};">Статус:</td>
            <td style="padding:4px 0;font-size:14px;color:#4ADE80;font-weight:600;">Одобрен ✓</td>
          </tr>
        </table>
      </div>
    `,
    footer: `${mutedText('© AURIX — платформа для независимых артистов')}`,
  });
}
