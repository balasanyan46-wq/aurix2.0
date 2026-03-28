import { Inject, Injectable, Logger } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class InsightsService {
  private readonly log = new Logger('Insights');

  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  // ── Analytics Dashboard ──────────────────────────────────

  async getAnalytics(userId: number) {
    // Resolve artist_id: releases.artist_id → artists.id, not users.id
    const { rows: artistRows } = await this.pool.query(
      'SELECT id FROM artists WHERE user_id = $1 LIMIT 1', [userId],
    ).catch(() => ({ rows: [] }));
    const artistId = artistRows[0]?.id;
    if (!artistId) {
      return {
        summary: { total_streams: 0, total_revenue: 0, total_clicks: 0, releases_count: 0, growth_pct: 0, engagement: 0, viral_score: 0 },
        stream_series: [],
        releases: [],
        diagnosis: [{ problem: 'У тебя ещё нет профиля артиста', cause: 'Без профиля нет релизов и данных', fix: 'Создай первый релиз — профиль артиста создастся автоматически', effect: 'После первого релиза откроется полная аналитика', severity: 'critical' }],
      };
    }

    const [releasesRes, rowsRes, clicksRes] = await Promise.all([
      this.pool.query(
        `SELECT id, title, status, genre, cover_url, release_date, created_at
         FROM releases WHERE artist_id = $1 ORDER BY created_at DESC LIMIT 20`,
        [artistId],
      ).catch(() => ({ rows: [] })),
      this.pool.query(
        `SELECT rr.release_id, rr.track_title, rr.streams, rr.revenue, rr.platform, rr.report_date
         FROM report_rows rr
         JOIN releases r ON r.id::text = rr.release_id
         WHERE r.artist_id = $1
         ORDER BY rr.report_date DESC LIMIT 200`,
        [artistId],
      ).catch(() => ({ rows: [] })),
      this.pool.query(
        `SELECT rc.release_id, count(*)::int AS clicks,
                count(DISTINCT rc.platform) AS platforms
         FROM release_clicks rc
         JOIN releases r ON r.id = rc.release_id
         WHERE r.artist_id = $1 AND rc.created_at >= now() - interval '30 days'
         GROUP BY rc.release_id`,
        [artistId],
      ).catch(() => ({ rows: [] })),
    ]);

    const releases = releasesRes.rows as any[];
    const rows = rowsRes.rows as any[];
    const clicks = clicksRes.rows as any[];

    const totalStreams = rows.reduce((s: number, r: any) => s + (Number(r.streams) || 0), 0);
    const totalRevenue = rows.reduce((s: number, r: any) => s + (Number(r.revenue) || 0), 0);
    const totalClicks = clicks.reduce((s: number, r: any) => s + (Number(r.clicks) || 0), 0);

    // Daily stream series (30 days)
    const dailyMap = new Map<string, number>();
    for (const r of rows) {
      if (!r.report_date) continue;
      const day = new Date(r.report_date).toISOString().slice(0, 10);
      dailyMap.set(day, (dailyMap.get(day) || 0) + (Number(r.streams) || 0));
    }

    const streamSeries: { day: string; streams: number }[] = [];
    const now = new Date();
    for (let i = 29; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      const key = d.toISOString().slice(0, 10);
      streamSeries.push({ day: key, streams: dailyMap.get(key) || 0 });
    }

    // Per-release breakdown
    const releaseStats = releases.map((rel: any) => {
      const relRows = rows.filter((r: any) => String(r.release_id) === String(rel.id));
      const relClicks = clicks.find((c: any) => String(c.release_id) === String(rel.id));
      const streams = relRows.reduce((s: number, r: any) => s + (Number(r.streams) || 0), 0);
      const revenue = relRows.reduce((s: number, r: any) => s + (Number(r.revenue) || 0), 0);

      const platformMap = new Map<string, number>();
      for (const r of relRows) {
        if (r.platform) {
          platformMap.set(r.platform, (platformMap.get(r.platform) || 0) + (Number(r.streams) || 0));
        }
      }

      return {
        id: rel.id,
        title: rel.title,
        cover_url: rel.cover_url,
        genre: rel.genre,
        status: rel.status,
        streams,
        revenue: Math.round(revenue * 100) / 100,
        clicks: Number(relClicks?.clicks) || 0,
        platforms: Object.fromEntries(platformMap),
      };
    });

    // Growth
    const last7 = streamSeries.slice(-7).reduce((s, d) => s + d.streams, 0);
    const prev7 = streamSeries.slice(-14, -7).reduce((s, d) => s + d.streams, 0);
    const growthPct = prev7 > 0 ? Math.round(((last7 - prev7) / prev7) * 100) : 0;

    // Engagement (0-100)
    const engagement = Math.min(100, Math.round(
      (totalClicks * 2 + totalStreams * 0.01 + totalRevenue * 0.5) / Math.max(releases.length, 1),
    ));

    // Viral (0-100)
    const clickStreamRatio = totalStreams > 0 ? totalClicks / totalStreams : 0;
    const viral = Math.min(100, Math.round(
      Math.max(0, growthPct) * 0.5 + clickStreamRatio * 200 + (releases.length > 3 ? 10 : 0),
    ));

    // ── DIAGNOSIS ENGINE ────────────────────────────────────
    const diagnosis = this.buildDiagnosis({
      totalStreams, totalRevenue, totalClicks, growthPct,
      engagement, viral, releases, releaseStats, streamSeries,
    });

    return {
      summary: {
        total_streams: totalStreams,
        total_revenue: Math.round(totalRevenue * 100) / 100,
        total_clicks: totalClicks,
        releases_count: releases.length,
        growth_pct: growthPct,
        engagement,
        viral_score: viral,
      },
      stream_series: streamSeries,
      releases: releaseStats,
      diagnosis,
    };
  }

  private buildDiagnosis(ctx: {
    totalStreams: number; totalRevenue: number; totalClicks: number;
    growthPct: number; engagement: number; viral: number;
    releases: any[]; releaseStats: any[]; streamSeries: any[];
  }) {
    const d: { problem: string; cause: string; fix: string; effect: string; severity: string }[] = [];

    // No releases
    if (ctx.releases.length === 0) {
      d.push({
        problem: 'У тебя ещё нет релизов',
        cause: 'Без музыки на платформах нет данных для анализа и нет стримов',
        fix: 'Загрузи первый трек прямо сейчас — даже один сингл запустит твою аналитику',
        effect: 'Через 7 дней после релиза появятся первые данные по стримам и кликам',
        severity: 'critical',
      });
      return d;
    }

    // Declining streams
    if (ctx.growthPct < -20) {
      d.push({
        problem: `Стримы падают на ${Math.abs(ctx.growthPct)}% за неделю`,
        cause: 'Алгоритмы платформ снижают охват когда нет новой активности и промо',
        fix: 'Выпусти тизер или Reels с фрагментом трека — это перезапустит алгоритмическое продвижение',
        effect: 'Один вирусный Reels может дать +300-500% к стримам за 48 часов',
        severity: 'high',
      });
    } else if (ctx.growthPct < 0) {
      d.push({
        problem: `Рост замедлился (${ctx.growthPct}%)`,
        cause: 'Органический охват истощается через 2-3 недели после релиза без поддержки',
        fix: 'Запусти серию сторис с behind-the-scenes или запланируй коллаб с блогером',
        effect: 'Регулярный контент удерживает алгоритмический буст и сохраняет рост',
        severity: 'medium',
      });
    }

    // Low engagement
    if (ctx.engagement < 20 && ctx.totalStreams > 0) {
      d.push({
        problem: 'Люди слушают, но не взаимодействуют',
        cause: 'Нет призыва к действию в описании и промо — слушатели не знают что делать дальше',
        fix: 'Добавь CTA в описание каждого трека: "сохрани в плейлист", "поделись в сторис"',
        effect: 'Engagement выше 40 — сигнал алгоритмам что трек стоит рекомендовать шире',
        severity: 'high',
      });
    }

    // Low viral score
    if (ctx.viral < 15 && ctx.releases.length > 1) {
      d.push({
        problem: 'Виральность на нуле — трек не распространяется сам',
        cause: 'Контент не адаптирован под TikTok/Reels форматы где происходит вирусный рост',
        fix: 'Создай 3-5 коротких видео под разные моменты трека — один точно выстрелит',
        effect: 'Даже 1 видео с 10K просмотров может привести 500+ новых слушателей',
        severity: 'high',
      });
    }

    // No clicks
    if (ctx.totalClicks === 0 && ctx.totalStreams > 50) {
      d.push({
        problem: 'Ни одного клика по ссылкам — трафик не конвертируется',
        cause: 'Нет Smart Link или ссылка не размещена в био и описаниях',
        fix: 'Создай Smart Link и размести во всех соцсетях — в био, постах, сторис',
        effect: 'Smart Link собирает данные и увеличивает конверсию в стримы на 30-50%',
        severity: 'medium',
      });
    }

    // Low revenue
    if (ctx.totalRevenue < 10 && ctx.totalStreams > 1000) {
      d.push({
        problem: 'Стримы есть, а денег нет',
        cause: 'Возможно трек крутится на платформах с низкой ставкой за стрим или в free-тире',
        fix: 'Проверь распределение по платформам — фокус на Spotify/Apple Music даёт x3-5 к revenue',
        effect: 'Перенаправление даже 20% трафика на высокооплачиваемые платформы заметно увеличит доход',
        severity: 'medium',
      });
    }

    // Zero activity days
    const zeroDays = ctx.streamSeries.filter(s => s.streams === 0).length;
    if (zeroDays > 20 && ctx.releases.length > 0) {
      d.push({
        problem: `${zeroDays} из 30 дней — тишина, ноль стримов`,
        cause: 'Трек перестал появляться в рекомендациях и плейлистах — нужна свежая активность',
        fix: 'Выпусти ремикс, акустическую версию или новый трек — платформы любят активных артистов',
        effect: 'Новый релиз за 7-14 дней перезапускает профиль артиста в алгоритмах',
        severity: 'high',
      });
    }

    // All good
    if (d.length === 0) {
      d.push({
        problem: 'Всё идёт по плану — не расслабляйся',
        cause: 'Текущий рост стабильный, но конкуренты тоже не спят',
        fix: 'Масштабируй то что работает — больше контента, больше коллабов, новый релиз',
        effect: 'Удвоение активности в хорошие периоды даёт экспоненциальный рост аудитории',
        severity: 'positive',
      });
    }

    return d;
  }

  // ── Release Plan Generator ───────────────────────────────

  async generateReleasePlan(userId: number, body: {
    release_id?: string;
    track_title?: string;
    genre?: string;
    release_date?: string;
    days?: number;
  }) {
    const days = body.days || 14;
    const { rows: artRows } = await this.pool.query(
      'SELECT id FROM artists WHERE user_id = $1 LIMIT 1', [userId],
    ).catch(() => ({ rows: [] }));
    const artistId = artRows[0]?.id;

    let trackInfo = '';
    if (body.release_id && artistId) {
      const { rows } = await this.pool.query(
        `SELECT title, genre, release_type FROM releases WHERE id = $1 AND artist_id = $2`,
        [body.release_id, artistId],
      ).catch(() => ({ rows: [] }));
      if (rows[0]) {
        trackInfo = `Трек: "${rows[0].title}", жанр: ${rows[0].genre || body.genre || 'не указан'}, тип: ${rows[0].release_type}`;
      }
    }
    if (!trackInfo && body.track_title) {
      trackInfo = `Трек: "${body.track_title}", жанр: ${body.genre || 'не указан'}`;
    }

    const releaseDate = body.release_date || new Date(Date.now() + days * 86400000).toISOString().slice(0, 10);

    // Goal & milestones based on days
    const goal = {
      title: trackInfo
        ? `Запустить "${body.track_title || 'трек'}" так, чтобы его услышали`
        : `Подготовить и провести мощный релиз за ${days} дней`,
      description: 'Не просто выложить — а создать волну, которая принесёт стримы, подписчиков и узнаваемость',
      milestones: [
        { at_day: 1, label: 'Старт промо', emoji: '🎬' },
        { at_day: Math.ceil(days * 0.4), label: 'Пик тизеров', emoji: '🔥' },
        { at_day: Math.ceil(days * 0.7), label: 'Пресейв', emoji: '🎯' },
        { at_day: days - 1, label: 'День X', emoji: '🚀' },
        { at_day: days, label: 'Анализ', emoji: '📊' },
      ],
    };

    const apiKey = process.env.DEEPSEEK_API_KEY;
    if (!apiKey) {
      return { plan: this.fallbackPlan(days, releaseDate), source: 'template', release_date: releaseDate, goal };
    }

    try {
      const axios = (await import('axios')).default;
      const res = await axios.post('https://api.deepseek.com/v1/chat/completions', {
        model: 'deepseek-chat',
        messages: [
          {
            role: 'system',
            content: `Ты — дерзкий музыкальный маркетолог-стратег. Ты не боишься говорить прямо. Создай план продвижения релиза на ${days} дней.
${trackInfo ? `\n${trackInfo}` : ''}
Дата релиза: ${releaseDate}

Верни строго JSON массив. Каждый элемент:
{
  "day": число (1-${days}),
  "title": "Дерзкое короткое название действия",
  "description": "Конкретное описание: что именно делать, как подать, чего ожидать (2-3 предложения). Пиши живым языком, не как инструкция.",
  "type": "content" | "social" | "release" | "engage" | "analytics",
  "priority": "high" | "medium" | "low",
  "why": "Почему это работает — 1 предложение о механике или психологии"
}

Включи: тизеры, Reels/TikTok, сториз, обратный отсчёт, день релиза, пост-релизная активность, анализ.
Тексты должны быть живыми и мотивирующими, не сухими. Пиши по-русски. Только JSON массив, без markdown.`,
          },
        ],
        max_tokens: 2000,
        temperature: 0.75,
      }, {
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        timeout: 30000,
      });

      const content = res.data?.choices?.[0]?.message?.content || '[]';
      let plan: any[];
      try {
        const cleaned = content.replace(/```json?\n?/g, '').replace(/```/g, '').trim();
        plan = JSON.parse(cleaned);
        if (!Array.isArray(plan)) plan = [plan];
      } catch {
        plan = this.fallbackPlan(days, releaseDate);
      }

      return { plan, source: 'ai', release_date: releaseDate, goal };
    } catch (e: any) {
      this.log.warn(`AI plan generation failed: ${e.message}`);
      return { plan: this.fallbackPlan(days, releaseDate), source: 'template', release_date: releaseDate, goal };
    }
  }

  private fallbackPlan(days: number, releaseDate: string) {
    const plan = [
      { day: 1, title: 'Тизер в сторис — зацепи внимание', description: 'Запиши 15-секундный тизер — самый мощный момент трека на атмосферном видео. Не выкладывай весь трек, дай попробовать. Интрига — твой друг.', type: 'content', priority: 'high', why: 'Короткий тизер создаёт любопытство — мозг хочет услышать продолжение' },
      { day: 2, title: 'Анонс — заяви о себе', description: 'Напиши пост-анонс с датой. Обложка + цитата из текста, которая бьёт в чувства. Пусть люди поймут: это не просто трек, это событие.', type: 'social', priority: 'high', why: 'Первый публичный анонс фиксирует дату в голове подписчиков' },
      { day: 3, title: 'Behind the scenes — покажи кухню', description: 'Студия, микрофон, экран с проектом. Люди обожают закулисье — это создаёт связь. Ты не далёкая звезда, ты настоящий.', type: 'content', priority: 'medium', why: 'Закулисье создаёт эмоциональную связь с артистом' },
      { day: 5, title: 'Reels / TikTok — взорви ленту', description: 'Вертикальное видео 15-30 сек под самый качающий фрагмент. Смена кадров в такт бита. Trending-формат, не изобретай велосипед.', type: 'content', priority: 'high', why: 'Reels — главный канал органического роста в 2024-2025' },
      { day: 7, title: 'Обратный отсчёт — создай предвкушение', description: 'Стикер обратного отсчёта в сторис. Спроси подписчиков: "чего ждёте от трека?" Пусть они вложат своё внимание ДО релиза.', type: 'engage', priority: 'medium', why: 'Вопрос вовлекает — человек, который ответил, уже ждёт релиз' },
      { day: Math.min(10, days - 2), title: 'Пресейв — собери армию', description: 'Ссылка на пресейв + искренний текст: почему этот трек важен. Не "послушайте мой новый сингл", а история. Эмоция продаёт.', type: 'social', priority: 'high', why: 'Пресейвы — прямой сигнал платформам что трек ожидаемый' },
      { day: Math.min(12, days - 1), title: 'Финальный тизер — "Завтра"', description: 'Самый яркий, самый мощный момент. Одно слово: "Завтра". Всё. Минимализм бьёт сильнее тысячи слов.', type: 'content', priority: 'high', why: 'Краткость в финале создаёт максимальное напряжение перед релизом' },
      { day: Math.min(13, days), title: 'ДЕНЬ РЕЛИЗА — всё или ничего', description: 'Пост, сторис, Reels, TikTok — весь арсенал. Попроси друзей, коллег, семью — пусть каждый сохранит и поделится в первые 24 часа.', type: 'release', priority: 'high', why: 'Первые 24 часа определяют алгоритмическую судьбу трека' },
      { day: Math.min(14, days), title: 'Анализ — что сработало?', description: 'Открой статистику: стримы, клики, охват. Поделись первыми результатами с подписчиками — люди любят быть частью успеха.', type: 'analytics', priority: 'medium', why: 'Публичный отчёт показывает прозрачность и вовлекает аудиторию' },
    ];
    return plan.filter(p => p.day <= days);
  }

  // ── Promo Ideas Generator ────────────────────────────────

  async generatePromoIdeas(userId: number, body: {
    description: string;
    genre?: string;
    mood?: string;
    release_id?: string;
  }) {
    const apiKey = process.env.DEEPSEEK_API_KEY;

    let context = body.description;
    if (body.genre) context += `, жанр: ${body.genre}`;
    if (body.mood) context += `, настроение: ${body.mood}`;

    if (body.release_id) {
      const { rows: artR } = await this.pool.query(
        'SELECT id FROM artists WHERE user_id = $1 LIMIT 1', [userId],
      ).catch(() => ({ rows: [] }));
      const artId = artR[0]?.id;
      if (artId) {
        const { rows } = await this.pool.query(
          `SELECT title, genre FROM releases WHERE id = $1 AND artist_id = $2`,
          [body.release_id, artId],
        ).catch(() => ({ rows: [] }));
        if (rows[0]) {
          context += `. Трек: "${rows[0].title}" (${rows[0].genre || ''})`;
        }
      }
    }

    if (!apiKey) {
      return { ideas: this.fallbackPromoIdeas(context), source: 'template' };
    }

    try {
      const axios = (await import('axios')).default;
      const res = await axios.post('https://api.deepseek.com/v1/chat/completions', {
        model: 'deepseek-chat',
        messages: [
          {
            role: 'system',
            content: `Ты — дерзкий креативный директор музыкального промо. Ты знаешь что работает в TikTok и Reels. Сгенерируй 10 идей для продвижения.

Контекст: ${context}

Верни строго JSON массив из 10 объектов:
{
  "title": "Дерзкое короткое название",
  "description": "Конкретное описание: что снять, как подать, что написать (3-4 предложения). Живой язык.",
  "type": "video" | "reels" | "story" | "post" | "collab" | "challenge",
  "hook": "Цепляющий хук для начала видео",
  "difficulty": "easy" | "medium" | "hard",
  "viral_potential": число от 1 до 10,
  "why_it_works": "Объяснение психологии/механики: почему это цепляет людей (1-2 предложения)"
}

Идеи должны быть конкретные, дерзкие, для TikTok/Reels/VK. Не сухие инструкции, а живые идеи.
Пиши по-русски. Только JSON, без markdown.`,
          },
        ],
        max_tokens: 2500,
        temperature: 0.8,
      }, {
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        timeout: 30000,
      });

      const content = res.data?.choices?.[0]?.message?.content || '[]';
      let ideas: any[];
      try {
        const cleaned = content.replace(/```json?\n?/g, '').replace(/```/g, '').trim();
        ideas = JSON.parse(cleaned);
        if (!Array.isArray(ideas)) ideas = [ideas];
      } catch {
        ideas = this.fallbackPromoIdeas(context);
      }

      return { ideas, source: 'ai' };
    } catch (e: any) {
      this.log.warn(`AI promo generation failed: ${e.message}`);
      return { ideas: this.fallbackPromoIdeas(context), source: 'template' };
    }
  }

  private fallbackPromoIdeas(context: string) {
    return [
      { title: 'Lip-sync на убойный момент', description: 'Открой рот под самый мощный момент трека. Смена кадров в такт. Не думай — просто сними. Первый дубль часто самый живой.', type: 'reels', hook: 'Когда слышишь этот бит впервые...', difficulty: 'easy', viral_potential: 8, why_it_works: 'Lip-sync — самый простой вход в алгоритмы Reels. Люди смотрят лица, а музыка цепляет подсознательно.' },
      { title: 'История трека — честно и больно', description: 'Расскажи КАК ты написал этот трек. Не "я записал песню", а "я сидел в 3 ночи и...". Эмоция > продакшн.', type: 'video', hook: 'Этот трек я написал когда всё летело к чертям...', difficulty: 'medium', viral_potential: 7, why_it_works: 'Уязвимость — самый мощный инструмент. Люди подписываются на людей, а не на музыку.' },
      { title: 'Демо vs Финал — трансформация', description: 'Покажи голосовую заметку или первую демку, потом резкий cut на финальный мастер. Контраст убивает.', type: 'reels', hook: 'Вот так это звучало в начале... а вот так сейчас', difficulty: 'easy', viral_potential: 9, why_it_works: 'Трансформация — один из самых вирусных форматов. Мозг кайфует от контраста "было/стало".' },
      { title: 'Челлендж — просто и повторяемо', description: 'Придумай движение или жест под припев. Чем проще — тем лучше. Сними сам, отметь 5 друзей. Запусти хештег.', type: 'challenge', hook: 'Повтори если не слабо', difficulty: 'medium', viral_potential: 10, why_it_works: 'Челлендж превращает зрителей в создателей контента. Каждый участник — бесплатный промоутер.' },
      { title: 'Реакция друзей — первое прослушивание', description: 'Поставь трек друзьям без предупреждения. Сними реакцию. Настоящие эмоции — лучший маркетинг на свете.', type: 'video', hook: 'Показал новый трек друзьям и вот что вышло...', difficulty: 'easy', viral_potential: 8, why_it_works: 'Зеркальные нейроны: мы чувствуем то, что чувствуют другие. Их реакция = наша реакция.' },
      { title: 'Кинематографичный визуал', description: 'Текст трека на экране + атмосферные кадры. Закат, город ночью, дождь. Минимум монтажа, максимум вайба.', type: 'reels', hook: '', difficulty: 'medium', viral_potential: 6, why_it_works: 'Эстетика продаёт. Люди сохраняют красивое, а сохранения — главный сигнал для алгоритма.' },
      { title: 'Коллаб с блогером — чужая аудитория', description: 'Найди 2-3 блогеров с 5-20K подписчиков в твоём жанре. Предложи трек бесплатно для их контента. Win-win.', type: 'collab', hook: 'Новый саунд для твоего контента — бесплатно', difficulty: 'hard', viral_potential: 9, why_it_works: 'Микро-блогеры имеют самый высокий engagement rate. Их рекомендация = доверие их аудитории.' },
      { title: 'Countdown за 5 дней — нарастающее напряжение', description: 'Каждый день — новый фрагмент трека в сторис. Начни с самого тихого, закончи самым мощным. Стикер обратного отсчёта.', type: 'story', hook: 'Осталось 5 дней до того, что изменит всё...', difficulty: 'easy', viral_potential: 5, why_it_works: 'Серийный контент формирует привычку — люди возвращаются каждый день чтобы узнать продолжение.' },
      { title: 'Studio vlog — покажи процесс', description: 'Сними 60 секунд из студии: наушники, микрофон, момент "вот оно!". Не полировать, не монтировать идеально. Реальность > глянец.', type: 'video', hook: 'Заглянем в студию на 60 секунд...', difficulty: 'medium', viral_potential: 7, why_it_works: 'Процесс создания вызывает уважение. Люди ценят труд и хотят поддержать того, кто старается.' },
      { title: 'Мем — юмор побеждает всё', description: 'Возьми популярный мем-шаблон, адаптируй под трек. "POV: ты слушаешь этот трек в 3 ночи и понимаешь всё". Юмор + музыка = бомба.', type: 'reels', hook: 'POV: ты услышал этот трек и забыл обо всём', difficulty: 'easy', viral_potential: 8, why_it_works: 'Мемы — валюта интернета. Люди шарят смешное, а с ним шарится и твоя музыка.' },
    ];
  }
}
