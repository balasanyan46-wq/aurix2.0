import { THEME } from '../mailer.config';
import { emailLayout, ctaButton, heading, bodyText, mutedText } from './layout';

export function buildWelcomeTemplate(name: string | null, loginUrl: string): string {
  const T = THEME;
  const greeting = name ? `${name}, добро пожаловать!` : 'Добро пожаловать в AURIX!';

  return emailLayout({
    title: 'Добро пожаловать — AURIX',
    preheader: 'Ваш аккаунт подтверждён. Время творить.',
    body: `
      <div style="text-align:center;margin-bottom:20px;">
        <span style="font-size:48px;">🎵</span>
      </div>
      ${heading(greeting)}
      ${bodyText('Ваш email успешно подтверждён. Теперь вам доступны все инструменты AURIX для управления карьерой:')}
      <table cellpadding="0" cellspacing="0" role="presentation" style="margin:0 0 24px;">
        <tr>
          <td style="padding:8px 0;font-size:15px;color:${T.textSecondary};">
            <span style="color:${T.accent};font-weight:700;margin-right:8px;">▸</span> Управление релизами и дистрибуция
          </td>
        </tr>
        <tr>
          <td style="padding:8px 0;font-size:15px;color:${T.textSecondary};">
            <span style="color:${T.accent};font-weight:700;margin-right:8px;">▸</span> AI-студия для стратегий и контент-планов
          </td>
        </tr>
        <tr>
          <td style="padding:8px 0;font-size:15px;color:${T.textSecondary};">
            <span style="color:${T.accent};font-weight:700;margin-right:8px;">▸</span> DNK-тесты — узнайте свою уникальность
          </td>
        </tr>
        <tr>
          <td style="padding:8px 0;font-size:15px;color:${T.textSecondary};">
            <span style="color:${T.accent};font-weight:700;margin-right:8px;">▸</span> Аналитика и продвижение
          </td>
        </tr>
      </table>
      ${ctaButton(loginUrl, 'Войти в AURIX')}
    `,
    footer: `${mutedText('© AURIX — платформа для независимых артистов')}`,
  });
}
