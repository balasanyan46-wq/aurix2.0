begin;

alter table if exists public.artist_navigator_materials
  add column if not exists blockers text[] not null default '{}';

with seed_rows(
  ord,
  slug,
  title,
  excerpt,
  category,
  tags,
  platforms,
  stages,
  goals,
  blockers,
  difficulty,
  reading_time_minutes,
  priority_score
) as (
  values
    -- Yandex Music (6)
    (31, 'yandex-growth-no-illusions', 'Как артисту расти в Яндекс Музыке без иллюзий', 'Разбор реальной механики роста в Яндекс Музыке: какие сигналы двигают трек, а какие создают только шум.', 'yandex_music', array['яндекс','рост','модель']::text[], array['яндекс','vk','youtube']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['набрать аудиторию','подготовить релиз']::text[], array['не понимаю, как расти']::text[], 'средний', 11, 0.930),
    (32, 'yandex-artist-card-setup', 'Как оформить карточку артиста в Яндекс Музыке', 'Карточка артиста влияет на доверие и конверсию. Покрываем минимум, без которого рост будет ломаться.', 'yandex_music', array['яндекс','карточка','оформление']::text[], array['яндекс']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['подготовить релиз','набрать аудиторию']::text[], array['не понимаю платформы']::text[], 'базовый', 9, 0.900),
    (33, 'yandex-release-prep', 'Как подготовить релиз под Яндекс Музыку', 'Пошаговая подготовка релиза под требования локального рынка: метаданные, тайминг и промо-связка.', 'yandex_music', array['яндекс','релиз','чеклист']::text[], array['яндекс','vk']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['подготовить релиз']::text[], array['не понимаю платформы']::text[], 'средний', 12, 0.950),
    (34, 'yandex-first-7-days-killers', 'Что убивает трек в Яндексе в первые 7 дней', 'Главные ошибки старта: когда релиз есть, а инерции нет. Список критичных провалов и антикейсы.', 'yandex_music', array['яндекс','ошибки','первые 7 дней']::text[], array['яндекс']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['подготовить релиз','понять аналитику']::text[], array['не понимаю, как расти']::text[], 'средний', 10, 0.910),
    (35, 'yandex-clean-traffic', 'Как гнать трафик в Яндекс Музыку без мусорных прослушиваний', 'Как привлекать не случайные клики, а релевантные прослушивания с удержанием и возвратами.', 'yandex_music', array['яндекс','трафик','качество']::text[], array['яндекс','telegram','vk']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['набрать аудиторию','разобраться с продвижением']::text[], array['не понимаю, как расти']::text[], 'продвинутый', 13, 0.890),
    (36, 'yandex-no-growth-diagnosis', 'Почему у тебя есть релизы, но нет роста в Яндекс Музыке', 'Диагностика стагнации: где ломается воронка и почему новые релизы не дают накопительного эффекта.', 'yandex_music', array['яндекс','диагностика','рост']::text[], array['яндекс']::text[], array['выпускаю регулярно','есть команда / есть движение']::text[], array['понять аналитику','набрать аудиторию']::text[], array['не понимаю, как расти']::text[], 'продвинутый', 14, 0.880),

    -- VK Music (6)
    (37, 'vk-growth-system', 'Как устроен рост артиста в VK Музыке', 'Структура роста в VK: комьюнити, контент, клипы и аудио-сигналы в одной системе.', 'vk_music', array['vk','рост','алгоритм']::text[], array['vk','telegram']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['набрать аудиторию','разобраться с продвижением']::text[], array['не понимаю платформы']::text[], 'средний', 11, 0.920),
    (38, 'vk-card-community-link', 'Как оформить карточку артиста и связать ее с сообществом', 'Без связки с сообществом карточка не работает как центр трафика. Даем рабочую конфигурацию.', 'vk_music', array['vk','карточка','сообщество']::text[], array['vk']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['подготовить релиз','набрать аудиторию']::text[], array['нет системы']::text[], 'базовый', 8, 0.900),
    (39, 'vk-music-ads-efficiency', 'VK Музыка + VK Реклама: как лить трафик без слива бюджета', 'Минимальная рекламная архитектура для музыканта: гипотезы, лимиты и контроль качества трафика.', 'vk_music', array['vk','реклама','бюджет']::text[], array['vk']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['набрать аудиторию','разобраться с продвижением']::text[], array['не понимаю, как расти']::text[], 'продвинутый', 15, 0.940),
    (40, 'vk-release-content-clips', 'Как делать релиз под VK: контент, клипы, комьюнити', 'Релиз в VK требует опоры на контент и комьюнити. Разбираем связку шагов в правильной последовательности.', 'vk_music', array['vk','релиз','клипы']::text[], array['vk']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['подготовить релиз','выстроить контент']::text[], array['нет контента']::text[], 'средний', 12, 0.930),
    (41, 'vk-artist-stats-reading', 'Как читать статистику артиста в VK и делать выводы', 'Какие метрики реально влияют на решения и как не утонуть в шумных цифрах.', 'vk_music', array['vk','статистика','решения']::text[], array['vk']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['понять аналитику']::text[], array['не понимаю, как расти']::text[], 'средний', 10, 0.870),
    (42, 'vk-track-outperforms-others', 'Почему трек может жить в VK лучше, чем на других платформах', 'Когда VK становится главным каналом роста и как капитализировать локальную динамику трека.', 'vk_music', array['vk','сценарий','аудитория']::text[], array['vk','яндекс']::text[], array['выпускаю регулярно','есть команда / есть движение']::text[], array['разобраться с продвижением','понять аналитику']::text[], array['не понимаю платформы']::text[], 'продвинутый', 12, 0.860),

    -- Legal / contracts / brand (6)
    (43, 'rights-owner-reality', 'Кому принадлежат права на песню на самом деле', 'Разделяем авторские и смежные права, чтобы не потерять контроль над монетизацией и дистрибуцией.', 'legal_safety', array['права','автор','мастер']::text[], array['vk','яндекс','youtube']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['разобраться с правами','начать систему']::text[], array['не понимаю, что делать следующим']::text[], 'средний', 12, 0.960),
    (44, 'related-rights-simple', 'Что такое смежные права простыми словами для артиста', 'Объясняем смежные права без юридического тумана: кто и за что получает выплаты.', 'contracts_rights', array['смежные права','роялти','деньги']::text[], array['vk','яндекс']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['разобраться с правами']::text[], array['не понимаю, как расти']::text[], 'базовый', 9, 0.910),
    (45, 'license-agreement-clean', 'Лицензионный договор без юридического тумана', 'Каркас лицензионного договора: обязательные пункты, срок, территория, выплаты и контроль.', 'contracts_rights', array['лицензия','договор','риски']::text[], array['vk','яндекс']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['разобраться с правами','начать систему']::text[], array['есть люди без договоров']::text[], 'продвинутый', 16, 0.950),
    (46, 'license-vs-assignment', 'Чем лицензия отличается от отчуждения прав', 'Критическая развилка для артиста: где ты делегируешь использование, а где теряешь владение.', 'contracts_rights', array['лицензия','отчуждение','права']::text[], array['vk','яндекс','youtube']::text[], array['только начинаю','уже выпускаю музыку']::text[], array['разобраться с правами']::text[], array['есть люди без договоров']::text[], 'средний', 11, 0.920),
    (47, 'when-trademark-needed', 'Когда артисту нужен товарный знак', 'Когда оформление товарного знака оправдано и как это защищает имя артиста на длинной дистанции.', 'artist_brand', array['товарный знак','бренд','защита']::text[], array['vk','яндекс','telegram']::text[], array['уже выпускаю музыку','выпускаю регулярно']::text[], array['разобраться с правами','набрать аудиторию']::text[], array['не понимаю, что делать следующим']::text[], 'средний', 10, 0.900),
    (48, 'contract-red-flags', 'Красные флаги в договорах и сотрудничестве', 'Список стоп-сигналов в документах и устных договоренностях, которые чаще всего ломают карьеру.', 'legal_safety', array['договор','риски','безопасность']::text[], array['vk','яндекс','youtube']::text[], array['только начинаю','уже выпускаю музыку','выпускаю регулярно']::text[], array['разобраться с правами','начать систему']::text[], array['есть люди без договоров']::text[], 'продвинутый', 14, 0.970)
),
base as (
  select
    'nav-' || ord::text as id,
    slug,
    title,
    'Практический маршрут без воды'::text as subtitle,
    excerpt,
    jsonb_build_array(
      jsonb_build_object('kind','hero','title','Главный контекст','text',excerpt),
      jsonb_build_object('kind','why_it_matters','title','Почему это важно','text','Сначала закрываем корневой риск, затем масштабируем рост.'),
      jsonb_build_object(
        'kind','key_points',
        'title','Ключевые принципы',
        'text','Фокус только на решениях с практическим эффектом.',
        'items',jsonb_build_array(
          'Определи приоритетный KPI на 14 дней.',
          'Убери действия, не связанные с целью.',
          'Закрепи ритм через короткие циклы внедрения.'
        )
      ),
      jsonb_build_object(
        'kind','mistakes',
        'title','Частые ошибки',
        'text','Ошибка номер один — активность без стратегии.',
        'items',jsonb_build_array(
          'Слишком широкий фокус.',
          'Отсутствие контрольных метрик.',
          'Нет перехода к действию в продукте.'
        )
      ),
      jsonb_build_object(
        'kind','action_steps',
        'title','Что сделать сейчас',
        'text','Минимальный цикл внедрения на ближайшие 48 часов.',
        'items',jsonb_build_array(
          'Выбери 1 следующий шаг.',
          'Поставь дедлайн и критерий результата.',
          'Зафиксируй действие в AURIX.'
        )
      ),
      jsonb_build_object(
        'kind','aurix_next_step',
        'title','Следующий шаг в AURIX',
        'text','Открой релевантный модуль и запусти выполнение сразу после чтения.'
      )
    ) as body_blocks,
    category,
    tags,
    platforms,
    stages,
    goals,
    blockers,
    difficulty,
    reading_time_minutes,
    'статья'::text as format_type,
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
      jsonb_build_object('title','Яндекс Музыка для артистов','url','https://music.yandex.ru/artists','source_type','official','note','Официальная документация и продуктовые материалы платформы.'),
      jsonb_build_object('title','VK Музыка для артистов','url','https://vk.com/music','source_type','official','note','Официальные материалы и интерфейсы экосистемы VK.')
    ) as source_pack,
    (ord <= 36) as is_featured,
    true as is_published,
    priority_score::numeric(6,3),
    array['nav-' || greatest(ord - 1, 31)::text, 'nav-' || least(ord + 1, 48)::text]::text[] as related_content_ids,
    (now() - make_interval(days => ord)) as created_at,
    now() as updated_at,
    now() as last_reviewed_at
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
