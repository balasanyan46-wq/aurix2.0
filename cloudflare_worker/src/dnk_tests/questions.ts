import type { DnkTestSlug, TestQuestion } from "./types";

const SCALE = { min: 1, max: 5, labels: ["Совсем нет", "", "50/50", "", "Да, точно"] };

const Q: TestQuestion[] = [
  // 1) Архетип артиста
  { id: "aa_q01", test_slug: "artist_archetype", type: "scale", text: "Мне легче вести сцену, чем вписываться в чужой темп.", scale: SCALE, axis_weights: { stage_power: 12 } },
  { id: "aa_q02", test_slug: "artist_archetype", type: "scale", text: "Уязвимость в тексте усиливает мой образ, а не ослабляет.", scale: SCALE, axis_weights: { vulnerability: 12 } },
  { id: "aa_q03", test_slug: "artist_archetype", type: "scale", text: "Мне важнее удивить, чем соответствовать ожиданиям аудитории.", scale: SCALE, axis_weights: { novelty_drive: 12 } },
  { id: "aa_q04", test_slug: "artist_archetype", type: "scale", text: "Я умею держать единый образ в музыке, контенте и выступлениях.", scale: SCALE, axis_weights: { cohesion: 10 } },
  { id: "aa_q05", test_slug: "artist_archetype", type: "forced_choice", text: "Что точнее про тебя на сцене?", axis_weights: {}, options: [
    { id: "A", label: "Я давлю энергией и направляю зал.", axis_weights: { stage_power: 12, vulnerability: -4 } },
    { id: "B", label: "Я втягиваю через тишину и точность.", axis_weights: { vulnerability: 8, cohesion: 6 } },
  ] },
  { id: "aa_q06", test_slug: "artist_archetype", type: "sjt", text: "Новый трек вызывает спор в команде. Ты:", axis_weights: {}, options: [
    { id: "A", label: "Оставляю рискованный вариант — это мой нерв.", axis_weights: { novelty_drive: 10, stage_power: 4 } },
    { id: "B", label: "Ищу версию, где риск сохраняется, но образ цельный.", axis_weights: { cohesion: 10, novelty_drive: 4 } },
    { id: "C", label: "Откладываю релиз до полной уверенности.", axis_weights: { cohesion: 4, stage_power: -6 } },
  ] },
  { id: "aa_q07", test_slug: "artist_archetype", type: "scale", text: "Когда меня не понимают сразу, я всё равно держу линию.", scale: SCALE, axis_weights: { stage_power: 8, cohesion: 4 } },
  { id: "aa_q08", test_slug: "artist_archetype", type: "scale", text: "Я готов менять форму, если суть образа остаётся честной.", scale: SCALE, axis_weights: { novelty_drive: 8, cohesion: 6 } },
  { id: "aa_q09", test_slug: "artist_archetype", type: "forced_choice", text: "Твой главный ресурс в моменте:", axis_weights: {}, options: [
    { id: "A", label: "Контроль и рамка.", axis_weights: { cohesion: 10 } },
    { id: "B", label: "Импульс и риск.", axis_weights: { novelty_drive: 10 } },
  ], followup_rules: [{ if_axis_conflict: ["cohesion", "novelty_drive"], ask: ["aa_f01"] }] },
  { id: "aa_q10", test_slug: "artist_archetype", type: "sjt", text: "После сильного фидбэка ты:", axis_weights: {}, options: [
    { id: "A", label: "Делаю версию «жёстче» и иду до конца.", axis_weights: { stage_power: 8, novelty_drive: 6 } },
    { id: "B", label: "Оставляю силу, но открываю больше человеческого.", axis_weights: { vulnerability: 8, cohesion: 6 } },
    { id: "C", label: "Снижаю интенсивность, чтобы не оттолкнуть.", axis_weights: { stage_power: -8, vulnerability: 4 } },
  ] },
  { id: "aa_q11", test_slug: "artist_archetype", type: "open", text: "Одной фразой: в чём твоя сценическая роль?", axis_weights: {} },
  { id: "aa_q12", test_slug: "artist_archetype", type: "open", text: "Что в твоём образе должно оставаться неизменным при любом росте?", axis_weights: {} },
  { id: "aa_f01", test_slug: "artist_archetype", type: "forced_choice", text: "Если выбирать одно на 3 месяца:", axis_weights: {}, options: [
    { id: "A", label: "Стабильный образ и узнаваемость.", axis_weights: { cohesion: 10, novelty_drive: -4 } },
    { id: "B", label: "Серию экспериментов ради новой роли.", axis_weights: { novelty_drive: 10, cohesion: -4 } },
  ] },

  // 2) Тон коммуникации
  { id: "tc_q01", test_slug: "tone_communication", type: "scale", text: "Я говорю прямо, даже если это звучит резко.", scale: SCALE, axis_weights: { directness: 12 } },
  { id: "tc_q02", test_slug: "tone_communication", type: "scale", text: "Тепло и поддержка в тексте важнее удара.", scale: SCALE, axis_weights: { warmth: 12 } },
  { id: "tc_q03", test_slug: "tone_communication", type: "scale", text: "Провокация помогает мне удерживать внимание.", scale: SCALE, axis_weights: { provocation: 12 } },
  { id: "tc_q04", test_slug: "tone_communication", type: "scale", text: "Чистая и понятная формулировка важнее «красивого тумана».", scale: SCALE, axis_weights: { clarity: 12 } },
  { id: "tc_q05", test_slug: "tone_communication", type: "forced_choice", text: "В сторис ты чаще:", axis_weights: {}, options: [
    { id: "A", label: "Бьёшь тезисом и коротким выводом.", axis_weights: { directness: 10, clarity: 6 } },
    { id: "B", label: "Ведёшь через личный контекст и эмоцию.", axis_weights: { warmth: 10, provocation: -4 } },
  ] },
  { id: "tc_q06", test_slug: "tone_communication", type: "sjt", text: "Твой пост неправильно поняли. Что делаешь?", axis_weights: {}, options: [
    { id: "A", label: "Поясняю позицию в 3 пунктах.", axis_weights: { clarity: 10, directness: 6 } },
    { id: "B", label: "Отвечаю мягко и снимаю напряжение.", axis_weights: { warmth: 10 } },
    { id: "C", label: "Поднимаю градус и оборачиваю в дискуссию.", axis_weights: { provocation: 10, directness: 4 } },
  ] },
  { id: "tc_q07", test_slug: "tone_communication", type: "scale", text: "Мне важно оставлять пространство для интерпретации.", scale: SCALE, axis_weights: { clarity: -8, provocation: 4 } },
  { id: "tc_q08", test_slug: "tone_communication", type: "scale", text: "Я осознанно фильтрую слова, чтобы не обесценить аудиторию.", scale: SCALE, axis_weights: { warmth: 8, clarity: 6 } },
  { id: "tc_q09", test_slug: "tone_communication", type: "sjt", text: "Хейтер пишет: «очередной пафос». Ты:", axis_weights: {}, options: [
    { id: "A", label: "Один точный ответ и закрываю тему.", axis_weights: { directness: 8, clarity: 6 } },
    { id: "B", label: "Иронизирую и делаю это частью подачи.", axis_weights: { provocation: 10 } },
    { id: "C", label: "Перевожу в спокойный диалог.", axis_weights: { warmth: 8, directness: -4 } },
  ] },
  { id: "tc_q10", test_slug: "tone_communication", type: "forced_choice", text: "Тебе ближе:", axis_weights: {}, options: [
    { id: "A", label: "Фразы-крючки и острота.", axis_weights: { provocation: 8, directness: 6 } },
    { id: "B", label: "Уверенная простота и уважение.", axis_weights: { warmth: 8, clarity: 6 } },
  ], followup_rules: [{ if_axis_conflict: ["provocation", "warmth"], ask: ["tc_f01"] }] },
  { id: "tc_q11", test_slug: "tone_communication", type: "open", text: "Какие 3 слова лучше всего описывают твой рабочий тон?", axis_weights: {} },
  { id: "tc_q12", test_slug: "tone_communication", type: "open", text: "Какую фразу ты никогда не хочешь читать у себя в контенте?", axis_weights: {} },
  { id: "tc_f01", test_slug: "tone_communication", type: "forced_choice", text: "Если выбирать одно в конфликтном контенте:", axis_weights: {}, options: [
    { id: "A", label: "Сначала удержать внимание.", axis_weights: { provocation: 10, warmth: -4 } },
    { id: "B", label: "Сначала удержать доверие.", axis_weights: { warmth: 10, provocation: -4 } },
  ] },

  // 3) Сюжетное ядро
  { id: "sc_q01", test_slug: "story_core", type: "scale", text: "Меня сильнее цепляет конфликт «близость vs контроль».", scale: SCALE, axis_weights: { inner_conflict: 10 } },
  { id: "sc_q02", test_slug: "story_core", type: "scale", text: "Я пишу глубже, когда в истории есть цена выбора.", scale: SCALE, axis_weights: { narrative_depth: 12 } },
  { id: "sc_q03", test_slug: "story_core", type: "scale", text: "Мне важно показать полный эмоциональный диапазон, а не один тон.", scale: SCALE, axis_weights: { emotional_range: 12 } },
  { id: "sc_q04", test_slug: "story_core", type: "scale", text: "В финале истории мне нужен вектор выхода, а не только боль.", scale: SCALE, axis_weights: { resolution_style: 10 } },
  { id: "sc_q05", test_slug: "story_core", type: "forced_choice", text: "Твоя сильная линия чаще:", axis_weights: {}, options: [
    { id: "A", label: "Внутренний монолог и саморазбор.", axis_weights: { narrative_depth: 10, inner_conflict: 6 } },
    { id: "B", label: "Событие и внешняя драма.", axis_weights: { emotional_range: 8, resolution_style: 6 } },
  ] },
  { id: "sc_q06", test_slug: "story_core", type: "sjt", text: "Трек «красивый», но без конфликта. Ты:", axis_weights: {}, options: [
    { id: "A", label: "Добавляю драматический узел в текст.", axis_weights: { narrative_depth: 10, inner_conflict: 6 } },
    { id: "B", label: "Оставляю вайб, не перегружаю смыслом.", axis_weights: { emotional_range: 6, narrative_depth: -6 } },
    { id: "C", label: "Переписываю структуру и развязку.", axis_weights: { resolution_style: 10 } },
  ] },
  { id: "sc_q07", test_slug: "story_core", type: "scale", text: "Линия «потеря статуса/лица» для меня сильнее, чем «романтика».", scale: SCALE, axis_weights: { inner_conflict: 8, emotional_range: 4 } },
  { id: "sc_q08", test_slug: "story_core", type: "scale", text: "Мне легче работать с темой вины, чем с темой стыда.", scale: SCALE, axis_weights: { inner_conflict: 6, resolution_style: 4 } },
  { id: "sc_q09", test_slug: "story_core", type: "forced_choice", text: "В эмоциональной дуге тебе ближе:", axis_weights: {}, options: [
    { id: "A", label: "Медленный разогрев и тяжёлая кульминация.", axis_weights: { narrative_depth: 8, emotional_range: 6 } },
    { id: "B", label: "Резкий вход и короткий удар.", axis_weights: { emotional_range: 8, resolution_style: 4 } },
  ] },
  { id: "sc_q10", test_slug: "story_core", type: "sjt", text: "Слушатели просят «попроще». Ты:", axis_weights: {}, options: [
    { id: "A", label: "Упрощаю язык, но оставляю конфликт.", axis_weights: { resolution_style: 8, narrative_depth: 4 } },
    { id: "B", label: "Оставляю сложный слой как есть.", axis_weights: { narrative_depth: 10 } },
    { id: "C", label: "Делаю две версии подачи темы.", axis_weights: { emotional_range: 6, resolution_style: 8 } },
  ] },
  { id: "sc_q11", test_slug: "story_core", type: "open", text: "Какой конфликт ты повторяешь в разных песнях снова и снова?", axis_weights: {} },
  { id: "sc_q12", test_slug: "story_core", type: "open", text: "Какая тема звучит «чужой» для тебя, даже если она трендовая?", axis_weights: {} },

  // 4) Профиль роста
  { id: "gp_q01", test_slug: "growth_profile", type: "scale", text: "Я лучше расту через регулярный контакт с ядром аудитории.", scale: SCALE, axis_weights: { community_bias: 12 } },
  { id: "gp_q02", test_slug: "growth_profile", type: "scale", text: "Я умею собирать вирусные единицы контента вокруг трека.", scale: SCALE, axis_weights: { viral_bias: 12 } },
  { id: "gp_q03", test_slug: "growth_profile", type: "scale", text: "Плейлисты и редакторские подборки — мой главный ускоритель.", scale: SCALE, axis_weights: { playlist_bias: 12 } },
  { id: "gp_q04", test_slug: "growth_profile", type: "scale", text: "Живые выступления дают мне качественный скачок, а не только охват.", scale: SCALE, axis_weights: { live_bias: 12 } },
  { id: "gp_q05", test_slug: "growth_profile", type: "forced_choice", text: "Если месяц только на один канал:", axis_weights: {}, options: [
    { id: "A", label: "Комьюнити-работа (ядро и UGC).", axis_weights: { community_bias: 12 } },
    { id: "B", label: "Вирусные форматы и короткие клипы.", axis_weights: { viral_bias: 12 } },
  ] },
  { id: "gp_q06", test_slug: "growth_profile", type: "forced_choice", text: "Тебе проще системно масштабировать через:", axis_weights: {}, options: [
    { id: "A", label: "Плейлистную стратегию и репит.", axis_weights: { playlist_bias: 12 } },
    { id: "B", label: "Сцену, ивенты и офлайн присутствие.", axis_weights: { live_bias: 12 } },
  ] },
  { id: "gp_q07", test_slug: "growth_profile", type: "sjt", text: "Трек получил первые 20k прослушиваний. Что первым делом?", axis_weights: {}, options: [
    { id: "A", label: "Запускаю серию UGC-механик.", axis_weights: { community_bias: 8, viral_bias: 4 } },
    { id: "B", label: "Дожимаю плейлистные входы и метаданные.", axis_weights: { playlist_bias: 10 } },
    { id: "C", label: "Собираю локальные лайвы и фан-встречу.", axis_weights: { live_bias: 10, community_bias: 4 } },
  ] },
  { id: "gp_q08", test_slug: "growth_profile", type: "scale", text: "Мне комфортно работать в длинной серии, а не в разовых вспышках.", scale: SCALE, axis_weights: { community_bias: 6, playlist_bias: 6 } },
  { id: "gp_q09", test_slug: "growth_profile", type: "scale", text: "Я готов платить «налог регулярности» ради накопительного роста.", scale: SCALE, axis_weights: { playlist_bias: 6, community_bias: 6 } },
  { id: "gp_q10", test_slug: "growth_profile", type: "sjt", text: "Есть бюджет только на одно направление. Ты выбираешь:", axis_weights: {}, options: [
    { id: "A", label: "Рилсы/шортсы под повторяемый хук.", axis_weights: { viral_bias: 10 } },
    { id: "B", label: "Плейлистный PR + редакторские питчи.", axis_weights: { playlist_bias: 10 } },
    { id: "C", label: "Мини-тур/лайв-сессии.", axis_weights: { live_bias: 10 } },
  ], followup_rules: [{ if_axis_conflict: ["viral_bias", "community_bias"], ask: ["gp_f01"] }] },
  { id: "gp_q11", test_slug: "growth_profile", type: "open", text: "Где ты реально получал лучший рост за последние 6 месяцев?", axis_weights: {} },
  { id: "gp_q12", test_slug: "growth_profile", type: "open", text: "Какой канал ты переоцениваешь, но продолжаешь в него вкладываться?", axis_weights: {} },
  { id: "gp_f01", test_slug: "growth_profile", type: "forced_choice", text: "Что важнее в ближайшие 30 дней?", axis_weights: {}, options: [
    { id: "A", label: "Взрывной охват сейчас.", axis_weights: { viral_bias: 10, community_bias: -4 } },
    { id: "B", label: "Укрепление ядра на дистанции.", axis_weights: { community_bias: 10, viral_bias: -4 } },
  ] },

  // 5) Индекс дисциплины
  { id: "di_q01", test_slug: "discipline_index", type: "scale", text: "Я начинаю работу по расписанию, а не по настроению.", scale: SCALE, axis_weights: { planning: 12 } },
  { id: "di_q02", test_slug: "discipline_index", type: "scale", text: "Я довожу задачу до «готово», даже если интерес просел.", scale: SCALE, axis_weights: { execution: 12 } },
  { id: "di_q03", test_slug: "discipline_index", type: "scale", text: "После срыва я быстро возвращаюсь в ритм без самобичевания.", scale: SCALE, axis_weights: { recovery: 12 } },
  { id: "di_q04", test_slug: "discipline_index", type: "scale", text: "Я умею защищать фокус от отвлекающих задач и чатов.", scale: SCALE, axis_weights: { focus_protection: 12 } },
  { id: "di_q05", test_slug: "discipline_index", type: "sjt", text: "День сорвался полностью. Твой ход:", axis_weights: {}, options: [
    { id: "A", label: "Делаю короткий «минимум дня» и фиксирую следующий старт.", axis_weights: { recovery: 10, planning: 4 } },
    { id: "B", label: "Переношу всё на завтра и закрываю ноутбук.", axis_weights: { recovery: -8 } },
    { id: "C", label: "Работаю до ночи, чтобы отыграться.", axis_weights: { execution: 6, recovery: -4 } },
  ] },
  { id: "di_q06", test_slug: "discipline_index", type: "forced_choice", text: "Что тебя чаще ломает?", axis_weights: {}, options: [
    { id: "A", label: "Сложный вход в задачу.", axis_weights: { planning: -8 } },
    { id: "B", label: "Потеря темпа в середине.", axis_weights: { execution: -8 } },
  ] },
  { id: "di_q07", test_slug: "discipline_index", type: "scale", text: "Я заранее определяю «стоп-правило», чтобы не сорваться в хаос.", scale: SCALE, axis_weights: { focus_protection: 8, planning: 6 } },
  { id: "di_q08", test_slug: "discipline_index", type: "scale", text: "Мне нужна внешняя отчётность (человек/дедлайн), чтобы держать ритм.", scale: SCALE, axis_weights: { execution: 4, planning: -4 } },
  { id: "di_q09", test_slug: "discipline_index", type: "sjt", text: "Внезапно прилетела срочная задача не по приоритету. Ты:", axis_weights: {}, options: [
    { id: "A", label: "Фиксирую в бэклог, текущий слот не трогаю.", axis_weights: { focus_protection: 10 } },
    { id: "B", label: "Переключаюсь сразу, чтобы «не висело».", axis_weights: { focus_protection: -8, recovery: -4 } },
    { id: "C", label: "Даю 15 минут, затем возвращаюсь в основной трек.", axis_weights: { focus_protection: 6, recovery: 6 } },
  ] },
  { id: "di_q10", test_slug: "discipline_index", type: "forced_choice", text: "Твой лучший формат работы:", axis_weights: {}, options: [
    { id: "A", label: "Короткие спринты с чёткими блоками.", axis_weights: { planning: 8, execution: 6 } },
    { id: "B", label: "Длинные сессии до полного погружения.", axis_weights: { execution: 8, focus_protection: 4 } },
  ], followup_rules: [{ if_axis_conflict: ["planning", "execution"], ask: ["di_f01"] }] },
  { id: "di_q11", test_slug: "discipline_index", type: "open", text: "Как выглядит твой рабочий минимум дня в плохом состоянии?", axis_weights: {} },
  { id: "di_q12", test_slug: "discipline_index", type: "open", text: "Какой триггер чаще всего выбивает тебя из ритма?", axis_weights: {} },
  { id: "di_f01", test_slug: "discipline_index", type: "forced_choice", text: "В конфликте план vs импульс ты выбираешь:", axis_weights: {}, options: [
    { id: "A", label: "План как приоритет, импульс как бонус.", axis_weights: { planning: 10 } },
    { id: "B", label: "Импульс как двигатель, план как рамка.", axis_weights: { execution: 8, planning: 2 } },
  ] },

  // 6) Риск-профиль карьеры
  { id: "cr_q01", test_slug: "career_risk", type: "scale", text: "Я откладываю публикацию, пока не станет «идеально».", scale: SCALE, axis_weights: { avoidance: 12 } },
  { id: "cr_q02", test_slug: "career_risk", type: "scale", text: "Я принимаю резкие карьерные решения на пике эмоции.", scale: SCALE, axis_weights: { impulsivity: 12 } },
  { id: "cr_q03", test_slug: "career_risk", type: "scale", text: "Мне сложно двигаться без внешнего подтверждения и одобрения.", scale: SCALE, axis_weights: { dependency: 12 } },
  { id: "cr_q04", test_slug: "career_risk", type: "scale", text: "Я держусь за старый образ, даже когда контекст изменился.", scale: SCALE, axis_weights: { identity_rigidity: 12 } },
  { id: "cr_q05", test_slug: "career_risk", type: "sjt", text: "Сильная критика после релиза. Ты:", axis_weights: {}, options: [
    { id: "A", label: "Замолкаю и откладываю следующий шаг.", axis_weights: { avoidance: 10, dependency: 6 } },
    { id: "B", label: "Резко меняю всё в подаче на ходу.", axis_weights: { impulsivity: 10 } },
    { id: "C", label: "Фиксирую выводы и иду по заранее выбранной рамке.", axis_weights: { identity_rigidity: -4, avoidance: -4 } },
  ] },
  { id: "cr_q06", test_slug: "career_risk", type: "forced_choice", text: "Что чаще происходит у тебя перед важным шагом?", axis_weights: {}, options: [
    { id: "A", label: "Слишком долгий анализ и перенос.", axis_weights: { avoidance: 10 } },
    { id: "B", label: "Быстрый рывок без проверки последствий.", axis_weights: { impulsivity: 10 } },
  ] },
  { id: "cr_q07", test_slug: "career_risk", type: "scale", text: "Я отменяю решения, если вижу неоднозначную реакцию в первые часы.", scale: SCALE, axis_weights: { dependency: 10, impulsivity: 4 } },
  { id: "cr_q08", test_slug: "career_risk", type: "scale", text: "Мне трудно пересобрать себя без ощущения «я предал(а) ядро».", scale: SCALE, axis_weights: { identity_rigidity: 10 } },
  { id: "cr_q09", test_slug: "career_risk", type: "sjt", text: "Команда предлагает стратегию, которая тебе не близка. Ты:", axis_weights: {}, options: [
    { id: "A", label: "Соглашаюсь, чтобы не конфликтовать.", axis_weights: { dependency: 8 } },
    { id: "B", label: "Отвергаю сразу, без теста.", axis_weights: { identity_rigidity: 8 } },
    { id: "C", label: "Тестирую ограниченно и принимаю решение по данным.", axis_weights: { avoidance: -4, impulsivity: -4 } },
  ] },
  { id: "cr_q10", test_slug: "career_risk", type: "forced_choice", text: "Твой типичный саботаж ближе к:", axis_weights: {}, options: [
    { id: "A", label: "Тянуть и не выпускать.", axis_weights: { avoidance: 10 } },
    { id: "B", label: "Резко сжигать и перезапускать.", axis_weights: { impulsivity: 10 } },
  ], followup_rules: [{ if_axis_conflict: ["avoidance", "impulsivity"], ask: ["cr_f01"] }] },
  { id: "cr_q11", test_slug: "career_risk", type: "open", text: "Где ты чаще всего «ломаешь» собственный карьерный цикл?", axis_weights: {} },
  { id: "cr_q12", test_slug: "career_risk", type: "open", text: "Какой один сигнал должен останавливать твой автосаботаж?", axis_weights: {} },
  { id: "cr_f01", test_slug: "career_risk", type: "forced_choice", text: "Под давлением ты чаще:", axis_weights: {}, options: [
    { id: "A", label: "Замираю и ухожу в подготовку.", axis_weights: { avoidance: 10, impulsivity: -4 } },
    { id: "B", label: "Действую мгновенно, чтобы снять тревогу.", axis_weights: { impulsivity: 10, avoidance: -4 } },
  ] },
];

const byId = new Map<string, TestQuestion>(Q.map((x) => [x.id, x]));

export function getQuestionById(id: string): TestQuestion | undefined {
  return byId.get(id);
}

export function getCoreQuestions(testSlug: DnkTestSlug): TestQuestion[] {
  return Q.filter((q) => q.test_slug === testSlug && !q.id.includes("_f"));
}

export function getFollowupById(id: string): TestQuestion | undefined {
  const q = byId.get(id);
  if (!q || !q.id.includes("_f")) return undefined;
  return q;
}

export function getAllQuestionsMap(): Map<string, TestQuestion> {
  return byId;
}
