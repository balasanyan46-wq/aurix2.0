import { THEME } from '../mailer.config';
import { emailLayout, heading, bodyText, mutedText } from './layout';

export function buildReleaseLiveTemplate(opts: {
  artistName: string;
  releaseTitle: string;
}): string {
  const T = THEME;
  return emailLayout({
    title: 'Релиз доступен на площадках — AURIX',
    preheader: `«${opts.releaseTitle}» теперь на площадках!`,
    body: `
      <div style="text-align:center;margin-bottom:20px;">
        <span style="font-size:48px;">🚀</span>
      </div>
      ${heading('Ваш релиз в эфире!')}
      ${bodyText(`<strong style="color:${T.textPrimary};">${opts.artistName}</strong>, ваш релиз <strong style="color:${T.accent};">«${opts.releaseTitle}»</strong> теперь доступен на музыкальных площадках!`)}
      ${bodyText('Следите за статистикой прослушиваний в разделе аналитики AURIX.')}
      <div style="padding:16px 20px;background:rgba(255,106,26,0.08);border-radius:12px;border:1px solid rgba(255,106,26,0.15);">
        <table cellpadding="0" cellspacing="0" role="presentation">
          <tr>
            <td style="padding:4px 0;font-size:14px;color:${T.textMuted};width:100px;">Релиз:</td>
            <td style="padding:4px 0;font-size:14px;color:${T.textPrimary};font-weight:600;">${opts.releaseTitle}</td>
          </tr>
          <tr>
            <td style="padding:4px 0;font-size:14px;color:${T.textMuted};">Статус:</td>
            <td style="padding:4px 0;font-size:14px;color:${T.accent};font-weight:600;">🔴 LIVE</td>
          </tr>
        </table>
      </div>
    `,
    footer: `${mutedText('© AURIX — платформа для независимых артистов')}`,
  });
}
