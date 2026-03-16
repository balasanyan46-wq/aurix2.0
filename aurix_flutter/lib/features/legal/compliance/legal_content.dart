import 'package:flutter/material.dart';

class LegalDocSection {
  const LegalDocSection({
    required this.title,
    required this.body,
    this.points = const <String>[],
    this.calloutLabel,
    this.calloutText,
  });

  final String title;
  final String body;
  final List<String> points;
  final String? calloutLabel;
  final String? calloutText;
}

class LegalDoc {
  const LegalDoc({
    required this.slug,
    required this.title,
    required this.shortDescription,
    required this.lastUpdated,
    required this.heroNote,
    required this.sections,
    this.relatedSlugs = const <String>[],
  });

  final String slug;
  final String title;
  final String shortDescription;
  final String lastUpdated;
  final String heroNote;
  final List<LegalDocSection> sections;
  final List<String> relatedSlugs;
}

const legalSupportEmailPlaceholder = '{{SUPPORT_EMAIL}}';
const legalPrivacyEmailPlaceholder = '{{PRIVACY_CONTACT_EMAIL}}';
const legalAddressPlaceholder = '{{LEGAL_ADDRESS}}';
const legalInnPlaceholder = '{{INN}}';
const legalOgrnipPlaceholder = '{{OGRNIP}}';
const legalRefundDaysPlaceholder = '{{REFUND_POLICY_DAYS}}';

const legalOperatorName = 'ИП Баласанян Армен Рустамович';

