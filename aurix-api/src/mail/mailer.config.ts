// ═══════════════════════════════════════════════════════
//  AURIX — Mailer configuration
// ═══════════════════════════════════════════════════════

export const MAILER_CONFIG = {
  smtp: {
    host: process.env.SMTP_HOST || 'smtp.yandex.ru',
    port: Number(process.env.SMTP_PORT) || 465,
    secure: (process.env.SMTP_SECURE ?? 'true') === 'true',
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
  from: process.env.SMTP_FROM || 'AURIX <aurix@aurixai.ru>',
  appUrl: process.env.APP_URL || 'http://localhost:3000',
};

// ── Design tokens (AURIX dark theme) ──────────────────
export const THEME = {
  bgOuter: '#07070B',
  bgCard: '#0E0F14',
  borderCard: '#1A1B23',
  accent: '#FF6A1A',
  accentHover: '#FF8A4A',
  textPrimary: '#EAEAEA',
  textSecondary: '#8A8A9A',
  textMuted: '#555566',
  cardWidth: 680,
  radius: 16,
};
