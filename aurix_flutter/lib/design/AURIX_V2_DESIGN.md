# AURIX V2 — Design Concept
## Музыкальный Bloomberg. Forbes для артистов.

---

## 1. СТРАТЕГИЧЕСКИЙ КОНТЕКСТ

AURIX — не SaaS. AURIX — **индустриальный стандарт**:
- Музыкальный Bloomberg Terminal
- Forbes для артистов
- Операционная система карьеры
- Индекс влияния

**Цель ощущения:** "Это серьёзно. Это система. Это влияние. Это будущее."

---

## 2. ВИЗУАЛЬНЫЙ АУДИТ (текущее состояние)

| Проблема | Решение V2 |
|----------|------------|
| Glass-эффекты, hover-glow | Плоские поверхности, 1px borders |
| Мягкие rounded corners (18–20px) | Жёсткие 8–12px или 0 |
| Много карточек-оболочек | Данные как структура, минимум контейнеров |
| Startup-атмосфера | Financial terminal, institutional |
| Слабый визуальный вес чисел | Hero: 72–96px tabular numbers |
| Хаотичная иерархия | 3 уровня: Display / Title / Body |

---

## 3. ДИЗАЙН-СИСТЕМА V2

### Палитра
```
bg0:     #08080A  — Фон
bg1:     #0C0C0F  — Поверхности
bg2:     #12121A  — Элевация (редко)
border:  #1E1E24  — Разделители
text:    #FAFAFA  — Основной
muted:   #6B6B73  — Вторичный
accent:  #E8A317  — Amber (статус, акцент)
positive:#22C55E  — Рост
negative:#6B7280  — Падение (нейтрально)
```

### Типографика
```
Display:  72–96px, Tabular, W800 — Hero Index
H1:       32–40px, W700 — Заголовки секций
H2:       20–24px, W600 — Подзаголовки
Body:     14–16px, W400 — Текст
Caption:  11–12px, W500 — Метки
Tabular:  fontFeatures: [FontFeature.tabularFigures()]
```

### Сетка и Spacing
```
4, 8, 12, 16, 24, 32, 48, 64
Base unit: 4
Section gap: 32–48
Card padding: 24
```

### Компоненты
- **Surface**: Flat, border 1px #1E1E24, padding 24, radius 8
- **No glow, no gradient overlay**
- **Accent** — точечно: CTA, активные состояния, рост

---

## 4. СТРУКТУРА СТРАНИЦ

### Home
- Hero: Index 72px + Level + Delta + Rank (строгая сетка)
- Trajectory: Минималистичный line chart
- Next Action: 1 главный шаг, лаконично
- Leaders: Топ-3, компактные строки

### Aurix Index
- Заголовок: "AURIX INDEX" — uppercase, tracking
- Табы: Минималистичные, underline indicator
- Данные — центр композиции

### Leaderboard
- Табличный вид: Rank | Artist | Level | Score | Δ
- Строгая сетка, без лишних карточек
- Топ-3: subtle highlight

### Artist Profile
- Hero: Аватар + Имя + Index (крупно)
- Stats: 2–3 ключевые метрики
- Badges: Ряд лаконичных тегов
- Next Steps: Нумерованный список

---

## 5. ПРИНЦИПЫ

1. **Данные — центр** — числа крупнее, текста меньше
2. **Строгая иерархия** — 3 уровня, не больше
3. **Премиальная нейтральность** — один акцент
4. **Структура вместо декора** — сетка, границы, воздух
5. **Доверие через простоту** — никакого визуального хаоса
6. **Terminal / Bloomberg** — institutional, серьёзно
