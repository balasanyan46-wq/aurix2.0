import 'dnk_models.dart';

class DnkQuestion {
  final String id;
  final String type; // scale | forced_choice | sjt | open
  final String text;
  final List<DnkQuestionOption>? options;
  final DnkScaleLabels? scaleLabels;
  final bool isFollowup;

  const DnkQuestion({
    required this.id,
    required this.type,
    required this.text,
    this.options,
    this.scaleLabels,
    this.isFollowup = false,
  });
}

const List<DnkQuestion> dnkCoreQuestions = [
  // ── SCALE 1..5 (16 questions) ───────────────────────────────
  DnkQuestion(
    id: 'q01_energy_drive',
    type: 'scale',
    text: 'Мне ближе быстрая, напористая музыка — чем спокойная и плавная.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q02_energy_stamina',
    type: 'scale',
    text: 'Я могу работать на максимуме несколько недель подряд и не выгорать.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q03_novelty_risk',
    type: 'scale',
    text: 'Я скорее выпущу что-то своё, даже если это не зайдёт массово.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q04_novelty_iteration',
    type: 'scale',
    text: 'Мне нравится ломать то, что уже работает, — пробовать новый звук или подачу.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q05_darkness_vector',
    type: 'scale',
    text: 'Моя музыка чаще про тень и драму, чем про свет и лёгкость.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q06_darkness_boundaries',
    type: 'scale',
    text: 'Даже в тяжёлых темах я оставлю надежду — полная безысходность не моё.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q07_lyric_truth',
    type: 'scale',
    text: 'Мне тяжело исполнять текст, если он не про реальные вещи.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q08_lyric_technique',
    type: 'scale',
    text: 'Мне важнее подача и вайб — а не глубокий смысл в каждой строке.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q09_structure_planning',
    type: 'scale',
    text: 'С планом и дедлайнами я делаю лучший результат.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q10_structure_flow',
    type: 'scale',
    text: 'Лучшее у меня получается в потоке: пришло — сел — сделал.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q11_publicness_attention',
    type: 'scale',
    text: 'Камера, сцена, эфиры — мне в кайф быть на виду.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q12_publicness_privacy',
    type: 'scale',
    text: 'Пусть за меня говорит музыка — личное я держу при себе.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q13_conflict_direct',
    type: 'scale',
    text: 'В конфликте я режу прямо и быстро, даже если жёстко.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q14_conflict_diplomacy',
    type: 'scale',
    text: 'Чаще я сглаживаю углы, чем иду в лобовое столкновение.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q15_commercial_instinct',
    type: 'scale',
    text: 'Я думаю цифрами: охваты, плейлисты, удержание — и подстраиваю подачу.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),
  DnkQuestion(
    id: 'q16_commercial_integrity',
    type: 'scale',
    text: 'Я не поменяю своё ради цифр — даже если это замедлит рост.',
    scaleLabels: DnkScaleLabels(low: 'Совсем нет', high: 'Да, точно'),
  ),

  // ── FORCED CHOICE (4 questions) ─────────────────────────────
  DnkQuestion(
    id: 'q17_fc_unique_vs_mass',
    type: 'forced_choice',
    text: 'Что тебе ближе: делать своё или делать масштабное?',
    options: [
      DnkQuestionOption(key: 'A', text: 'Сделать странно, но своё — пусть не всем зайдёт'),
      DnkQuestionOption(key: 'B', text: 'Сделать понятно и стабильно — чтобы масштабировалось'),
    ],
  ),
  DnkQuestion(
    id: 'q18_fc_dark_vs_bright',
    type: 'forced_choice',
    text: 'Ядро твоей музыки — это скорее:',
    options: [
      DnkQuestionOption(key: 'A', text: 'Тень, драма, напряжение'),
      DnkQuestionOption(key: 'B', text: 'Свет, лёгкость, энергия'),
    ],
  ),
  DnkQuestion(
    id: 'q19_fc_plan_vs_flow',
    type: 'forced_choice',
    text: 'Когда ты реально делаешь лучшее?',
    options: [
      DnkQuestionOption(key: 'A', text: 'Когда есть план, этапы и контроль'),
      DnkQuestionOption(key: 'B', text: 'Когда ловлю поток и делаю на импульсе'),
    ],
  ),
  DnkQuestion(
    id: 'q20_fc_public_style',
    type: 'forced_choice',
    text: 'Твой стиль на публике:',
    options: [
      DnkQuestionOption(key: 'A', text: 'Я — лицо бренда, люблю общаться и быть на виду'),
      DnkQuestionOption(key: 'B', text: 'Я скрытнее: пусть внимание на музыке, не на мне'),
    ],
  ),

  // ── SJT SCENARIOS (3 questions) ─────────────────────────────
  DnkQuestion(
    id: 'q21_sjt_hate_comment',
    type: 'sjt',
    text: 'Под Reels пишут: «Кринж. Очередной позёр». Что делаешь?',
    options: [
      DnkQuestionOption(key: 'A', text: 'Игнорирую и продолжаю выкладывать'),
      DnkQuestionOption(key: 'B', text: 'Отвечаю спокойно или с иронией'),
      DnkQuestionOption(key: 'C', text: 'Отвечаю жёстко, ставлю на место'),
      DnkQuestionOption(key: 'D', text: 'Удаляю комментарий — не хочу триггериться'),
    ],
  ),
  DnkQuestion(
    id: 'q22_sjt_release_failed',
    type: 'sjt',
    text: 'Релиз не залетел, цифры слабые. Первое действие?',
    options: [
      DnkQuestionOption(key: 'A', text: 'Резко меняю стиль — ищу новое'),
      DnkQuestionOption(key: 'B', text: 'Докручиваю подачу, не меняя суть музыки'),
      DnkQuestionOption(key: 'C', text: 'Беру паузу — мне нужно переварить'),
      DnkQuestionOption(key: 'D', text: 'Иду к команде/наставнику за разбором'),
    ],
  ),
  DnkQuestion(
    id: 'q23_sjt_team_deadline',
    type: 'sjt',
    text: 'Человек в команде второй раз срывает дедлайн. Что делаешь?',
    options: [
      DnkQuestionOption(key: 'A', text: 'Меняю исполнителя без разговоров'),
      DnkQuestionOption(key: 'B', text: 'Жёсткий разговор + условия + контроль'),
      DnkQuestionOption(key: 'C', text: 'Пытаюсь понять причины и помочь'),
      DnkQuestionOption(key: 'D', text: 'Беру часть задачи на себя, чтобы спасти'),
    ],
  ),

  // ── OPEN (2 questions) ──────────────────────────────────────
  DnkQuestion(
    id: 'q24_open_identity',
    type: 'open',
    text: 'Продолжи одной фразой: «Моя музыка — это …»',
  ),
  DnkQuestion(
    id: 'q25_open_nonnegotiable',
    type: 'open',
    text: 'Что ты никогда не продашь ради хайпа?',
  ),

  // ═══════════════════════════════════════════════════════════
  // ── SOCIAL MAGNETISM (12 questions) ────────────────────────
  // ═══════════════════════════════════════════════════════════

  // ── SJT: social scenarios (6) ─────────────────────────────
  DnkQuestion(
    id: 'q26_sjt_hate_wave',
    type: 'sjt',
    text: 'Под постом — волна хейта: «зазнался», «кто ты такой». Что делаешь?',
    options: [
      DnkQuestionOption(key: 'A', text: 'Пишу развёрнутый ответ, объясняю позицию'),
      DnkQuestionOption(key: 'B', text: 'Один саркастичный ответ — и дальше работаю'),
      DnkQuestionOption(key: 'C', text: 'Молча удаляю и блокирую'),
      DnkQuestionOption(key: 'D', text: 'Превращаю хейт в контент — сторис или видео'),
    ],
  ),
  DnkQuestion(
    id: 'q27_sjt_ignored',
    type: 'sjt',
    text: 'Написал важному человеку. Тишина уже неделю. Что дальше?',
    options: [
      DnkQuestionOption(key: 'A', text: 'Пишу повторно, прямо спрашиваю'),
      DnkQuestionOption(key: 'B', text: 'Нахожу другой путь — обхожу стороной'),
      DnkQuestionOption(key: 'C', text: 'Жду ещё — может, человек занят'),
      DnkQuestionOption(key: 'D', text: 'Делаю контент, где косвенно привлекаю внимание'),
    ],
  ),
  DnkQuestion(
    id: 'q28_sjt_betrayal',
    type: 'sjt',
    text: 'Человек из команды подвёл в критический момент. Первый шаг?',
    options: [
      DnkQuestionOption(key: 'A', text: 'Убираю из проекта сразу, без разговоров'),
      DnkQuestionOption(key: 'B', text: 'Жёсткий разговор один на один, даю шанс'),
      DnkQuestionOption(key: 'C', text: 'Публично обозначаю ситуацию, чтобы не повторилось'),
      DnkQuestionOption(key: 'D', text: 'Пытаюсь понять причину, но дистанцируюсь'),
    ],
  ),
  DnkQuestion(
    id: 'q29_sjt_viral',
    type: 'sjt',
    text: 'Твой трек завирусился. +50k за сутки. Что делаешь?',
    options: [
      DnkQuestionOption(key: 'A', text: 'Сразу леплю контент — сторис, Reels, эфиры'),
      DnkQuestionOption(key: 'B', text: 'Делаю паузу, чтобы не наломать дров'),
      DnkQuestionOption(key: 'C', text: 'Пишу честный пост: «вот что я чувствую»'),
      DnkQuestionOption(key: 'D', text: 'Готовлю следующий релиз, пока внимание горячее'),
    ],
  ),
  DnkQuestion(
    id: 'q30_sjt_public_mistake',
    type: 'sjt',
    text: 'Ты публично ошибся — неудачный пост, косяк на сцене. Реакция?',
    options: [
      DnkQuestionOption(key: 'A', text: 'Признаю ошибку публично и двигаюсь дальше'),
      DnkQuestionOption(key: 'B', text: 'Молча удаляю — все забудут'),
      DnkQuestionOption(key: 'C', text: 'Превращаю в шутку/мем — обращаю в плюс'),
      DnkQuestionOption(key: 'D', text: 'Прошу команду разрулить, сам ухожу в тень'),
    ],
  ),
  DnkQuestion(
    id: 'q31_sjt_be_softer',
    type: 'sjt',
    text: 'Тебе говорят: «Будь проще, помягче — так больше людей придёт». Что делаешь?',
    options: [
      DnkQuestionOption(key: 'A', text: 'Слушаю и пробую — может, они правы'),
      DnkQuestionOption(key: 'B', text: 'Вежливо отказываюсь — мой стиль не про мягкость'),
      DnkQuestionOption(key: 'C', text: 'Игнорирую — это не обсуждается'),
      DnkQuestionOption(key: 'D', text: 'Нахожу компромисс: в контенте мягче, в музыке нет'),
    ],
  ),

  // ── FORCED CHOICE: social magnetism (4) ───────────────────
  DnkQuestion(
    id: 'q32_fc_close_vs_strong',
    type: 'forced_choice',
    text: 'Что для бренда ценнее?',
    options: [
      DnkQuestionOption(key: 'A', text: 'Быть ближе к людям — доступность, «свой»'),
      DnkQuestionOption(key: 'B', text: 'Быть сильнее — авторитет, дистанция'),
    ],
  ),
  DnkQuestion(
    id: 'q33_fc_stable_vs_unpredictable',
    type: 'forced_choice',
    text: 'Твой публичный образ — это:',
    options: [
      DnkQuestionOption(key: 'A', text: 'Стабильность: узнаваемый стиль, предсказуемость'),
      DnkQuestionOption(key: 'B', text: 'Непредсказуемость: удивлять, ломать ожидания'),
    ],
  ),
  DnkQuestion(
    id: 'q34_fc_direct_vs_diplomatic',
    type: 'forced_choice',
    text: 'Как ты общаешься с людьми?',
    options: [
      DnkQuestionOption(key: 'A', text: 'Прямо — говорю как есть, даже если режет'),
      DnkQuestionOption(key: 'B', text: 'Дипломатично — выбираю слова ради результата'),
    ],
  ),
  DnkQuestion(
    id: 'q35_fc_face_vs_music',
    type: 'forced_choice',
    text: 'Ты как артист — это скорее:',
    options: [
      DnkQuestionOption(key: 'A', text: 'Я — лицо бренда, моя личность и есть продукт'),
      DnkQuestionOption(key: 'B', text: 'Пусть говорит музыка, а я за ней'),
    ],
  ),

  // ── OPEN: social magnetism (2) ────────────────────────────
  DnkQuestion(
    id: 'q36_open_attract',
    type: 'open',
    text: 'Продолжи: «Люди тянутся ко мне, когда я…»',
  ),
  DnkQuestion(
    id: 'q37_open_repel',
    type: 'open',
    text: 'Продолжи: «Люди отдаляются, когда я…»',
  ),
];

/// Axis display config for the UI
class DnkAxisInfo {
  final String key;
  final String label;
  final String lowLabel;
  final String highLabel;

  const DnkAxisInfo({
    required this.key,
    required this.label,
    required this.lowLabel,
    required this.highLabel,
  });
}

const List<DnkAxisInfo> dnkAxesInfo = [
  DnkAxisInfo(key: 'energy', label: 'Энергия', lowLabel: 'Спокойный', highLabel: 'Взрывной'),
  DnkAxisInfo(key: 'novelty', label: 'Новаторство', lowLabel: 'Традиционный', highLabel: 'Экспериментальный'),
  DnkAxisInfo(key: 'darkness', label: 'Темнота', lowLabel: 'Светлый', highLabel: 'Мрачный'),
  DnkAxisInfo(key: 'lyric_focus', label: 'Фокус на текст', lowLabel: 'Подача/флоу', highLabel: 'Смысл/текст'),
  DnkAxisInfo(key: 'structure', label: 'Структура', lowLabel: 'Поток/импульс', highLabel: 'План/контроль'),
  DnkAxisInfo(key: 'conflict_style', label: 'Конфликтность', lowLabel: 'Дипломат', highLabel: 'Прямой'),
  DnkAxisInfo(key: 'publicness', label: 'Публичность', lowLabel: 'Закрытый', highLabel: 'Открытый'),
  DnkAxisInfo(key: 'commercial_focus', label: 'Коммерция', lowLabel: 'Искусство', highLabel: 'Рынок'),
];

const List<DnkAxisInfo> dnkSocialAxesInfo = [
  DnkAxisInfo(key: 'warmth', label: 'Тепло', lowLabel: 'Дистанция', highLabel: 'Близость'),
  DnkAxisInfo(key: 'power', label: 'Сила', lowLabel: 'Мягкий', highLabel: 'Авторитет'),
  DnkAxisInfo(key: 'edge', label: 'Нерв', lowLabel: 'Стабильный', highLabel: 'Провокатор'),
  DnkAxisInfo(key: 'clarity', label: 'Ясность', lowLabel: 'Загадка', highLabel: 'Прозрачность'),
];
