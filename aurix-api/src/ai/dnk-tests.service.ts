import {
  Inject,
  Injectable,
  Logger,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { EdenAiService } from './eden-ai.service';

// ── Types ────────────────────────────────────────────────────

export interface DnkTestQuestion {
  id: string;
  text: string;
  type: 'scale' | 'forced_choice' | 'sjt' | 'open';
  options?: { key: string; label: string }[];
  scale_labels?: { min: string; max: string };
}

export interface DnkTestResult {
  id: string;
  session_id: string;
  test_slug: string;
  score_axes: Record<string, number>;
  summary: string;
  strengths: string[];
  risks: string[];
  actions_7_days: string[];
  content_prompts: string[];
  confidence: Record<string, number>;
  regen_count: number;
}

// ── Axes per test slug ───────────────────────────────────────

const TEST_AXES: Record<string, string[]> = {
  artist_archetype: ['stage_power', 'vulnerability', 'novelty_drive', 'cohesion'],
  tone_communication: ['directness', 'warmth', 'provocation', 'clarity'],
  story_core: ['inner_conflict', 'narrative_depth', 'emotional_range', 'resolution_style'],
  growth_profile: ['community_bias', 'viral_bias', 'playlist_bias', 'live_bias'],
  discipline_index: ['planning', 'execution', 'recovery', 'focus_protection'],
  career_risk: ['avoidance', 'impulsivity', 'dependency', 'identity_rigidity'],
};

// ── System prompts per test ──────────────────────────────────

const TEST_PROMPTS: Record<string, string> = {
  artist_archetype: `Ты — эксперт по архетипам артистов и сценическим образам.

Проанализируй ответы артиста и определи его архетип.

Оси анализа:
- stage_power (0-100): сила сценического присутствия, харизма, магнетизм
- vulnerability (0-100): готовность раскрыться, показать слабость, быть настоящим
- novelty_drive (0-100): тяга к новому, экспериментальность, отказ от шаблонов
- cohesion (0-100): цельность образа, согласованность музыки/визуала/поведения`,

  tone_communication: `Ты — эксперт по коммуникации и публичному поведению артистов.

Проанализируй ответы и определи стиль коммуникации артиста.

Оси анализа:
- directness (0-100): прямота высказываний, готовность говорить неудобное
- warmth (0-100): теплота, дружелюбие, эмоциональная доступность
- provocation (0-100): склонность к провокации, конфликту, хайпу
- clarity (0-100): ясность мысли, структурированность, чёткость посыла`,

  story_core: `Ты — эксперт по нарративу и сторителлингу в музыке.

Проанализируй ответы и определи ядро истории артиста.

Оси анализа:
- inner_conflict (0-100): глубина внутреннего конфликта, который питает творчество
- narrative_depth (0-100): способность рассказывать многослойные истории
- emotional_range (0-100): ширина эмоционального диапазона в текстах и подаче
- resolution_style (0-100): как артист разрешает конфликты в историях (0=оставляет открытыми, 100=закрывает)`,

  growth_profile: `Ты — стратег музыкального маркетинга и роста аудитории.

Проанализируй ответы и определи профиль роста артиста.

Оси анализа:
- community_bias (0-100): склонность к построению комьюнити, работе с фанатами
- viral_bias (0-100): склонность к вирусному контенту, хайпу, трендам
- playlist_bias (0-100): склонность к попаданию в плейлисты, алгоритмическому продвижению
- live_bias (0-100): склонность к живым выступлениям, концертной деятельности`,

  discipline_index: `Ты — продюсер и коуч, специализирующийся на продуктивности артистов.

Проанализируй ответы и определи индекс дисциплины артиста.

Оси анализа:
- planning (0-100): способность планировать, ставить цели, видеть перспективу
- execution (0-100): способность доводить до конца, не бросать проекты
- recovery (0-100): скорость восстановления после провалов, стрессоустойчивость
- focus_protection (0-100): способность защищать фокус, не распыляться`,

  career_risk: `Ты — карьерный стратег и риск-аналитик для музыкальных артистов.

Проанализируй ответы и определи карьерные риски артиста.

Оси анализа:
- avoidance (0-100): склонность избегать решений, прокрастинация, страх действия
- impulsivity (0-100): импульсивность, необдуманные решения, хаос
- dependency (0-100): зависимость от внешней валидации, чужого мнения, лейбла
- identity_rigidity (0-100): ригидность идентичности, неспособность адаптироваться`,
};

const RESULT_FORMAT_INSTRUCTION = `

Верни результат СТРОГО в JSON. Без markdown, без комментариев, без текста до или после JSON.

{
  "score_axes": { "<axis1>": <0-100>, "<axis2>": <0-100>, "<axis3>": <0-100>, "<axis4>": <0-100> },
  "summary": "развёрнутый текстовый анализ, 3-5 предложений, конкретно и резко",
  "strengths": ["сильная сторона 1", "сильная сторона 2", "сильная сторона 3"],
  "risks": ["риск 1", "риск 2", "риск 3"],
  "actions_7_days": ["конкретное действие 1", "конкретное действие 2", "конкретное действие 3", "конкретное действие 4", "конкретное действие 5"],
  "content_prompts": ["идея контента 1", "идея контента 2", "идея контента 3"],
  "confidence": { "<axis1>": <0.0-1.0>, "<axis2>": <0.0-1.0>, "<axis3>": <0.0-1.0>, "<axis4>": <0.0-1.0> }
}

Требования:
— Все тексты на русском
— Будь конкретным и резким, без воды и банальностей
— strengths — минимум 3 пункта
— risks — минимум 3 пункта
— actions_7_days — минимум 5 конкретных действий, готовых к выполнению
— content_prompts — минимум 3 идеи для контента, специфичные для этого артиста
— confidence отражает уверенность оценки по каждой оси`;

// ── Question banks ───────────────────────────────────────────

const QUESTION_BANKS: Record<string, DnkTestQuestion[]> = {
  artist_archetype: [
    { id: 'aa_1', text: 'Насколько ты уверенно чувствуешь себя на сцене или перед камерой?', type: 'scale', scale_labels: { min: 'Теряюсь', max: 'В своей стихии' } },
    { id: 'aa_2', text: 'Что для тебя важнее на сцене?', type: 'forced_choice', options: [{ key: 'control', label: 'Контроль и точность' }, { key: 'energy', label: 'Энергия и импровизация' }] },
    { id: 'aa_3', text: 'Как часто ты показываешь уязвимость в своём творчестве?', type: 'scale', scale_labels: { min: 'Никогда', max: 'Всегда' } },
    { id: 'aa_4', text: 'Ты записал трек, который очень личный и болезненный. Что делаешь?', type: 'sjt', options: [{ key: 'release', label: 'Выпускаю — именно это и нужно людям' }, { key: 'edit', label: 'Редактирую, чтобы не было слишком откровенно' }, { key: 'shelf', label: 'Оставляю себе, не готов делиться' }] },
    { id: 'aa_5', text: 'Насколько тебе важно пробовать новые жанры и звуки?', type: 'scale', scale_labels: { min: 'Нашёл своё — не меняю', max: 'Постоянно экспериментирую' } },
    { id: 'aa_6', text: 'Твой визуал, музыка и поведение — это единая история?', type: 'scale', scale_labels: { min: 'Каждый раз разное', max: 'Всё связано в один образ' } },
    { id: 'aa_7', text: 'Коллаборация с артистом из совершенно другого жанра. Твоя реакция?', type: 'forced_choice', options: [{ key: 'excited', label: 'Кайф, хочу попробовать' }, { key: 'cautious', label: 'Зависит от артиста и условий' }, { key: 'no', label: 'Не моё, останусь в своём' }] },
    { id: 'aa_8', text: 'Опиши свой идеальный концерт в 2-3 предложениях.', type: 'open' },
    { id: 'aa_9', text: 'Насколько твой сценический образ отличается от тебя в жизни?', type: 'scale', scale_labels: { min: 'Я один и тот же', max: 'Это два разных человека' } },
  ],

  tone_communication: [
    { id: 'tc_1', text: 'Ты получил негативный комментарий под треком. Что делаешь?', type: 'sjt', options: [{ key: 'ignore', label: 'Игнорирую' }, { key: 'reply_calm', label: 'Отвечаю спокойно' }, { key: 'reply_sharp', label: 'Отвечаю резко и прямо' }, { key: 'joke', label: 'Превращаю в шутку' }] },
    { id: 'tc_2', text: 'Насколько ты прямолинеен в общении с аудиторией?', type: 'scale', scale_labels: { min: 'Обтекаемо', max: 'Рублю правду' } },
    { id: 'tc_3', text: 'Что ближе к твоему стилю общения?', type: 'forced_choice', options: [{ key: 'warm', label: 'Тёплый, дружелюбный' }, { key: 'distant', label: 'Дистанцированный, загадочный' }, { key: 'provocative', label: 'Провокационный, дерзкий' }] },
    { id: 'tc_4', text: 'Тебя позвали на интервью. Какой формат выберешь?', type: 'forced_choice', options: [{ key: 'structured', label: 'Структурированное, с подготовленными вопросами' }, { key: 'freeform', label: 'Свободный разговор, куда выведет' }, { key: 'avoid', label: 'Лучше письменное или вообще откажусь' }] },
    { id: 'tc_5', text: 'Насколько ты готов использовать провокацию для привлечения внимания?', type: 'scale', scale_labels: { min: 'Никогда', max: 'Это мой главный инструмент' } },
    { id: 'tc_6', text: 'Как ты объясняешь свою музыку людям, которые её не знают?', type: 'open' },
    { id: 'tc_7', text: 'Насколько легко тебя понять с первого раза?', type: 'scale', scale_labels: { min: 'Надо переспрашивать', max: 'Всё кристально ясно' } },
    { id: 'tc_8', text: 'Конфликт с другим артистом публично. Твои действия?', type: 'sjt', options: [{ key: 'public', label: 'Выношу всё на публику, хайп — это ресурс' }, { key: 'private', label: 'Решаю в личке, публике не показываю' }, { key: 'creative', label: 'Отвечаю треком или контентом' }] },
    { id: 'tc_9', text: 'Насколько ты открыт в сторис/постах о своей личной жизни?', type: 'scale', scale_labels: { min: 'Только музыка', max: 'Показываю всё' } },
    { id: 'tc_10', text: 'Опиши свой тон общения с фанатами в 1-2 предложениях.', type: 'open' },
  ],

  story_core: [
    { id: 'sc_1', text: 'Насколько твои тексты автобиографичны?', type: 'scale', scale_labels: { min: 'Полностью выдуманные', max: 'Всё из жизни' } },
    { id: 'sc_2', text: 'Что движет твоим творчеством больше всего?', type: 'forced_choice', options: [{ key: 'pain', label: 'Боль и внутренний конфликт' }, { key: 'joy', label: 'Радость и энергия' }, { key: 'observation', label: 'Наблюдение за миром' }, { key: 'escape', label: 'Эскапизм и фантазия' }] },
    { id: 'sc_3', text: 'Насколько глубоко ты копаешь в своих историях?', type: 'scale', scale_labels: { min: 'Поверхностно, настроение', max: 'До самого дна' } },
    { id: 'sc_4', text: 'Ты пишешь трек о расставании. Какой финал?', type: 'sjt', options: [{ key: 'open', label: 'Открытый — всё висит в воздухе' }, { key: 'resolved', label: 'Закрытый — я сделал выводы и иду дальше' }, { key: 'twist', label: 'Твист — всё не так, как казалось' }] },
    { id: 'sc_5', text: 'Какой эмоциональный диапазон ты чаще показываешь в музыке?', type: 'forced_choice', options: [{ key: 'narrow_deep', label: 'Узкий, но глубокий — одна эмоция до предела' }, { key: 'wide_surface', label: 'Широкий — много эмоций, скольжу по ним' }, { key: 'wide_deep', label: 'Широкий и глубокий — каждая эмоция прожита' }] },
    { id: 'sc_6', text: 'О чём ты никогда бы не написал трек?', type: 'open' },
    { id: 'sc_7', text: 'Насколько тебе важно, чтобы слушатель понял историю «правильно»?', type: 'scale', scale_labels: { min: 'Пусть каждый видит своё', max: 'Важно, чтобы поняли мой посыл' } },
    { id: 'sc_8', text: 'Расскажи главный конфликт, который ты переживаешь как артист.', type: 'open' },
    { id: 'sc_9', text: 'Ты чаще пишешь от первого лица или создаёшь персонажей?', type: 'forced_choice', options: [{ key: 'first_person', label: 'От первого лица — я и есть история' }, { key: 'character', label: 'Создаю персонажей и истории' }, { key: 'mix', label: 'Миксую — иногда я, иногда персонаж' }] },
  ],

  growth_profile: [
    { id: 'gp_1', text: 'Что для тебя важнее: 1000 преданных фанатов или 100000 случайных слушателей?', type: 'forced_choice', options: [{ key: 'fans', label: '1000 преданных' }, { key: 'reach', label: '100000 случайных' }] },
    { id: 'gp_2', text: 'Насколько ты готов подстраиваться под тренды ради охватов?', type: 'scale', scale_labels: { min: 'Никогда', max: 'Всегда, если работает' } },
    { id: 'gp_3', text: 'У тебя есть новый трек. Где ты хочешь, чтобы его услышали первым?', type: 'forced_choice', options: [{ key: 'playlist', label: 'В плейлисте стриминга' }, { key: 'live', label: 'На концерте вживую' }, { key: 'viral', label: 'В вирусном видео' }, { key: 'community', label: 'В своём комьюнити/чате' }] },
    { id: 'gp_4', text: 'Насколько ты комфортно чувствуешь себя на сцене перед большой аудиторией?', type: 'scale', scale_labels: { min: 'Стресс', max: 'Кайф' } },
    { id: 'gp_5', text: 'Ты получил предложение сделать вирусный челлендж, но он не в твоём стиле. Что делаешь?', type: 'sjt', options: [{ key: 'do_it', label: 'Делаю — охваты важнее' }, { key: 'adapt', label: 'Адаптирую под свой стиль' }, { key: 'refuse', label: 'Отказываюсь — не моё' }] },
    { id: 'gp_6', text: 'Как часто ты общаешься со своей аудиторией напрямую?', type: 'scale', scale_labels: { min: 'Почти никогда', max: 'Каждый день' } },
    { id: 'gp_7', text: 'Насколько тебе важно попасть в редакционные плейлисты?', type: 'scale', scale_labels: { min: 'Не думаю об этом', max: 'Это главная цель' } },
    { id: 'gp_8', text: 'Опиши свою идеальную стратегию роста в 2-3 предложениях.', type: 'open' },
    { id: 'gp_9', text: 'Что ты выберешь: тур по 10 городам или месяц активного контент-маркетинга?', type: 'forced_choice', options: [{ key: 'tour', label: 'Тур' }, { key: 'content', label: 'Контент-маркетинг' }] },
    { id: 'gp_10', text: 'Насколько ты готов инвестировать время в построение комьюнити?', type: 'scale', scale_labels: { min: 'Лучше делать музыку', max: 'Это так же важно, как музыка' } },
  ],

  discipline_index: [
    { id: 'di_1', text: 'Насколько часто ты ставишь конкретные цели по музыке на неделю/месяц?', type: 'scale', scale_labels: { min: 'Никогда', max: 'Всегда' } },
    { id: 'di_2', text: 'Ты начал 10 треков за месяц. Сколько из них ты закончишь?', type: 'forced_choice', options: [{ key: '1_2', label: '1-2' }, { key: '3_5', label: '3-5' }, { key: '6_8', label: '6-8' }, { key: 'all', label: 'Все 10' }] },
    { id: 'di_3', text: 'После провала (плохой релиз, отмена концерта) — как быстро ты возвращаешься в строй?', type: 'scale', scale_labels: { min: 'Недели/месяцы', max: 'На следующий день' } },
    { id: 'di_4', text: 'Тебя зовут на тусовку, но ты планировал работать в студии. Что делаешь?', type: 'sjt', options: [{ key: 'party', label: 'Иду на тусовку — жизнь одна' }, { key: 'studio', label: 'Остаюсь в студии — план есть план' }, { key: 'compromise', label: 'Зависит от ситуации, ищу компромисс' }] },
    { id: 'di_5', text: 'Насколько легко тебя отвлечь от работы над музыкой?', type: 'scale', scale_labels: { min: 'Очень легко', max: 'Почти невозможно' } },
    { id: 'di_6', text: 'Есть ли у тебя чёткий распорядок дня для творчества?', type: 'forced_choice', options: [{ key: 'strict', label: 'Да, жёсткий график' }, { key: 'loose', label: 'Примерный, но гибкий' }, { key: 'none', label: 'Нет, работаю когда приходит вдохновение' }] },
    { id: 'di_7', text: 'Опиши, что чаще всего мешает тебе закончить начатое.', type: 'open' },
    { id: 'di_8', text: 'Насколько ты умеешь говорить «нет» проектам, которые не в приоритете?', type: 'scale', scale_labels: { min: 'Берусь за всё', max: 'Чётко фильтрую' } },
    { id: 'di_9', text: 'Последний раз, когда план пошёл не так — как ты отреагировал?', type: 'open' },
  ],

  career_risk: [
    { id: 'cr_1', text: 'Насколько часто ты откладываешь важные решения по карьере?', type: 'scale', scale_labels: { min: 'Никогда', max: 'Постоянно' } },
    { id: 'cr_2', text: 'Ты получил два предложения: стабильный контракт vs рискованный, но потенциально прорывной проект. Что выберешь?', type: 'forced_choice', options: [{ key: 'stable', label: 'Стабильный контракт' }, { key: 'risky', label: 'Рискованный проект' }, { key: 'both', label: 'Попробую совместить' }] },
    { id: 'cr_3', text: 'Насколько важно для тебя одобрение других (лейбл, коллеги, аудитория)?', type: 'scale', scale_labels: { min: 'Мне всё равно', max: 'Критически важно' } },
    { id: 'cr_4', text: 'Тебе предложили полностью сменить жанр — это может дать рост. Что делаешь?', type: 'sjt', options: [{ key: 'switch', label: 'Переключаюсь — рост важнее' }, { key: 'experiment', label: 'Попробую параллельно, не бросая своё' }, { key: 'refuse', label: 'Отказываюсь — это не я' }] },
    { id: 'cr_5', text: 'Насколько быстро ты принимаешь решения по карьере?', type: 'scale', scale_labels: { min: 'Долго думаю', max: 'Решаю мгновенно' } },
    { id: 'cr_6', text: 'Что для тебя страшнее: не попробовать или попробовать и провалиться?', type: 'forced_choice', options: [{ key: 'not_try', label: 'Не попробовать' }, { key: 'fail', label: 'Попробовать и провалиться' }] },
    { id: 'cr_7', text: 'Насколько твой стиль/образ привязан к конкретному жанру или эстетике?', type: 'scale', scale_labels: { min: 'Я гибкий', max: 'Я — это мой жанр' } },
    { id: 'cr_8', text: 'Опиши главный риск для своей карьеры прямо сейчас.', type: 'open' },
    { id: 'cr_9', text: 'Ты потерял основной источник дохода от музыки. Что делаешь первым?', type: 'sjt', options: [{ key: 'pivot', label: 'Быстро ищу новые источники' }, { key: 'wait', label: 'Жду, пока ситуация наладится' }, { key: 'backup', label: 'Ухожу на подработку, музыка в фоне' }] },
    { id: 'cr_10', text: 'Насколько легко тебе менять свой имидж, если рынок требует?', type: 'scale', scale_labels: { min: 'Не меняюсь', max: 'Легко адаптируюсь' } },
  ],
};

// ── Service ──────────────────────────────────────────────────

@Injectable()
export class DnkTestsService {
  private readonly logger = new Logger(DnkTestsService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly ai: EdenAiService,
  ) {}

  // ── 1. Catalog ──────────────────────────────────────────────

  async getCatalog(): Promise<{ tests: any[] }> {
    const { rows } = await this.pool.query(
      `SELECT slug, title_ru, description, example_json, sort_order
       FROM dnk_test_defs
       WHERE is_active = true
       ORDER BY sort_order`,
    );

    return {
      tests: rows.map((r) => ({
        slug: r.slug,
        title: r.title_ru,
        description: r.description,
        what_gives: r.title_ru,
        example_result: r.example_json ?? null,
      })),
    };
  }

  // ── 2. Start session ────────────────────────────────────────

  async startSession(
    userId: string,
    testSlug: string,
  ): Promise<{ session_id: string; test_slug: string; questions: DnkTestQuestion[] }> {
    const questions = this.getQuestions(testSlug);

    const { rows } = await this.pool.query(
      `INSERT INTO dnk_test_sessions (user_id, test_slug, status, started_at)
       VALUES ($1, $2, 'in_progress', now())
       RETURNING id`,
      [userId, testSlug],
    );

    return {
      session_id: rows[0].id,
      test_slug: testSlug,
      questions,
    };
  }

  // ── 3. Submit answer ────────────────────────────────────────

  async submitAnswer(
    userId: string,
    sessionId: string,
    questionId: string,
    answerType: string,
    answerJson: Record<string, any>,
  ): Promise<{ ok: true }> {
    // Verify session ownership
    const session = await this.pool.query(
      `SELECT id, status FROM dnk_test_sessions WHERE id = $1 AND user_id = $2`,
      [sessionId, userId],
    );
    if (session.rows.length === 0) {
      throw new HttpException('Session not found', HttpStatus.NOT_FOUND);
    }
    if (session.rows[0].status !== 'in_progress') {
      throw new HttpException('Session already finished', HttpStatus.BAD_REQUEST);
    }

    const mappedType = this.mapAnswerType(answerType);

    await this.pool.query(
      `INSERT INTO dnk_test_answers (session_id, question_id, answer_type, answer_json)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (session_id, question_id) DO UPDATE
       SET answer_type = $3, answer_json = $4`,
      [sessionId, questionId, mappedType, JSON.stringify(answerJson)],
    );

    return { ok: true };
  }

  // ── 4. Finish ───────────────────────────────────────────────

  async finish(
    userId: string,
    sessionId: string,
  ): Promise<DnkTestResult & { status: string }> {
    // Verify session ownership & get test_slug
    const sessionRes = await this.pool.query(
      `SELECT id, test_slug, status FROM dnk_test_sessions WHERE id = $1 AND user_id = $2`,
      [sessionId, userId],
    );
    if (sessionRes.rows.length === 0) {
      throw new HttpException('Session not found', HttpStatus.NOT_FOUND);
    }

    const session = sessionRes.rows[0];
    if (session.status === 'finished') {
      throw new HttpException('Session already finished', HttpStatus.BAD_REQUEST);
    }

    const testSlug: string = session.test_slug;

    // Collect answers
    const answersRes = await this.pool.query(
      `SELECT question_id, answer_type, answer_json
       FROM dnk_test_answers
       WHERE session_id = $1
       ORDER BY question_id`,
      [sessionId],
    );

    if (answersRes.rows.length === 0) {
      throw new HttpException('No answers found for this session', HttpStatus.BAD_REQUEST);
    }

    // Format answers for AI
    const answersText = answersRes.rows
      .map((a) => {
        const val = typeof a.answer_json === 'string' ? JSON.parse(a.answer_json) : a.answer_json;
        let readable: string;
        if (a.answer_type === 'scale') {
          readable = `value=${val.value}/5`;
        } else if (a.answer_type === 'choice' || a.answer_type === 'sjt') {
          readable = `choice=${val.key}`;
        } else {
          readable = `text="${val.text || ''}"`;
        }
        return `- ${a.question_id} (${a.answer_type}): ${readable}`;
      })
      .join('\n');

    // Build system prompt
    const testPrompt = TEST_PROMPTS[testSlug];
    if (!testPrompt) {
      throw new HttpException(`Unknown test slug: ${testSlug}`, HttpStatus.BAD_REQUEST);
    }

    const axes = TEST_AXES[testSlug];
    const systemPrompt = `${testPrompt}${RESULT_FORMAT_INSTRUCTION}

Оси для этого теста: ${axes.join(', ')}`;

    const userMessage = `Вот ответы артиста на тест "${testSlug}":\n\n${answersText}\n\nПроанализируй и верни результат в JSON.`;

    // Call Eden AI
    let rawResult: string;
    try {
      rawResult = await this.ai.chat({
        message: userMessage,
        mode: 'dnk_full',
        contextPrompt: systemPrompt,
      });
    } catch (e) {
      this.logger.error(`Eden AI DNK test call failed for ${testSlug}`, e);
      await this.pool.query(
        `UPDATE dnk_test_sessions SET status = 'abandoned' WHERE id = $1`,
        [sessionId],
      );
      throw new HttpException(
        'AI service unavailable, try again later',
        HttpStatus.BAD_GATEWAY,
      );
    }

    // Parse result
    let parsed: Record<string, any>;
    try {
      parsed = JSON.parse(rawResult);
    } catch {
      this.logger.error(
        `Failed to parse DNK test JSON for ${testSlug}`,
        rawResult.slice(0, 500),
      );
      await this.pool.query(
        `UPDATE dnk_test_sessions SET status = 'abandoned' WHERE id = $1`,
        [sessionId],
      );
      throw new HttpException(
        'AI returned invalid format, try again',
        HttpStatus.BAD_GATEWAY,
      );
    }

    const scoreAxes = parsed.score_axes || {};
    const summary = parsed.summary || '';
    const strengths = parsed.strengths || [];
    const risks = parsed.risks || [];
    const actions7Days = parsed.actions_7_days || [];
    const contentPrompts = parsed.content_prompts || [];
    const confidence = parsed.confidence || {};

    // Store result
    const resultRes = await this.pool.query(
      `INSERT INTO dnk_test_results
        (session_id, test_slug, score_axes, summary, strengths, risks, actions_7_days, content_prompts, payload, confidence, regen_count)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 0)
       RETURNING id`,
      [
        sessionId,
        testSlug,
        JSON.stringify(scoreAxes),
        summary,
        JSON.stringify(strengths),
        JSON.stringify(risks),
        JSON.stringify(actions7Days),
        JSON.stringify(contentPrompts),
        JSON.stringify(parsed),
        JSON.stringify(confidence),
      ],
    );

    // Mark session finished
    await this.pool.query(
      `UPDATE dnk_test_sessions SET status = 'finished', finished_at = now() WHERE id = $1`,
      [sessionId],
    );

    return {
      status: 'ready',
      id: resultRes.rows[0].id,
      session_id: sessionId,
      test_slug: testSlug,
      score_axes: scoreAxes,
      summary,
      strengths,
      risks,
      actions_7_days: actions7Days,
      content_prompts: contentPrompts,
      confidence,
      regen_count: 0,
    };
  }

  // ── 5. Get result ───────────────────────────────────────────

  async getResult(
    userId: string,
    sessionId?: string,
    resultId?: string,
  ): Promise<DnkTestResult & { status: string }> {
    let row: any;

    if (resultId) {
      const res = await this.pool.query(
        `SELECT r.*, s.user_id, s.status AS session_status
         FROM dnk_test_results r
         JOIN dnk_test_sessions s ON s.id = r.session_id
         WHERE r.id = $1`,
        [resultId],
      );
      row = res.rows[0];
    } else if (sessionId) {
      const res = await this.pool.query(
        `SELECT r.*, s.user_id, s.status AS session_status
         FROM dnk_test_results r
         JOIN dnk_test_sessions s ON s.id = r.session_id
         WHERE r.session_id = $1`,
        [sessionId],
      );
      row = res.rows[0];
    } else {
      throw new HttpException(
        'Either sessionId or resultId is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    if (!row) {
      throw new HttpException('Result not found', HttpStatus.NOT_FOUND);
    }

    if (row.user_id !== userId) {
      throw new HttpException('Access denied', HttpStatus.FORBIDDEN);
    }

    return {
      status: 'ready',
      id: row.id,
      session_id: row.session_id,
      test_slug: row.test_slug,
      score_axes: typeof row.score_axes === 'string' ? JSON.parse(row.score_axes) : row.score_axes,
      summary: row.summary,
      strengths: typeof row.strengths === 'string' ? JSON.parse(row.strengths) : row.strengths,
      risks: typeof row.risks === 'string' ? JSON.parse(row.risks) : row.risks,
      actions_7_days: typeof row.actions_7_days === 'string' ? JSON.parse(row.actions_7_days) : row.actions_7_days,
      content_prompts: typeof row.content_prompts === 'string' ? JSON.parse(row.content_prompts) : row.content_prompts,
      confidence: typeof row.confidence === 'string' ? JSON.parse(row.confidence) : row.confidence,
      regen_count: row.regen_count || 0,
    };
  }

  // ── 6. Get progress ─────────────────────────────────────────

  async getProgress(
    userId: string,
  ): Promise<{ tests: Record<string, { status: string; session_id?: string; finished_at?: string }> }> {
    const allSlugs = Object.keys(TEST_AXES);

    const { rows } = await this.pool.query(
      `SELECT DISTINCT ON (test_slug)
              test_slug, id, status, finished_at
       FROM dnk_test_sessions
       WHERE user_id = $1
       ORDER BY test_slug, started_at DESC`,
      [userId],
    );

    const sessionMap = new Map(rows.map((r: any) => [r.test_slug, r]));

    const tests: Record<string, { status: string; session_id?: string; finished_at?: string }> = {};
    for (const slug of allSlugs) {
      const session = sessionMap.get(slug) as any;
      if (session) {
        tests[slug] = {
          status: session.status,
          session_id: session.id,
          finished_at: session.finished_at?.toISOString() ?? undefined,
        };
      } else {
        tests[slug] = { status: 'not_started' };
      }
    }

    return { tests };
  }

  // ── Helpers ─────────────────────────────────────────────────

  private getQuestions(testSlug: string): DnkTestQuestion[] {
    const questions = QUESTION_BANKS[testSlug];
    if (!questions) {
      throw new HttpException(
        `Unknown test slug: ${testSlug}`,
        HttpStatus.BAD_REQUEST,
      );
    }
    return questions;
  }

  private mapAnswerType(type: string): string {
    switch (type) {
      case 'scale':
        return 'scale';
      case 'forced_choice':
        return 'choice';
      case 'sjt':
        return 'sjt';
      case 'open':
        return 'open_text';
      default:
        return 'open_text';
    }
  }
}
