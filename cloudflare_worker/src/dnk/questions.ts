import type { DnkQuestion } from "./types";

export const DNK_CORE_QUESTIONS: DnkQuestion[] = [
  // ── SCALE 1..5 (16 questions) ───────────────────────────────
  {
    id: "q01_energy_drive",
    type: "scale",
    text: "Мне ближе быстрая, напористая музыка — чем спокойная и плавная.",
    scale: { min: 1, max: 5, labels: ["Совсем нет", "", "50/50", "", "Да, точно"] },
    axis_weights: { energy: 12 },
    followup_rules: [{ if_axis_uncertain: "energy", ask: ["f01_energy_context"] }],
  },
  {
    id: "q02_energy_stamina",
    type: "scale",
    text: "Я могу работать на максимуме несколько недель подряд и не выгорать.",
    scale: { min: 1, max: 5 },
    axis_weights: { energy: 6, structure: 4 },
    followup_rules: [{ if_axis_uncertain: "structure", ask: ["f02_structure_deadlines"] }],
  },
  {
    id: "q03_novelty_risk",
    type: "scale",
    text: "Я скорее выпущу что-то своё, даже если это не зайдёт массово.",
    scale: { min: 1, max: 5 },
    axis_weights: { novelty: 12, commercial_focus: -6 },
    followup_rules: [{ if_axis_conflict: ["novelty", "commercial_focus"], ask: ["f03_tradeoff_unique_vs_mass"] }],
  },
  {
    id: "q04_novelty_iteration",
    type: "scale",
    text: "Мне нравится ломать то, что уже работает, — пробовать новый звук или подачу.",
    scale: { min: 1, max: 5 },
    axis_weights: { novelty: 10 },
  },
  {
    id: "q05_darkness_vector",
    type: "scale",
    text: "Моя музыка чаще про тень и драму, чем про свет и лёгкость.",
    scale: { min: 1, max: 5 },
    axis_weights: { darkness: 12 },
  },
  {
    id: "q06_darkness_boundaries",
    type: "scale",
    text: "Даже в тяжёлых темах я оставлю надежду — полная безысходность не моё.",
    scale: { min: 1, max: 5 },
    axis_weights: { darkness: -6, lyric_focus: 4 },
  },
  {
    id: "q07_lyric_truth",
    type: "scale",
    text: "Мне тяжело исполнять текст, если он не про реальные вещи.",
    scale: { min: 1, max: 5 },
    axis_weights: { lyric_focus: 10 },
  },
  {
    id: "q08_lyric_technique",
    type: "scale",
    text: "Мне важнее подача и вайб — а не глубокий смысл в каждой строке.",
    scale: { min: 1, max: 5 },
    axis_weights: { lyric_focus: -10, commercial_focus: 4 },
    followup_rules: [{ if_axis_conflict: ["lyric_focus"], ask: ["f04_lyrics_priority_check"] }],
  },
  {
    id: "q09_structure_planning",
    type: "scale",
    text: "С планом и дедлайнами я делаю лучший результат.",
    scale: { min: 1, max: 5 },
    axis_weights: { structure: 12 },
  },
  {
    id: "q10_structure_flow",
    type: "scale",
    text: "Лучшее у меня получается в потоке: пришло — сел — сделал.",
    scale: { min: 1, max: 5 },
    axis_weights: { structure: -10, novelty: 4 },
  },
  {
    id: "q11_publicness_attention",
    type: "scale",
    text: "Камера, сцена, эфиры — мне в кайф быть на виду.",
    scale: { min: 1, max: 5 },
    axis_weights: { publicness: 12 },
  },
  {
    id: "q12_publicness_privacy",
    type: "scale",
    text: "Пусть за меня говорит музыка — личное я держу при себе.",
    scale: { min: 1, max: 5 },
    axis_weights: { publicness: -10, lyric_focus: 4 },
  },
  {
    id: "q13_conflict_direct",
    type: "scale",
    text: "В конфликте я режу прямо и быстро, даже если жёстко.",
    scale: { min: 1, max: 5 },
    axis_weights: { conflict_style: 12 },
  },
  {
    id: "q14_conflict_diplomacy",
    type: "scale",
    text: "Чаще я сглаживаю углы, чем иду в лобовое столкновение.",
    scale: { min: 1, max: 5 },
    axis_weights: { conflict_style: -12 },
  },
  {
    id: "q15_commercial_instinct",
    type: "scale",
    text: "Я думаю цифрами: охваты, плейлисты, удержание — и подстраиваю подачу.",
    scale: { min: 1, max: 5 },
    axis_weights: { commercial_focus: 12 },
  },
  {
    id: "q16_commercial_integrity",
    type: "scale",
    text: "Я не поменяю своё ради цифр — даже если это замедлит рост.",
    scale: { min: 1, max: 5 },
    axis_weights: { commercial_focus: -10, novelty: 4 },
  },

  // ── FORCED CHOICE (4 questions) ─────────────────────────────
  {
    id: "q17_fc_unique_vs_mass",
    type: "forced_choice",
    text: "Что тебе ближе: делать своё или делать масштабное?",
    axis_weights: {},
    options: [
      { id: "A", label: "Сделать странно, но своё — пусть не всем зайдёт", axis_weights: { novelty: 14, commercial_focus: -8 } },
      { id: "B", label: "Сделать понятно и стабильно — чтобы масштабировалось", axis_weights: { novelty: -10, commercial_focus: 12 } },
    ],
    followup_rules: [{ if_axis_uncertain: "novelty", ask: ["f03_tradeoff_unique_vs_mass"] }],
  },
  {
    id: "q18_fc_dark_vs_bright",
    type: "forced_choice",
    text: "Ядро твоей музыки — это скорее:",
    axis_weights: {},
    options: [
      { id: "A", label: "Тень, драма, напряжение", axis_weights: { darkness: 14 } },
      { id: "B", label: "Свет, лёгкость, энергия", axis_weights: { darkness: -12, energy: 4 } },
    ],
  },
  {
    id: "q19_fc_plan_vs_flow",
    type: "forced_choice",
    text: "Когда ты реально делаешь лучшее?",
    axis_weights: {},
    options: [
      { id: "A", label: "Когда есть план, этапы и контроль", axis_weights: { structure: 14 } },
      { id: "B", label: "Когда ловлю поток и делаю на импульсе", axis_weights: { structure: -12, novelty: 4 } },
    ],
  },
  {
    id: "q20_fc_public_style",
    type: "forced_choice",
    text: "Твой стиль на публике:",
    axis_weights: {},
    options: [
      { id: "A", label: "Я — лицо бренда, люблю общаться и быть на виду", axis_weights: { publicness: 14 } },
      { id: "B", label: "Я скрытнее: пусть внимание на музыке, не на мне", axis_weights: { publicness: -14 } },
    ],
  },

  // ── SJT SCENARIOS (3 questions) ─────────────────────────────
  {
    id: "q21_sjt_hate_comment",
    type: "sjt",
    text: "Под Reels пишут: «Кринж. Очередной позёр». Что делаешь?",
    axis_weights: {},
    options: [
      { id: "A", label: "Игнорирую и продолжаю выкладывать", axis_weights: { structure: 6, publicness: 4 } },
      { id: "B", label: "Отвечаю спокойно или с иронией", axis_weights: { conflict_style: -8, publicness: 6 } },
      { id: "C", label: "Отвечаю жёстко, ставлю на место", axis_weights: { conflict_style: 12, publicness: 4 } },
      { id: "D", label: "Удаляю комментарий — не хочу триггериться", axis_weights: { publicness: -8, structure: -4 } },
    ],
    followup_rules: [{ if_axis_uncertain: "conflict_style", ask: ["f05_conflict_reply_style"] }],
  },
  {
    id: "q22_sjt_release_failed",
    type: "sjt",
    text: "Релиз не залетел, цифры слабые. Первое действие?",
    axis_weights: {},
    options: [
      { id: "A", label: "Резко меняю стиль — ищу новое", axis_weights: { novelty: 10, structure: -6 } },
      { id: "B", label: "Докручиваю подачу, не меняя суть музыки", axis_weights: { structure: 10, commercial_focus: 6 } },
      { id: "C", label: "Беру паузу — мне нужно переварить", axis_weights: { energy: -6, publicness: -4 } },
      { id: "D", label: "Иду к команде/наставнику за разбором", axis_weights: { structure: 8, publicness: 4 } },
    ],
  },
  {
    id: "q23_sjt_team_deadline",
    type: "sjt",
    text: "Человек в команде второй раз срывает дедлайн. Что делаешь?",
    axis_weights: {},
    options: [
      { id: "A", label: "Меняю исполнителя без разговоров", axis_weights: { conflict_style: 8, structure: 6 } },
      { id: "B", label: "Жёсткий разговор + условия + контроль", axis_weights: { conflict_style: 10, structure: 10 } },
      { id: "C", label: "Пытаюсь понять причины и помочь", axis_weights: { conflict_style: -8, structure: 6 } },
      { id: "D", label: "Беру часть задачи на себя, чтобы спасти", axis_weights: { structure: 6, energy: -2 } },
    ],
  },

  // ── OPEN (2 questions) ──────────────────────────────────────
  {
    id: "q24_open_identity",
    type: "open",
    text: "Продолжи одной фразой: «Моя музыка — это …»",
    axis_weights: {},
  },
  {
    id: "q25_open_nonnegotiable",
    type: "open",
    text: "Что ты никогда не продашь ради хайпа?",
    axis_weights: {},
  },

  // ═══════════════════════════════════════════════════════════
  // ── SOCIAL MAGNETISM (12 questions) ────────────────────────
  // ═══════════════════════════════════════════════════════════

  // ── SJT: social scenarios (6) ─────────────────────────────
  {
    id: "q26_sjt_hate_wave",
    type: "sjt",
    text: "Под постом — волна хейта: «зазнался», «кто ты такой». Что делаешь?",
    axis_weights: {},
    options: [
      { id: "A", label: "Пишу развёрнутый ответ, объясняю позицию", axis_weights: { clarity: 8, warmth: 6 } },
      { id: "B", label: "Один саркастичный ответ — и дальше работаю", axis_weights: { edge: 10, power: 6 } },
      { id: "C", label: "Молча удаляю и блокирую", axis_weights: { power: -4, warmth: -4 } },
      { id: "D", label: "Превращаю хейт в контент — сторис или видео", axis_weights: { edge: 8, power: 10 } },
    ],
  },
  {
    id: "q27_sjt_ignored",
    type: "sjt",
    text: "Написал важному человеку. Тишина уже неделю. Что дальше?",
    axis_weights: {},
    options: [
      { id: "A", label: "Пишу повторно, прямо спрашиваю", axis_weights: { power: 6, clarity: 8 } },
      { id: "B", label: "Нахожу другой путь — обхожу стороной", axis_weights: { edge: 4, clarity: -4 } },
      { id: "C", label: "Жду ещё — может, человек занят", axis_weights: { warmth: 6, power: -6 } },
      { id: "D", label: "Делаю контент, где косвенно привлекаю внимание", axis_weights: { edge: 8, power: 4 } },
    ],
  },
  {
    id: "q28_sjt_betrayal",
    type: "sjt",
    text: "Человек из команды подвёл в критический момент. Первый шаг?",
    axis_weights: {},
    options: [
      { id: "A", label: "Убираю из проекта сразу, без разговоров", axis_weights: { power: 10, warmth: -8 } },
      { id: "B", label: "Жёсткий разговор один на один, даю шанс", axis_weights: { clarity: 8, power: 6 } },
      { id: "C", label: "Публично обозначаю ситуацию, чтобы не повторилось", axis_weights: { edge: 8, clarity: 6 } },
      { id: "D", label: "Пытаюсь понять причину, но дистанцируюсь", axis_weights: { warmth: 4, clarity: 4 } },
    ],
  },
  {
    id: "q29_sjt_viral",
    type: "sjt",
    text: "Твой трек завирусился. +50k за сутки. Что делаешь?",
    axis_weights: {},
    options: [
      { id: "A", label: "Сразу леплю контент — сторис, Reels, эфиры", axis_weights: { power: 8, edge: 6 } },
      { id: "B", label: "Делаю паузу, чтобы не наломать дров", axis_weights: { clarity: 8, warmth: -4 } },
      { id: "C", label: "Пишу честный пост: «вот что я чувствую»", axis_weights: { warmth: 10, clarity: 6 } },
      { id: "D", label: "Готовлю следующий релиз, пока внимание горячее", axis_weights: { power: 6, clarity: 4 } },
    ],
  },
  {
    id: "q30_sjt_public_mistake",
    type: "sjt",
    text: "Ты публично ошибся — неудачный пост, косяк на сцене. Реакция?",
    axis_weights: {},
    options: [
      { id: "A", label: "Признаю ошибку публично и двигаюсь дальше", axis_weights: { clarity: 12, warmth: 6 } },
      { id: "B", label: "Молча удаляю — все забудут", axis_weights: { power: -4, clarity: -8 } },
      { id: "C", label: "Превращаю в шутку/мем — обращаю в плюс", axis_weights: { edge: 10, power: 6 } },
      { id: "D", label: "Прошу команду разрулить, сам ухожу в тень", axis_weights: { warmth: -6, power: -6 } },
    ],
  },
  {
    id: "q31_sjt_be_softer",
    type: "sjt",
    text: "Тебе говорят: «Будь проще, помягче — так больше людей придёт». Что делаешь?",
    axis_weights: {},
    options: [
      { id: "A", label: "Слушаю и пробую — может, они правы", axis_weights: { warmth: 6, edge: -8 } },
      { id: "B", label: "Вежливо отказываюсь — мой стиль не про мягкость", axis_weights: { clarity: 8, edge: 6 } },
      { id: "C", label: "Игнорирую — это не обсуждается", axis_weights: { edge: 10, power: 4 } },
      { id: "D", label: "Нахожу компромисс: в контенте мягче, в музыке нет", axis_weights: { warmth: 4, clarity: 4 } },
    ],
  },

  // ── FORCED CHOICE: social magnetism (4) ───────────────────
  {
    id: "q32_fc_close_vs_strong",
    type: "forced_choice",
    text: "Что для бренда ценнее?",
    axis_weights: {},
    options: [
      { id: "A", label: "Быть ближе к людям — доступность, «свой»", axis_weights: { warmth: 14, power: -6 } },
      { id: "B", label: "Быть сильнее — авторитет, дистанция", axis_weights: { power: 14, warmth: -6 } },
    ],
  },
  {
    id: "q33_fc_stable_vs_unpredictable",
    type: "forced_choice",
    text: "Твой публичный образ — это:",
    axis_weights: {},
    options: [
      { id: "A", label: "Стабильность: узнаваемый стиль, предсказуемость", axis_weights: { clarity: 12, edge: -8 } },
      { id: "B", label: "Непредсказуемость: удивлять, ломать ожидания", axis_weights: { edge: 14, clarity: -6 } },
    ],
  },
  {
    id: "q34_fc_direct_vs_diplomatic",
    type: "forced_choice",
    text: "Как ты общаешься с людьми?",
    axis_weights: {},
    options: [
      { id: "A", label: "Прямо — говорю как есть, даже если режет", axis_weights: { edge: 10, clarity: 8 } },
      { id: "B", label: "Дипломатично — выбираю слова ради результата", axis_weights: { warmth: 8, clarity: 4 } },
    ],
  },
  {
    id: "q35_fc_face_vs_music",
    type: "forced_choice",
    text: "Ты как артист — это скорее:",
    axis_weights: {},
    options: [
      { id: "A", label: "Я — лицо бренда, моя личность и есть продукт", axis_weights: { power: 10, warmth: 6 } },
      { id: "B", label: "Пусть говорит музыка, а я за ней", axis_weights: { clarity: 6, edge: -4 } },
    ],
  },

  // ── OPEN: social magnetism (2) ────────────────────────────
  {
    id: "q36_open_attract",
    type: "open",
    text: "Продолжи: «Люди тянутся ко мне, когда я…»",
    axis_weights: {},
  },
  {
    id: "q37_open_repel",
    type: "open",
    text: "Продолжи: «Люди отдаляются, когда я…»",
    axis_weights: {},
  },
];

