-- ════════════════════════════════════════════════════════════════════════════
-- 095_message_templates.sql
-- A/B-тестируемые шаблоны sales-сообщений.
--
-- Зачем: сейчас suggested_message в next-action.service хардкоднут — нет
-- способа протестировать варианты. Эта миграция вводит таблицу шаблонов
-- с вариантами (variant_key), которые NextActionService выбирает рандомно
-- (или по weight'у). Конверсия трекается через offer_sent.meta.template_variant.
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.message_templates (
  id            bigserial PRIMARY KEY,
  -- code = ключ next-action (например, 'contact_hot_lead'), общий для всех
  -- вариантов одного действия.
  code          text NOT NULL,
  -- variant_key = метка для A/B (A, B, C…). Уникальна вместе с code.
  variant_key   text NOT NULL DEFAULT 'A',
  -- Содержимое
  message       text NOT NULL,
  -- Управление: активен ли вариант + его «вес» при случайном выборе
  active        boolean NOT NULL DEFAULT true,
  weight        smallint NOT NULL DEFAULT 1,
  -- Audit
  created_by    int NULL,                            -- admin_id (nullable, seed без author'а)
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT message_templates_code_variant_unique UNIQUE (code, variant_key),
  CONSTRAINT message_templates_weight_check CHECK (weight BETWEEN 0 AND 100)
);

CREATE INDEX IF NOT EXISTS idx_message_templates_code_active
  ON public.message_templates(code, active);

-- Триггер updated_at
DROP TRIGGER IF EXISTS trg_message_templates_updated_at ON public.message_templates;
CREATE TRIGGER trg_message_templates_updated_at
  BEFORE UPDATE ON public.message_templates
  FOR EACH ROW EXECUTE FUNCTION public.set_leads_updated_at();
-- (переиспользуем функцию из 090_leads.sql — она generic)

-- Seed: переносим текущие хардкоднутые тексты как variant_key='A'.
-- Variant B можно добавлять руками в БД через INSERT/UPDATE.
INSERT INTO public.message_templates (code, variant_key, message) VALUES
  ('contact_hot_lead', 'A',
   'Привет! Вижу, ты активно пользуешься AURIX. Подскажи, чем могу помочь — хочешь подобрать подходящий план или обсудить продвижение?'),
  ('upsell_promotion', 'A',
   'Отлично, что ты выпустил релиз! Теперь самое важное — продвижение. Расскажу про наш Promotion Pack: попадание в плейлисты, реклама в соцсетях, охват 50k+.'),
  ('push_to_payment', 'A',
   'Видел, что ты подготовил релиз — осталось только оплатить дистрибуцию. Если есть вопросы по тарифу, напиши, помогу выбрать.'),
  ('suggest_release', 'A',
   'AI уже проанализировал твой материал — самое время оформить релиз. Заберу за тебя всю техническую часть: ISRC, копирайт, заливку.'),
  ('suggest_analysis', 'A',
   'Видел, что ты загрузил трек. Хочешь, AURIX AI проанализирует его — даст разбор по миксу, потенциалу, аудитории. Это бесплатно для пробы.')
ON CONFLICT (code, variant_key) DO NOTHING;
