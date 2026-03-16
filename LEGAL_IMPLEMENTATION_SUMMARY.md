# AURIX · Legal Implementation Summary

## Что реализовано

- Добавлен новый публичный legal/compliance модуль с отдельными URL в формате `/legal/*`.
- Добавлены полноценные русскоязычные черновики ключевых документов: Privacy, Terms, Offer, Data Deletion, Privacy Choices, Cookies, Contact, Content Policy, Copyright, Refunds.
- Реализован премиальный UI legal-страниц в стиле AURIX: hero, callout-блоки, оглавление, related links, last-updated, copy-link, footer-nav.
- Интегрированы ссылки на legal в landing footer, auth-flow и настройки.
- Добавлен базовый flow запроса на удаление аккаунта (экран + запись в БД + вывод статуса).
- Добавлены compliance-хранилища в БД для acceptances и cookie choices.

## Созданные/обновленные страницы

- `/legal`
- `/legal/privacy`
- `/legal/terms`
- `/legal/offer`
- `/legal/data-deletion`
- `/legal/privacy-choices`
- `/legal/cookies`
- `/legal/contact`
- `/legal/content-policy`
- `/legal/copyright`
- `/legal/refunds`
- `/settings/account-deletion` (внутри приложения)

## Основные файлы реализации

- `aurix_flutter/lib/features/legal/compliance/legal_content.dart`
- `aurix_flutter/lib/features/legal/compliance/legal_pages.dart`
- `aurix_flutter/lib/presentation/router/app_router.dart`
- `aurix_flutter/lib/screens/settings/settings_screen.dart`
- `aurix_flutter/lib/features/settings/presentation/account_deletion_request_page.dart`
- `aurix_flutter/lib/presentation/screens/auth/register_screen.dart`
- `aurix_flutter/lib/presentation/screens/auth/login_screen.dart`
- `aurix_flutter/lib/presentation/landing/landing_page.dart`
- `aurix_flutter/lib/data/repositories/legal_compliance_repository.dart`
- `aurix_flutter/lib/data/repositories/account_deletion_request_repository.dart`
- `aurix_flutter/lib/data/providers/repositories_provider.dart`
- `supabase/migrations/061_legal_compliance_core.sql`
- `docs/legal/LEGAL_CONTENT_GUIDE.md`
- `docs/legal/LEGAL_APP_STORE_PLAY_NOTES.md`

## Что покрыто по сайту

- Публичный раздел `/legal` и отдельные страницы всех обязательных документов.
- Навигация между документами и постоянные URL для сторов.

## Что покрыто по приложению

- Ссылки на `Privacy` и `Terms` в auth.
- Обязательный checkbox согласия в форме регистрации.
- Раздел Legal & Privacy в Settings:
  - быстрые ссылки на документы;
  - сохранение privacy choices (analytics/marketing);
  - кнопка "Запросить удаление аккаунта";
  - отображение текущего статуса запроса удаления.

## Что сделано под App Store

- Подготовлены URL для Privacy Policy и User Privacy Choices.
- Подготовлена страница Data Deletion, пригодная для требований App Review.
- Сформирован короткий App Privacy summary в `docs/legal/LEGAL_APP_STORE_PLAY_NOTES.md`.

## Что сделано под Google Play

- Подготовлен Privacy Policy URL и Data deletion reference URL.
- Сформирован черновик Data Safety summary и список data categories в `docs/legal/LEGAL_APP_STORE_PLAY_NOTES.md`.

## Что нужно заполнить вручную

- `{{SUPPORT_EMAIL}}`
- `{{PRIVACY_CONTACT_EMAIL}}`
- `{{LEGAL_ADDRESS}}`
- `{{INN}}`
- `{{OGRNIP}}`
- `{{REFUND_POLICY_DAYS}}`

## Следующие 3 шага

1. Юридическая валидация текстов (особенно Offer/Refunds/Applicable law) и замена placeholders.
2. Заполнение App Store Connect / Google Play Console полей по чеклисту из `docs/legal/LEGAL_APP_STORE_PLAY_NOTES.md`.
3. E2E-проверка web/mobile маршрутов `/legal/*`, регистрации с consent и отправки account deletion request.
