import { THEME } from '../mailer.config';

const T = THEME;

/**
 * Shared AURIX email layout.
 * Wraps content in the dark-theme card with header + footer.
 */
export function emailLayout(opts: {
  title: string;
  preheader?: string;
  body: string;
  footer?: string;
}): string {
  const footerHtml = opts.footer
    ? opts.footer
    : `<p style="margin:0;font-size:12px;color:${T.textMuted};">© AURIX — платформа для независимых артистов</p>`;

  return `<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta name="color-scheme" content="dark" />
  <meta name="supported-color-schemes" content="dark" />
  <title>${opts.title}</title>
  <!--[if !mso]><!-->
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap');
  </style>
  <!--<![endif]-->
  ${opts.preheader ? `<span style="display:none;font-size:1px;color:${T.bgOuter};max-height:0;overflow:hidden;">${opts.preheader}</span>` : ''}
</head>
<body style="margin:0;padding:0;background-color:${T.bgOuter};font-family:Inter,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased;">
  <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="background-color:${T.bgOuter};padding:48px 16px;">
    <tr>
      <td align="center">
        <!-- Card -->
        <table width="${T.cardWidth}" cellpadding="0" cellspacing="0" role="presentation"
               style="max-width:${T.cardWidth}px;width:100%;background-color:${T.bgCard};border-radius:${T.radius}px;overflow:hidden;border:1px solid ${T.borderCard};">
          <!-- Header -->
          <tr>
            <td style="padding:36px 40px 24px;text-align:center;border-bottom:1px solid ${T.borderCard};">
              <h1 style="margin:0;font-size:28px;font-weight:800;color:${T.accent};letter-spacing:2px;font-family:Inter,'Segoe UI',sans-serif;">AURIX</h1>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:32px 40px 36px;">
              ${opts.body}
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="padding:20px 40px 24px;border-top:1px solid ${T.borderCard};text-align:center;">
              ${footerHtml}
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

/** Gradient CTA button (table-based for email clients) */
export function ctaButton(href: string, label: string): string {
  return `
  <table cellpadding="0" cellspacing="0" role="presentation" style="margin:0 auto;">
    <tr>
      <td style="border-radius:12px;background:linear-gradient(135deg, ${T.accent} 0%, ${T.accentHover} 100%);">
        <!--[if mso]>
        <v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" href="${href}" style="width:240px;height:48px;v-text-anchor:middle;" arcsize="25%" fillcolor="${T.accent}">
        <w:anchorlock/>
        <center style="color:#000;font-family:sans-serif;font-size:15px;font-weight:700;">
          ${label}
        </center>
        </v:roundrect>
        <![endif]-->
        <!--[if !mso]><!-->
        <a href="${href}" target="_blank"
           style="display:inline-block;padding:14px 40px;font-size:15px;font-weight:700;color:#000000;text-decoration:none;border-radius:12px;font-family:Inter,'Segoe UI',sans-serif;">
          ${label}
        </a>
        <!--<![endif]-->
      </td>
    </tr>
  </table>`;
}

/** Small muted paragraph */
export function mutedText(text: string): string {
  return `<p style="margin:0;font-size:13px;line-height:1.5;color:${T.textMuted};">${text}</p>`;
}

/** Heading */
export function heading(text: string): string {
  return `<h2 style="margin:0 0 16px;font-size:22px;font-weight:700;color:${T.textPrimary};font-family:Inter,'Segoe UI',sans-serif;">${text}</h2>`;
}

/** Body text */
export function bodyText(text: string): string {
  return `<p style="margin:0 0 24px;font-size:15px;line-height:1.7;color:${T.textSecondary};">${text}</p>`;
}
