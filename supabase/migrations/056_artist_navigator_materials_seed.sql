begin;

alter table if exists public.artist_navigator_materials
  add column if not exists blockers text[] not null default '{}';

with seed_rows(
  ord,
  slug,
  title,
  category,
  tags,
  stages,
  goals,
  blockers
) as (
  values
    (1, 'start-artist-positioning-core', 'Позиционирование артиста за 60 минут', 'Старт и позиционирование', array['позиционирование','бренд','старт']::text[], array['только начинаю']::text[], array['набрать аудиторию','выстроить контент']::text[], array['нет позиционирования','нет понимания, что делать']::text[]),
    (2, 'start-mini-brandbook', 'Мини-брендбук артиста без дизайнера', 'Старт и позиционирование', array['брендбук','визуал','tone']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['выстроить контент']::text[], array['нет позиционирования','нет контента']::text[]),
    (3, 'start-artist-profile-stack', 'Профиль артиста: база, которая конвертит', 'Старт и позиционирование', array['профиль','spotify','youtube']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['набрать аудиторию','подготовить релиз']::text[], array['нет знаний по платформам']::text[]),
    (4, 'release-90-days-system', 'Релиз как система: цикл 90 дней', 'Релиз как система', array['release','цикл','система']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['подготовить релиз']::text[], array['нет понимания, что делать']::text[]),
    (5, 'release-14-days-sprint', '14-дневный pre-release спринт', 'Релиз как система', array['pre-release','countdown','чеклист']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['подготовить релиз','выстроить контент']::text[], array['нет контента','нет дисциплины']::text[]),
    (6, 'release-post-launch-recovery', 'Что делать после релиза: первые 21 день', 'Релиз как система', array['post-release','дожим','аналитика']::text[], array['выпускаю регулярно','есть команда / есть движение']::text[], array['понять аналитику','набрать аудиторию']::text[], array['нет понимания, что делать']::text[]),
    (7, 'spotify-pitching-essentials', 'Spotify Pitching: без романтики, по шагам', 'Spotify', array['spotify','pitching','editorial']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['подготовить релиз']::text[], array['нет знаний по платформам']::text[]),
    (8, 'spotify-algo-signals', 'Алгоритмические сигналы Spotify: что реально влияет', 'Spotify', array['spotify','алгоритм','save-rate']::text[], array['выпускаю регулярно']::text[], array['понять аналитику','набрать аудиторию']::text[], array['нет знаний по платформам']::text[]),
    (9, 'spotify-profile-growth', 'Оформление Spotify-профиля для роста', 'Spotify', array['spotify','профиль','конверсия']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['набрать аудиторию']::text[], array['нет знаний по платформам']::text[]),
    (10, 'youtube-release-strategy', 'YouTube-стратегия на релизный месяц', 'YouTube', array['youtube','release','контент']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['подготовить релиз','выстроить контент']::text[], array['нет контента']::text[]),
    (11, 'youtube-shorts-engine', 'Shorts-движок: 12 идей без выгорания', 'YouTube', array['youtube','shorts','контент']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['выстроить контент','набрать аудиторию']::text[], array['нет контента']::text[]),
    (12, 'youtube-title-thumbnail-system', 'Система заголовков и превью для музыканта', 'YouTube', array['youtube','thumbnail','ctr']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['набрать аудиторию','понять аналитику']::text[], array['нет знаний по платформам']::text[]),
    (13, 'apple-music-profile-basics', 'Apple Music for Artists: база настройки', 'Apple Music', array['apple music','profile','artist']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['подготовить релиз']::text[], array['нет знаний по платформам']::text[]),
    (14, 'apple-editorial-readiness', 'Готовность к editorial на Apple Music', 'Apple Music', array['apple music','editorial','release']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['подготовить релиз']::text[], array['нет знаний по платформам']::text[]),
    (15, 'apple-post-release-signals', 'Как читать сигналы Apple Music после релиза', 'Apple Music', array['apple music','analytics','post-release']::text[], array['выпускаю регулярно']::text[], array['понять аналитику']::text[], array['нет знаний по платформам']::text[]),
    (16, 'content-pillars-artist', '3 контент-пиллара артиста', 'Контент и short-form', array['контент','pov','pillars']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['выстроить контент']::text[], array['нет контента']::text[]),
    (17, 'content-week-rhythm', 'Недельный ритм контента без перегруза', 'Контент и short-form', array['ритм','контент','дисциплина']::text[], array['только начинаю','уже выпускаю музыку','выпускаю регулярно']::text[], array['выстроить контент','навести систему']::text[], array['нет дисциплины','нет системы']::text[]),
    (18, 'content-from-one-track', 'Как снять 15 единиц контента с одного трека', 'Контент и short-form', array['контент','релиз','batch']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['выстроить контент','подготовить релиз']::text[], array['нет контента']::text[]),
    (19, 'analytics-minimum-dashboard', 'Минимальный аналитический дашборд артиста', 'Аналитика', array['аналитика','kpi','dashboard']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['понять аналитику']::text[], array['нет понимания, что делать']::text[]),
    (20, 'analytics-weekly-review', 'Еженедельный review: что менять в действиях', 'Аналитика', array['review','итерации','данные']::text[], array['выпускаю регулярно','есть команда / есть движение']::text[], array['понять аналитику','набрать аудиторию']::text[], array['нет понимания, что делать']::text[]),
    (21, 'analytics-when-release-flat', 'Если релиз «не полетел»: диагностика за 45 минут', 'Аналитика', array['post-release','diagnostic','рост']::text[], array['выпускаю регулярно','есть команда / есть движение']::text[], array['понять аналитику','разобраться с продвижением']::text[], array['нет понимания, что делать']::text[]),
    (22, 'monetization-direct-to-fan-core', 'Direct-to-fan: первый денежный контур', 'Монетизация и direct-to-fan', array['монетизация','direct-to-fan','оффер']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['заработать на музыке']::text[], array['нет денег']::text[]),
    (23, 'monetization-offers-ladder', 'Лестница офферов артиста: от 0 до первых продаж', 'Монетизация и direct-to-fan', array['офферы','продукт','продажи']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['заработать на музыке']::text[], array['нет денег']::text[]),
    (24, 'monetization-community-core', 'Комьюнити как актив: подписчик -> суперфан', 'Монетизация и direct-to-fan', array['комьюнити','суперфаны','retention']::text[], array['выпускаю регулярно','есть команда / есть движение']::text[], array['заработать на музыке','набрать аудиторию']::text[], array['нет денег']::text[]),
    (25, 'discipline-week-system', 'Система недели артиста: без хаоса', 'Система артиста / дисциплина', array['дисциплина','система','ритм']::text[], array['только начинаю','уже выпускаю музыку','выпускаю регулярно']::text[], array['навести систему']::text[], array['нет дисциплины','нет системы']::text[]),
    (26, 'discipline-micro-steps', 'Микро-шаги на каждый день: когда нет ресурса', 'Система артиста / дисциплина', array['микрошаги','прогресс','фокус']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['навести систему']::text[], array['нет дисциплины','нет понимания, что делать']::text[]),
    (27, 'discipline-focus-protocol', 'Фокус-протокол артиста на 90 минут', 'Система артиста / дисциплина', array['фокус','deep work','план']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['навести систему','выстроить контент']::text[], array['нет дисциплины']::text[]),
    (28, 'stuck-growth-reset', 'Ничего не растет: 7-дневный reset-план', 'Кейсы и разборы', array['рост','reset','антикризис']::text[], array['только начинаю','уже выпускаю музыку','выпускаю регулярно']::text[], array['разобраться с продвижением']::text[], array['нет понимания, что делать']::text[]),
    (29, 'stuck-content-no-response', 'Контент есть, отклика нет: где теряется внимание', 'Кейсы и разборы', array['контент','внимание','удержание']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['разобраться с продвижением','выстроить контент']::text[], array['нет контента']::text[]),
    (30, 'stuck-release-no-traction', 'Релиз вышел, но тишина: план дожима', 'Кейсы и разборы', array['релиз','post-release','дожим']::text[], array['выпускаю регулярно','есть команда / есть движение']::text[], array['разобраться с продвижением','понять аналитику']::text[], array['нет понимания, что делать']::text[])
),
base as (
  select
    'nav-' || ord::text as id,
    slug,
    title,
    'Практический маршрут без воды'::text as subtitle,
    'Короткий материал в стиле AURIX: сначала смысл, затем конкретные шаги и действие внутри продукта.'::text as excerpt,
    jsonb_build_array(
      jsonb_build_object(
        'kind','lead',
        'title','Зачем это тебе',
        'text','Этот блок объясняет, почему материал важен именно сейчас и какую точку роста он закрывает.'
      ),
      jsonb_build_object(
        'kind','essence',
        'title','Суть',
        'text','Концентрируемся на 2-3 принципах, которые дают максимум эффекта без перегруза.'
      ),
      jsonb_build_object(
        'kind','how_to',
        'title','Как сделать',
        'text','Пошаговый сценарий внедрения за 20-60 минут.',
        'items',jsonb_build_array(
          'Определи исходную точку и цель на неделю.',
          'Сделай один измеримый шаг в AURIX.',
          'Зафиксируй результат и корректировку.'
        )
      ),
      jsonb_build_object(
        'kind','checklist',
        'title','Чек-лист',
        'text','Проверь, что внедрение реально запущено.',
        'items',jsonb_build_array(
          'Есть понятный next step.',
          'Есть дедлайн на 7 дней.',
          'Есть action в Progress/Release/Studio AI.'
        )
      ),
      jsonb_build_object(
        'kind','mistakes',
        'title','Частые ошибки',
        'text','Главная ошибка — читать без действия. После каждого блока нужен конкретный шаг.'
      )
    ) as body_blocks,
    category,
    tags,
    array['spotify','youtube','apple music']::text[] as platforms,
    stages,
    goals,
    blockers,
    case
      when ord % 3 = 1 then 'базовый'
      when ord % 3 = 2 then 'средний'
      else 'продвинутый'
    end as difficulty,
    (5 + ((ord - 1) % 6))::int as reading_time_minutes,
    case
      when (ord - 1) % 6 = 0 then 'статья'
      when (ord - 1) % 6 = 1 then 'чеклист'
      when (ord - 1) % 6 = 2 then 'видео'
      when (ord - 1) % 6 = 3 then 'шаблон'
      when (ord - 1) % 6 = 4 then 'кейс'
      else 'маршрутный шаг'
    end as format_type,
    jsonb_build_array(
      jsonb_build_object('action_type','add_progress_task','label','Добавить шаг в Progress','route','/progress/manage?new=1'),
      jsonb_build_object('action_type','open_release_planner','label','Открыть Release Planner','route','/releases/create'),
      jsonb_build_object('action_type','open_studio_ai','label','Открыть Studio AI','route','/ai'),
      jsonb_build_object('action_type','open_promo','label','Открыть Promo','route','/promo'),
      jsonb_build_object('action_type','open_finances','label','Открыть Финансы','route','/finance'),
      jsonb_build_object('action_type','open_index','label','Открыть Рейтинг','route','/index'),
      jsonb_build_object('action_type','open_dnk','label','Открыть DNK','route','/dnk'),
      jsonb_build_object('action_type','save_to_route','label','Сохранить в мой маршрут','route','/navigator/saved')
    ) as action_links,
    jsonb_build_array(
      jsonb_build_object('title','Spotify for Artists','url','https://artists.spotify.com','source_type','official','note','Официальная база Spotify, уточнить конкретный материал при проде.'),
      jsonb_build_object('title','YouTube Creator','url','https://support.google.com/youtube','source_type','official','note','Шаблон ссылки, заменить на релевантный гайд при наполнении.')
    ) as source_pack,
    (ord <= 6) as is_featured,
    true as is_published,
    (0.55 + ((30 - ord)::numeric / 100))::numeric(6,3) as priority_score,
    array[
      'nav-' || (((ord - 1) % 30) + 1)::text,
      'nav-' || (((ord + 6) % 30) + 1)::text
    ]::text[] as related_content_ids,
    (now() - make_interval(days => (ord * 3))) as last_reviewed_at,
    (now() - make_interval(days => (40 + ord))) as created_at,
    (now() - make_interval(days => (ord / 2))) as updated_at
  from seed_rows
)
insert into public.artist_navigator_materials (
  id,
  slug,
  title,
  subtitle,
  excerpt,
  body_blocks,
  category,
  tags,
  platforms,
  stages,
  goals,
  blockers,
  difficulty,
  reading_time_minutes,
  format_type,
  action_links,
  source_pack,
  last_reviewed_at,
  is_featured,
  is_published,
  priority_score,
  related_content_ids,
  created_at,
  updated_at
)
select
  id,
  slug,
  title,
  subtitle,
  excerpt,
  body_blocks,
  category,
  tags,
  platforms,
  stages,
  goals,
  blockers,
  difficulty,
  reading_time_minutes,
  format_type,
  action_links,
  source_pack,
  last_reviewed_at,
  is_featured,
  is_published,
  priority_score,
  related_content_ids,
  created_at,
  updated_at
from base
on conflict (id) do update set
  slug = excluded.slug,
  title = excluded.title,
  subtitle = excluded.subtitle,
  excerpt = excluded.excerpt,
  body_blocks = excluded.body_blocks,
  category = excluded.category,
  tags = excluded.tags,
  platforms = excluded.platforms,
  stages = excluded.stages,
  goals = excluded.goals,
  blockers = excluded.blockers,
  difficulty = excluded.difficulty,
  reading_time_minutes = excluded.reading_time_minutes,
  format_type = excluded.format_type,
  action_links = excluded.action_links,
  source_pack = excluded.source_pack,
  last_reviewed_at = excluded.last_reviewed_at,
  is_featured = excluded.is_featured,
  is_published = excluded.is_published,
  priority_score = excluded.priority_score,
  related_content_ids = excluded.related_content_ids,
  updated_at = excluded.updated_at;

commit;
