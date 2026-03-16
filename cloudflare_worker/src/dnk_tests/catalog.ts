import type { DnkTestSlug, TestDef } from "./types";

export const DNK_TEST_CATALOG: TestDef[] = [
  {
    slug: "artist_archetype",
    title: "Архетип артиста",
    description: "Определяет тип творческой энергии и сценической роли.",
    whatGives: "Главный архетип, вторичные роли и рекомендации по образу.",
    exampleResult: "Провокатор / Проводник / Архитектор",
    axes: ["stage_power", "vulnerability", "novelty_drive", "cohesion"],
  },
  {
    slug: "tone_communication",
    title: "Тон коммуникации",
    description: "Показывает рабочий стиль речи артиста в контенте и соцсетях.",
    whatGives: "Правила формулировок, слова-опоры, слова-табу и готовые фразы.",
    exampleResult: "Прямой тёплый тон с контролируемой резкостью",
    axes: ["directness", "warmth", "provocation", "clarity"],
  },
  {
    slug: "story_core",
    title: "Сюжетное ядро",
    description: "Находит внутренний конфликт и устойчивые сюжетные линии песен.",
    whatGives: "Ключевые темы, эмоциональный вектор и что артисту не работает.",
    exampleResult: "Тема: контроль vs близость",
    axes: ["inner_conflict", "narrative_depth", "emotional_range", "resolution_style"],
  },
  {
    slug: "growth_profile",
    title: "Профиль роста",
    description: "Определяет канал масштабирования и систему развития на 30 дней.",
    whatGives: "Основной и вспомогательные каналы роста + анти-стратегии.",
    exampleResult: "Главный канал: комьюнити",
    axes: ["community_bias", "viral_bias", "playlist_bias", "live_bias"],
  },
  {
    slug: "discipline_index",
    title: "Индекс дисциплины",
    description: "Проверяет системность, устойчивость ритма и контроль срывов.",
    whatGives: "Уровень дисциплины, регламент и правило анти-срыва.",
    exampleResult: "Уровень: 68/100, блок: хаотичный старт",
    axes: ["planning", "execution", "recovery", "focus_protection"],
  },
  {
    slug: "career_risk",
    title: "Риск-профиль карьеры",
    description: "Показывает, где артист запускает самосаботаж карьерного цикла.",
    whatGives: "Стоп-фактор, 3 сценария самосаботажа и план выхода.",
    exampleResult: "Стоп-фактор: перфекционистская отсрочка",
    axes: ["avoidance", "impulsivity", "dependency", "identity_rigidity"],
  },
];

const map = new Map<DnkTestSlug, TestDef>(DNK_TEST_CATALOG.map((x) => [x.slug, x]));

export function getTestDef(slug: string): TestDef | undefined {
  return map.get(slug as DnkTestSlug);
}