const legalDocs = <LegalDoc>[
  LegalDoc(
    slug: 'privacy',
    title: 'Политика конфиденциальности',
    shortDescription: 'Как AURIX собирает, использует и защищает персональные данные.',
    lastUpdated: '05.03.2026',
    heroNote: 'Эта политика действует для сайта, веб-кабинета и мобильного приложения AURIX.',
    relatedSlugs: ['terms', 'data-deletion', 'privacy-choices', 'cookies', 'contact'],
    sections: [
      LegalDocSection(
        title: '1. Кто обрабатывает данные',
        body: 'Оператор персональных данных: $legalOperatorName. Юридические запросы по данным направляются на $legalPrivacyEmailPlaceholder. Почтовый адрес оператора: $legalAddressPlaceholder.',
      ),
      LegalDocSection(
        title: '2. Какие данные мы получаем',
        body: 'Мы обрабатываем данные, которые вы передаете напрямую, и данные, которые формируются во время использования сервиса.',
        points: [
          'Регистрация и профиль: email, телефон, имя/сценическое имя, настройки профиля.',
          'Подписка и платежи: статус тарифа, период доступа, платежный идентификатор у провайдера оплаты.',
          'Данные по работе в AURIX: релизы, треки, обложки, метаданные, история действий.',
          'Данные AI-инструментов: запросы, промпты, сгенерированные результаты, история использования.',
          'Технические данные: IP, тип устройства, версия приложения, журнал ошибок, аналитические события.',
        ],
      ),
      LegalDocSection(
        title: '3. Цели и правовые основания обработки',
        body: 'Мы обрабатываем данные для оказания сервиса, поддержки пользователя, безопасности и исполнения требований закона.',
        points: [
          'Исполнение договора: создание аккаунта, предоставление доступа, работа подписки.',
          'Законный интерес: защита от злоупотреблений, улучшение качества, диагностика проблем.',
          'Согласие пользователя: необязательная аналитика, маркетинговые коммуникации.',
          'Исполнение закона: хранение документов для бухгалтерского учета и разрешения споров.',
        ],
        calloutLabel: 'Коротко',
        calloutText: 'AURIX использует только те данные, которые нужны для работы продукта, безопасности и поддержки.',
      ),
      LegalDocSection(
        title: '4. Подрядчики и передача данных',
        body: 'Для работы AURIX может использовать инфраструктурных и технологических подрядчиков.',
        points: [
          'Облачная инфраструктура и база данных.',
          'Сервисы аналитики и мониторинга ошибок.',
          'Платежные провайдеры и биллинг-платформы.',
          'Сервисы поддержки пользователей и коммуникаций.',
          'AI-провайдеры для генеративных функций.',
        ],
      ),
      LegalDocSection(
        title: '5. Международная передача данных',
        body: 'Часть подрядчиков может обрабатывать данные за пределами страны вашего резидентства. В таких случаях мы применяем договорные и организационные меры для защиты данных.',
      ),
      LegalDocSection(
        title: '6. Сроки хранения',
        body: 'Мы храним данные столько, сколько это нужно для работы сервиса, выполнения обязательств и соблюдения закона.',
        points: [
          'Данные аккаунта: до удаления аккаунта пользователем или оператором.',
          'Платежные и учетные данные: в сроки, требуемые законодательством.',
          'Логи безопасности и антифрода: разумный срок для расследования инцидентов.',
        ],
      ),
      LegalDocSection(
        title: '7. Права пользователя',
        body: 'Вы можете запросить доступ к данным, исправление, ограничение обработки, удаление и экспорт данных в переносимом формате. Для запроса используйте страницу Privacy Choices или напишите на $legalPrivacyEmailPlaceholder.',
      ),
      LegalDocSection(
        title: '8. Удаление аккаунта и данных',
        body: 'В AURIX доступен запрос на удаление аккаунта. Детальная инструкция и сроки доступны на отдельной странице «Удаление аккаунта и данных».',
        calloutLabel: 'Как удалить данные',
        calloutText: 'Перейдите в Settings -> Запросить удаление аккаунта, подтвердите действие и получите номер запроса.',
      ),
      LegalDocSection(
        title: '9. Безопасность',
        body: 'Мы применяем технические и организационные меры: контроль доступа, RLS-политики на стороне БД, аудит событий и регулярное исправление уязвимостей.',
      ),
      LegalDocSection(
        title: '10. Обновления политики',
        body: 'Мы можем обновлять эту политику по мере развития сервиса и требований закона. Актуальная версия всегда доступна по постоянной ссылке этой страницы.',
      ),
    ],
  ),
  LegalDoc(
    slug: 'terms',
    title: 'Пользовательское соглашение',
    shortDescription: 'Условия использования AURIX, права и ограничения сторон.',
    lastUpdated: '05.03.2026',
    heroNote: 'Используя AURIX, вы подтверждаете согласие с этими условиями.',
    relatedSlugs: ['offer', 'content-policy', 'copyright', 'refunds', 'privacy'],
    sections: [
      LegalDocSection(
        title: '1. Предмет сервиса',
        body: 'AURIX предоставляет цифровой сервис для управления музыкальными релизами, контентом, аналитикой и AI-инструментами.',
      ),
      LegalDocSection(
        title: '2. Кто может использовать сервис',
        body: 'Сервис предназначен для дееспособных пользователей, которые предоставляют достоверные данные и соблюдают применимое право.',
      ),
      LegalDocSection(
        title: '3. Аккаунт и безопасность',
        body: 'Вы отвечаете за сохранность логина/пароля и за действия, совершенные под вашим аккаунтом.',
        points: [
          'Нельзя передавать аккаунт третьим лицам.',
          'При подозрении на взлом нужно сразу сообщить в поддержку.',
        ],
      ),
      LegalDocSection(
        title: '4. Допустимое использование',
        body: 'Запрещены злоупотребления, попытки обхода ограничений, незаконный контент и нарушения прав третьих лиц.',
      ),
      LegalDocSection(
        title: '5. Пользовательский контент и права',
        body: 'Пользователь самостоятельно несет ответственность за законность загрузки музыки, обложек, текстов и метаданных, а также за наличие необходимых прав.',
      ),
      LegalDocSection(
        title: '6. AI-функции и ограничения',
        body: 'AI-рекомендации предоставляются «как есть» и служат вспомогательным инструментом. Пользователь самостоятельно принимает решения и проверяет результат.',
        calloutLabel: 'Важно',
        calloutText: 'AURIX не гарантирует конкретный карьерный, коммерческий или финансовый результат от использования AI или любых инструментов сервиса.',
      ),
      LegalDocSection(
        title: '7. Изменение функциональности',
        body: 'AURIX вправе изменять состав функций, тарифы и интерфейс для развития сервиса, безопасности и соблюдения требований законодательства.',
      ),
      LegalDocSection(
        title: '8. Ограничения доступа',
        body: 'Мы можем ограничить или приостановить доступ при нарушении условий, риске безопасности или правовых основаниях.',
      ),
      LegalDocSection(
        title: '9. Применимое право и претензии',
        body: 'К отношениям сторон применяется право, определяемое действующим законодательством и статусом оператора. Претензии направляются на $legalSupportEmailPlaceholder.',
      ),
    ],
  ),
  LegalDoc(
    slug: 'offer',
    title: 'Публичная оферта',
    shortDescription: 'Условия приобретения цифрового доступа и подписки в AURIX.',
    lastUpdated: '05.03.2026',
    heroNote: 'Оплата тарифа считается акцептом настоящей оферты.',
    relatedSlugs: ['terms', 'refunds', 'contact'],
    sections: [
      LegalDocSection(
        title: '1. Стороны и предмет',
        body: 'Оферта определяет условия предоставления доступа к цифровому сервису AURIX оператором $legalOperatorName.',
      ),
      LegalDocSection(
        title: '2. Тарифы и период доступа',
        body: 'Актуальные тарифы, состав функций и период доступа указываются в интерфейсе AURIX на момент оплаты.',
      ),
      LegalDocSection(
        title: '3. Порядок оплаты и акцепт',
        body: 'Оплата проводится через подключенного платежного провайдера. Акцепт оферты происходит в момент успешной оплаты.',
      ),
      LegalDocSection(
        title: '4. Продление и отмена',
        body: 'Если предусмотрено автопродление, информация об этом отображается до оплаты. Пользователь может отменить подписку в настройках аккаунта.',
      ),
      LegalDocSection(
        title: '5. Возвраты',
        body: 'Порядок возвратов определяется отдельной политикой Refunds/Cancellation с учетом характера цифровой услуги.',
      ),
      LegalDocSection(
        title: '6. Электронный документооборот',
        body: 'Юридически значимые уведомления и документы могут направляться в электронном виде через интерфейс сервиса и/или email.',
      ),
      LegalDocSection(
        title: '7. Ответственность и реквизиты',
        body: 'Реквизиты оператора: $legalOperatorName, ИНН: $legalInnPlaceholder, ОГРНИП: $legalOgrnipPlaceholder, адрес: $legalAddressPlaceholder, email: $legalSupportEmailPlaceholder.',
      ),
    ],
  ),
  LegalDoc(
    slug: 'data-deletion',
    title: 'Удаление аккаунта и данных',
    shortDescription: 'Пошагово: как удалить аккаунт, что удаляется и в какие сроки.',
    lastUpdated: '05.03.2026',
    heroNote: 'В AURIX реализован безопасный поток запроса на удаление аккаунта.',
    relatedSlugs: ['privacy', 'privacy-choices', 'contact'],
    sections: [
      LegalDocSection(
        title: '1. Как отправить запрос',
        body: 'Откройте Settings -> Запросить удаление аккаунта. Укажите причину, подтвердите действие и сохраните номер запроса.',
      ),
      LegalDocSection(
        title: '2. Что удаляется',
        body: 'После обработки запроса удаляются данные профиля и контент, не требуемый к хранению по закону.',
        points: [
          'Данные аккаунта и профильные данные.',
          'Пользовательские релизные материалы и вспомогательные данные, если нет правового основания хранить их дальше.',
        ],
      ),
      LegalDocSection(
        title: '3. Что может храниться ограниченно',
        body: 'Часть данных может сохраняться в минимальном объеме для бухгалтерского учета, разрешения споров, выполнения закона и антифрода.',
      ),
      LegalDocSection(
        title: '4. Сроки обработки',
        body: 'Базовый срок обработки запроса: до 30 календарных дней, если закон не требует иного.',
        calloutLabel: 'Куда писать',
        calloutText: 'Если не получается отправить запрос в приложении, напишите на $legalSupportEmailPlaceholder с темой "Account deletion request".',
      ),
    ],
  ),
  LegalDoc(
    slug: 'privacy-choices',
    title: 'Управление данными и Privacy Choices',
    shortDescription: 'Настройки приватности, экспорт, исправление и удаление данных.',
    lastUpdated: '05.03.2026',
    heroNote: 'Страница нужна для compliance в App Store и Google Play.',
    relatedSlugs: ['privacy', 'cookies', 'data-deletion'],
    sections: [
      LegalDocSection(
        title: '1. Управление рассылками',
        body: 'Пользователь может отключить необязательные уведомления и маркетинговые письма в настройках профиля или через ссылку в письме.',
      ),
      LegalDocSection(
        title: '2. Запрос экспорта данных',
        body: 'Для выгрузки данных отправьте запрос через поддержку: укажите email аккаунта и пометку "Data export request".',
      ),
      LegalDocSection(
        title: '3. Запрос исправления данных',
        body: 'Вы можете обновить часть данных в профиле самостоятельно, а для иных данных направить запрос на $legalPrivacyEmailPlaceholder.',
      ),
      LegalDocSection(
        title: '4. Необязательная аналитика и cookies',
        body: 'Если в вашем регионе доступно управление согласием, вы можете отключить необязательную аналитику и cookies.',
      ),
    ],
  ),
  LegalDoc(
    slug: 'cookies',
    title: 'Политика cookies и аналитики',
    shortDescription: 'Какие cookies/SDK применяются и как управлять согласием.',
    lastUpdated: '05.03.2026',
    heroNote: 'AURIX использует только необходимый минимум и прозрачные категории.',
    relatedSlugs: ['privacy', 'privacy-choices'],
    sections: [
      LegalDocSection(
        title: '1. Категории',
        body: 'В сервисе могут использоваться обязательные, аналитические и, при наличии, маркетинговые cookies/SDK.',
        points: [
          'Обязательные: авторизация, безопасность, работа сессии.',
          'Аналитические: агрегированная статистика использования.',
          'Маркетинговые: только при явном включении и наличии соответствующего сценария.',
        ],
      ),
      LegalDocSection(
        title: '2. Управление согласием',
        body: 'На поддерживаемых платформах можно изменить выбор в Privacy Choices или системных настройках браузера/устройства.',
      ),
      LegalDocSection(
        title: '3. Срок действия',
        body: 'Срок хранения cookies зависит от категории и назначения, но ограничивается разумным периодом для работы сервиса.',
      ),
    ],
  ),
  LegalDoc(
    slug: 'contact',
    title: 'Юридические и Support контакты',
    shortDescription: 'Куда направлять юридические запросы, претензии и обращения поддержки.',
    lastUpdated: '05.03.2026',
    heroNote: 'Для быстрых обращений используйте email с понятной темой письма.',
    relatedSlugs: ['privacy', 'terms', 'copyright', 'data-deletion'],
    sections: [
      LegalDocSection(
        title: '1. Оператор сервиса',
        body: '$legalOperatorName',
      ),
      LegalDocSection(
        title: '2. Контакты',
        body: 'Support: $legalSupportEmailPlaceholder\nPrivacy: $legalPrivacyEmailPlaceholder\nАдрес: $legalAddressPlaceholder',
      ),
      LegalDocSection(
        title: '3. Реквизиты',
        body: 'ИНН: $legalInnPlaceholder\nОГРНИП: $legalOgrnipPlaceholder',
      ),
    ],
  ),
  LegalDoc(
    slug: 'content-policy',
    title: 'Правила пользовательского контента',
    shortDescription: 'Что можно загружать, что запрещено и как подать жалобу.',
    lastUpdated: '05.03.2026',
    heroNote: 'Пользователь отвечает за права на загружаемый контент.',
    relatedSlugs: ['terms', 'copyright'],
    sections: [
      LegalDocSection(
        title: '1. Разрешенный контент',
        body: 'Допускается загрузка музыкальных материалов, метаданных и визуалов, если у пользователя есть необходимые права и разрешения.',
      ),
      LegalDocSection(
        title: '2. Запрещенный контент',
        body: 'Запрещено размещать незаконный, оскорбительный, мошеннический контент и контент, нарушающий права третьих лиц.',
      ),
      LegalDocSection(
        title: '3. Ответственность',
        body: 'Ответственность за законность и права на контент несет пользователь, который загрузил материал.',
      ),
      LegalDocSection(
        title: '4. Модерация и ограничения',
        body: 'AURIX вправе ограничить доступ к контенту или удалить его при обоснованном подозрении на нарушение закона или условий сервиса.',
      ),
    ],
  ),
  LegalDoc(
    slug: 'copyright',
    title: 'Copyright / IP / Takedown Policy',
    shortDescription: 'Процедура жалобы на нарушение прав и порядок рассмотрения.',
    lastUpdated: '05.03.2026',
    heroNote: 'Мы обрабатываем обращения по нарушениям прав в приоритетном порядке.',
    relatedSlugs: ['content-policy', 'contact'],
    sections: [
      LegalDocSection(
        title: '1. Как подать жалобу',
        body: 'Отправьте обращение на $legalSupportEmailPlaceholder с темой "IP takedown notice".',
        points: [
          'Данные заявителя и способ обратной связи.',
          'Описание объекта права и подтверждение прав.',
          'Прямая ссылка на спорный материал в AURIX.',
          'Описание нарушения и требуемое действие.',
        ],
      ),
      LegalDocSection(
        title: '2. Рассмотрение обращения',
        body: 'AURIX проверяет полноту данных и может запросить дополнительные сведения. По результату возможно ограничение доступа, удаление материала или отказ при недостаточности оснований.',
      ),
      LegalDocSection(
        title: '3. Контр-уведомление',
        body: 'Пользователь, чьи материалы затронуты, может направить возражение с подтверждающими документами.',
      ),
    ],
  ),
  LegalDoc(
    slug: 'refunds',
    title: 'Возвраты и отмена подписки',
    shortDescription: 'Условия отмены, возврата средств и прекращения доступа.',
    lastUpdated: '05.03.2026',
    heroNote: 'Политика учитывает характер цифровой услуги и факт предоставления доступа.',
    relatedSlugs: ['offer', 'terms', 'contact'],
    sections: [
      LegalDocSection(
        title: '1. Отмена подписки',
        body: 'Подписку можно отменить в настройках аккаунта. После отмены автопродление прекращается с конца оплаченного периода.',
      ),
      LegalDocSection(
        title: '2. Когда возможен возврат',
        body: 'Возврат рассматривается индивидуально, например при технической невозможности оказания услуги по вине сервиса.',
      ),
      LegalDocSection(
        title: '3. Когда возврат не производится',
        body: 'Обычно возврат не применяется, если цифровой доступ уже был предоставлен и сервис использовался, кроме случаев, прямо предусмотренных законом.',
      ),
      LegalDocSection(
        title: '4. Сроки и контакт',
        body: 'Запрос на возврат направляется в течение $legalRefundDaysPlaceholder дней с описанием проблемы на $legalSupportEmailPlaceholder.',
      ),
    ],
  ),
];

const legalDocOrder = <String>[
  'privacy',
  'terms',
  'offer',
  'data-deletion',
  'privacy-choices',
  'cookies',
  'contact',
  'content-policy',
  'copyright',
  'refunds',
];

LegalDoc? legalDocBySlug(String slug) {
  for (final doc in legalDocs) {
    if (doc.slug == slug) return doc;
  }
  return null;
}

String legalDocPath(String slug) => '/legal/$slug';

IconData legalDocIcon(String slug) {
  switch (slug) {
    case 'privacy':
      return Icons.privacy_tip_outlined;
    case 'terms':
      return Icons.gavel_rounded;
    case 'offer':
      return Icons.request_quote_outlined;
    case 'data-deletion':
      return Icons.delete_forever_outlined;
    case 'privacy-choices':
      return Icons.tune_rounded;
    case 'cookies':
      return Icons.cookie_outlined;
    case 'contact':
      return Icons.support_agent_rounded;
    case 'content-policy':
      return Icons.rule_rounded;
    case 'copyright':
      return Icons.copyright_rounded;
    case 'refunds':
      return Icons.currency_exchange_rounded;
    default:
      return Icons.description_outlined;
  }
}
