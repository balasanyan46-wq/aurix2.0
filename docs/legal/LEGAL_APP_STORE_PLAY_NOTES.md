# AURIX · App Store / Google Play Legal Notes

## Обязательные публичные страницы

- `https://aurix.app/legal/privacy` — Privacy Policy URL
- `https://aurix.app/legal/terms` — Terms of Use URL
- `https://aurix.app/legal/privacy-choices` — User Privacy Choices URL
- `https://aurix.app/legal/data-deletion` — Account deletion instructions
- `https://aurix.app/legal/refunds` — Refunds/Cancellation policy
- `https://aurix.app/legal/contact` — Legal/support contacts

## Куда вставлять URL в сторах

- **App Store Connect**
  - Privacy Policy URL -> `https://aurix.app/legal/privacy`
  - User Privacy Choices URL -> `https://aurix.app/legal/privacy-choices`
  - Terms of Use (если поле доступно) -> `https://aurix.app/legal/terms`
- **Google Play Console**
  - Privacy Policy -> `https://aurix.app/legal/privacy`
  - Account Deletion URL / reference -> `https://aurix.app/legal/data-deletion`
  - Developer support email должен совпадать с `{{SUPPORT_EMAIL}}`

## Короткая App Privacy Summary (App Store)

**Data used to provide app functionality**
- Contact info (email, phone)
- User content (music/release files, metadata, generated content)
- Identifiers (account ID)
- Diagnostics and product interaction events

**Data linked to user**
- Account/profile data
- Subscription status and billing reference IDs
- User-generated content and activity history

**Data not sold**
- AURIX does not sell personal data.

## Короткая Google Play Data Safety Summary

- **Collected**: email, phone, account identifiers, user content, in-app activity, diagnostics.
- **Purpose**: app functionality, account management, analytics, security/fraud prevention, support.
- **Sharing**: only with subprocessors (cloud, analytics, payments, support, AI providers) as needed.
- **Security**: encrypted transport, access controls, least-privilege, audit-friendly data model.
- **Deletion**: available via in-app flow + public page `legal/data-deletion`.

## Developer notes: категории данных для ручной разметки

- Personal info: Email address, Phone number
- Financial info: Purchase/subscription metadata (provider reference)
- App activity: In-app interactions, content operations
- User content: Audio files, cover images, text metadata, AI prompts/results
- App info/performance: Crash logs, diagnostics
- Device/other IDs: user/account identifier

## Checklist перед отправкой

- [ ] Все legal URL публично доступны без авторизации.
- [ ] Страница `legal/data-deletion` содержит in-app шаги и support fallback.
- [ ] Страница `legal/privacy-choices` содержит опции opt-out и запросы на экспорт/исправление.
- [ ] В registration есть согласие с Terms + Privacy.
- [ ] В settings есть entry-point на Account Deletion Request.
- [ ] Заполнены placeholders: `{{SUPPORT_EMAIL}}`, `{{PRIVACY_CONTACT_EMAIL}}`, `{{LEGAL_ADDRESS}}`, `{{INN}}`, `{{OGRNIP}}`, `{{REFUND_POLICY_DAYS}}`.