// ── ADAPTIVE FOLLOWUP QUESTIONS ─────────────────────────────
export const DNK_FOLLOWUP_QUESTIONS: DnkQuestion[] = [
  {
    id: "f01_energy_context",
    type: "forced_choice",
    text: "Где ты сильнее как артист?",
    axis_weights: {},
    options: [
      { id: "A", label: "В высоком драйве, напоре, взрыве", axis_weights: { energy: 10 } },
      { id: "B", label: "В спокойной глубине, атмосфере, тонкости", axis_weights: { energy: -10, darkness: 4 } },
    ],
  },
  {
    id: "f02_structure_deadlines",
    type: "scale",
    text: "Без дедлайна и контроля я часто откладываю и растягиваю процесс.",
    scale: { min: 1, max: 5 },
    axis_weights: { structure: -12 },
  },
  {
    id: "f03_tradeoff_unique_vs_mass",
    type: "forced_choice",
    text: "Если выбирать одно на полгода:",
    axis_weights: {},
    options: [
      { id: "A", label: "Делать узнаваемый «хитовый» коридор", axis_weights: { commercial_focus: 12, novelty: -6 } },
      { id: "B", label: "Делать новый звук/образ и рискнуть цифрами", axis_weights: { novelty: 12, commercial_focus: -8 } },
    ],
  },
  {
    id: "f04_lyrics_priority_check",
    type: "forced_choice",
    text: "Что тебя больше цепляет в любимых треках?",
    axis_weights: {},
    options: [
      { id: "A", label: "Смысл, история, строки, которые режут", axis_weights: { lyric_focus: 10 } },
      { id: "B", label: "Подача, флоу, саунд — даже если смысл простой", axis_weights: { lyric_focus: -10, commercial_focus: 4 } },
    ],
  },
  {
    id: "f05_conflict_reply_style",
    type: "forced_choice",
    text: "Твой стиль ответа на провокацию:",
    axis_weights: {},
    options: [
      { id: "A", label: "Срежу и поставлю точку", axis_weights: { conflict_style: 10 } },
      { id: "B", label: "Переведу в юмор или спокойствие", axis_weights: { conflict_style: -10 } },
    ],
  },
  // ── NEW: fallback for q36/q37 "don't know" answers ────────
  {
    id: "f06_attract_hint",
    type: "sjt",
    text: "Люди тянутся ко мне, когда я:",
    axis_weights: {},
    options: [
      { id: "A", label: "Открыт и на энергии — зажигаю и веду", axis_weights: { warmth: 8, power: 4 } },
      { id: "B", label: "Спокоен и глубок — создаю доверие", axis_weights: { warmth: 10, clarity: 6 } },
      { id: "C", label: "Дерзкий и непредсказуемый — ломаю шаблоны", axis_weights: { edge: 10, power: 4 } },
      { id: "D", label: "Честный и прямой — без фильтров", axis_weights: { clarity: 10, edge: 4 } },
    ],
  },
  {
    id: "f07_repel_hint",
    type: "sjt",
    text: "Люди отдаляются, когда я:",
    axis_weights: {},
    options: [
      { id: "A", label: "Резко режу — и не замечаю, что задел", axis_weights: { edge: 6, warmth: -8 } },
      { id: "B", label: "Пропадаю и молчу без объяснений", axis_weights: { warmth: -6, clarity: -6 } },
      { id: "C", label: "Давлю и требую по-своему", axis_weights: { power: 8, warmth: -6 } },
      { id: "D", label: "Становлюсь холодным и закрытым", axis_weights: { warmth: -10, clarity: -4 } },
    ],
  },
];

export function getFollowupById(id: string): DnkQuestion | undefined {
  return DNK_FOLLOWUP_QUESTIONS.find((q) => q.id === id);
}

export function getAllQuestionsMap(): Map<string, DnkQuestion> {
  const map = new Map<string, DnkQuestion>();
  for (const q of DNK_CORE_QUESTIONS) map.set(q.id, q);
  for (const q of DNK_FOLLOWUP_QUESTIONS) map.set(q.id, q);
  return map;
}
