-- ============================================================
-- 039 · Seed Production service catalog from Services screen
-- ============================================================

-- Идемпотентное заполнение каталога услуг, чтобы заказы из раздела
-- "Услуги" корректно создавали процессы в "Продакшн".

insert into public.service_catalog (
  title,
  description,
  category,
  default_price,
  sla_days,
  required_inputs,
  deliverables,
  is_active
)
select
  'Бит на заказ',
  'Профессиональный бит под релиз артиста.',
  'music',
  null,
  10,
  '{"files":["референсы","демо"],"fields":["жанр","темп","настроение"]}'::jsonb,
  '{"files":["бит wav","стемы"],"notes":"2-3 итерации правок"}'::jsonb,
  true
where not exists (
  select 1 from public.service_catalog where lower(title) = lower('Бит на заказ')
);

insert into public.service_catalog (
  title, description, category, default_price, sla_days,
  required_inputs, deliverables, is_active
)
select
  'Текст / топлайн',
  'Написание или редактура текста и топлайна.',
  'music',
  null,
  7,
  '{"files":["демо","референсы"],"fields":["тема","язык","эмоция"]}'::jsonb,
  '{"files":["финальный текст"],"notes":"правки включены"}'::jsonb,
  true
where not exists (
  select 1 from public.service_catalog where lower(title) = lower('Текст / топлайн')
);

insert into public.service_catalog (
  title, description, category, default_price, sla_days,
  required_inputs, deliverables, is_active
)
select
  'Сведение',
  'Сведение трека в студийном качестве.',
  'music',
  null,
  8,
  '{"files":["стемы","референс"],"fields":["bpm","тональность"]}'::jsonb,
  '{"files":["mix wav"],"notes":"черновик + финал"}'::jsonb,
  true
where not exists (
  select 1 from public.service_catalog where lower(title) = lower('Сведение')
);

insert into public.service_catalog (
  title, description, category, default_price, sla_days,
  required_inputs, deliverables, is_active
)
select
  'Мастеринг',
  'Финальная подготовка трека к релизу.',
  'music',
  null,
  4,
  '{"files":["финальный микс wav"],"fields":["площадки","референс громкости"]}'::jsonb,
  '{"files":["master wav","mp3 320"],"notes":"подготовка под стриминг"}'::jsonb,
  true
where not exists (
  select 1 from public.service_catalog where lower(title) = lower('Мастеринг')
);

insert into public.service_catalog (
  title, description, category, default_price, sla_days,
  required_inputs, deliverables, is_active
)
select
  'Вокальная запись',
  'Студийная запись вокала с инженером.',
  'music',
  null,
 5,
  '{"fields":["город","дата","референс"],"files":["демо"]}'::jsonb,
  '{"files":["сырые дорожки","обработанные дорожки"]}'::jsonb,
  true
where not exists (
  select 1 from public.service_catalog where lower(title) = lower('Вокальная запись')
);

insert into public.service_catalog (
  title, description, category, default_price, sla_days,
  required_inputs, deliverables, is_active
)
select
  'Обложка',
  'Дизайн обложки релиза 3000x3000.',
  'visual',
  null,
 7,
  '{"files":["референсы"],"fields":["название релиза","настроение","жанр"]}'::jsonb,
  '{"files":["cover 3000x3000"],"notes":"до 3 концептов"}'::jsonb,
  true
where not exists (
  select 1 from public.service_catalog where lower(title) = lower('Обложка')
);

insert into public.service_catalog (
  title, description, category, default_price, sla_days,
  required_inputs, deliverables, is_active
)
select
  'Съёмка Reels',
  'Съёмка и монтаж коротких видео для соцсетей.',
  'promo',
  null,
 10,
  '{"fields":["концепт","дата","площадки"],"files":["референсы"]}'::jsonb,
  '{"files":["готовые reels"],"notes":"сценарий + монтаж"}'::jsonb,
  false
where not exists (
  select 1 from public.service_catalog where lower(title) = lower('Съёмка Reels')
);

insert into public.service_catalog (
  title, description, category, default_price, sla_days,
  required_inputs, deliverables, is_active
)
select
  'Продвижение',
  'Промо релиза в соцсетях и на площадках.',
  'promo',
  null,
 14,
  '{"fields":["цель","аудитория","бюджет"],"files":["трек","обложка"]}'::jsonb,
  '{"files":["план промо","отчеты"],"notes":"плейлистинг и промо-активности"}'::jsonb,
  true
where not exists (
  select 1 from public.service_catalog where lower(title) = lower('Продвижение')
);

insert into public.service_catalog (
  title, description, category, default_price, sla_days,
  required_inputs, deliverables, is_active
)
select
  'Годовое продюсирование',
  'Комплексное сопровождение артиста на 12 месяцев.',
  'other',
  null,
 30,
  '{"fields":["цели на год","текущий каталог","ресурсы"]}'::jsonb,
  '{"files":["годовая стратегия","план релизов","ежемесячные отчеты"]}'::jsonb,
  true
where not exists (
  select 1 from public.service_catalog where lower(title) = lower('Годовое продюсирование')
);
