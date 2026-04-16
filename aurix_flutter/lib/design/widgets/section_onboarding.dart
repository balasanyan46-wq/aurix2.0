import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Data for a section onboarding tip.
class OnboardingTip {
  final String id;
  final IconData icon;
  final String title;
  final String description;
  final List<String> steps;

  const OnboardingTip({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    this.steps = const [],
  });
}

/// Compact dismissible onboarding banner for any section.
/// Shows once per section, remembered via SharedPreferences.
class SectionOnboarding extends StatefulWidget {
  const SectionOnboarding({super.key, required this.tip});
  final OnboardingTip tip;

  @override
  State<SectionOnboarding> createState() => _SectionOnboardingState();
}

class _SectionOnboardingState extends State<SectionOnboarding>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  bool _dismissed = false;
  late AnimationController _ac;
  late Animation<double> _fadeAnim;

  static const _prefix = 'onboarding_seen_';

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _checkSeen();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _checkSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('$_prefix${widget.tip.id}') ?? false;
    if (!seen && mounted) {
      setState(() => _visible = true);
      _ac.forward();
    }
  }

  Future<void> _dismiss() async {
    await _ac.reverse();
    if (!mounted) return;
    setState(() => _dismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix${widget.tip.id}', true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !_visible) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AurixTokens.accent.withValues(alpha: 0.08),
              AurixTokens.aiAccent.withValues(alpha: 0.04),
              AurixTokens.bg1,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AurixTokens.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.tip.icon, size: 18, color: AurixTokens.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tip.title,
                        style: const TextStyle(
                          color: AurixTokens.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.tip.description,
                        style: const TextStyle(
                          color: AurixTokens.muted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _dismiss,
                  child: Icon(Icons.close_rounded, size: 18, color: AurixTokens.micro),
                ),
              ],
            ),
            if (widget.tip.steps.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...widget.tip.steps.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: AurixTokens.accent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${e.key + 1}',
                              style: TextStyle(
                                color: AurixTokens.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              e.value,
                              style: const TextStyle(
                                color: AurixTokens.textSecondary,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _dismiss,
                style: TextButton.styleFrom(
                  foregroundColor: AurixTokens.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                child: const Text('Понятно'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pre-defined onboarding tips for all sections.
class OnboardingTips {
  OnboardingTips._();

  static const home = OnboardingTip(
    id: 'home',
    icon: Icons.space_dashboard_rounded,
    title: 'Главная — ваш центр управления',
    description: 'Здесь собрана сводка по вашим релизам, аналитике и прогрессу.',
    steps: [
      'Смотрите статус текущего релиза',
      'Быстрые действия — создать релиз, обложку, промо',
      'Отслеживайте XP, достижения и уведомления',
    ],
  );

  static const studioAi = OnboardingTip(
    id: 'studio_ai',
    icon: Icons.auto_awesome_rounded,
    title: 'AURIX Studio AI',
    description: 'Ваш AI-ассистент для создания музыки. Генерируйте тексты, обложки, стратегии и анализируйте треки.',
    steps: [
      'Задайте вопрос или выберите инструмент',
      'AI создаст контент на основе вашего профиля и DNK',
      'Все результаты сохраняются в истории чата',
    ],
  );

  static const artist = OnboardingTip(
    id: 'artist',
    icon: Icons.person_pin_rounded,
    title: 'Профиль артиста',
    description: 'Настройте ваш творческий профиль — AI будет использовать эти данные для персонализации.',
    steps: [
      'Заполните имя, жанр, цели и аудиторию',
      'Данные используются в AI Studio и DNK',
      'Чем больше деталей — тем точнее рекомендации',
    ],
  );

  static const releases = OnboardingTip(
    id: 'releases',
    icon: Icons.album_rounded,
    title: 'Управление релизами',
    description: 'Создавайте релизы, загружайте треки и отправляйте на модерацию для публикации на стриминговых платформах.',
    steps: [
      'Нажмите "Создать релиз" и заполните данные',
      'Загрузите треки и обложку',
      'Отправьте на модерацию — после одобрения релиз появится на платформах',
    ],
  );

  static const beats = OnboardingTip(
    id: 'beats',
    icon: Icons.graphic_eq_rounded,
    title: 'Маркетплейс битов',
    description: 'Покупайте и продавайте биты. Загрузите свой бит на продажу или найдите идеальный бит для трека.',
    steps: [
      'Слушайте превью битов в каталоге',
      'Покупайте лицензии: аренда, эксклюзив',
      'Продавайте свои биты — загрузите через "Загрузить бит"',
    ],
  );

  static const stats = OnboardingTip(
    id: 'stats',
    icon: Icons.insights_rounded,
    title: 'Статистика',
    description: 'Отслеживайте динамику стримов, доход и популярность ваших релизов.',
    steps: [
      'Данные появятся после публикации релизов',
      'Загрузите отчёты платформ для детальной аналитики',
      'Смотрите стримы по каждому релизу отдельно',
    ],
  );

  static const promo = OnboardingTip(
    id: 'promo',
    icon: Icons.campaign_rounded,
    title: 'Продвижение',
    description: 'Инструменты для промо вашей музыки: питчинг в плейлисты, реклама, контент-стратегия.',
    steps: [
      'Создайте промо-кампанию для релиза',
      'AI подберёт стратегию продвижения',
      'Отслеживайте результаты кампаний',
    ],
  );

  static const finance = OnboardingTip(
    id: 'finance',
    icon: Icons.account_balance_wallet_rounded,
    title: 'Финансы',
    description: 'Доходы от стримов, продаж битов и рефералов. Вся финансовая аналитика в одном месте.',
    steps: [
      'Смотрите доход по месяцам и релизам',
      'Данные обновляются при загрузке отчётов',
    ],
  );

  static const subscription = OnboardingTip(
    id: 'subscription',
    icon: Icons.diamond_rounded,
    title: 'Подписка',
    description: 'Выберите тариф для доступа к расширенным инструментам: AI Studio, DNK, продвижение и команда.',
    steps: [
      'СТАРТ — 1 релиз, аналитика, чек-лист запуска',
      'ПРОРЫВ — безлимит релизов, AI, промо, сплиты',
      'ИМПЕРИЯ — полный доступ, команда, приоритет проверки',
    ],
  );

  static const services = OnboardingTip(
    id: 'services',
    icon: Icons.build_circle_rounded,
    title: 'Услуги',
    description: 'Профессиональные услуги для артистов: сведение, мастеринг, обложки, съёмка и продвижение.',
    steps: [
      'Выберите услугу из каталога',
      'Оставьте заявку с деталями',
      'Специалист свяжется с вами для обсуждения',
    ],
  );

  static const referral = OnboardingTip(
    id: 'referral',
    icon: Icons.card_giftcard_rounded,
    title: 'Реферальная программа',
    description: 'Приглашайте артистов и получайте 10% от всех их платежей навсегда.',
    steps: [
      'Скопируйте реферальную ссылку',
      'Поделитесь с друзьями-артистами',
      'Получайте пассивный доход от каждого платежа',
    ],
  );

  static const support = OnboardingTip(
    id: 'support',
    icon: Icons.support_agent_rounded,
    title: 'Поддержка',
    description: 'Напишите нам если что-то непонятно или не работает. Мы ответим как можно скорее.',
    steps: [
      'Нажмите "Написать" чтобы создать обращение',
      'Опишите проблему или задайте вопрос',
      'Ответ придёт в чат и на email',
    ],
  );

  static const achievements = OnboardingTip(
    id: 'achievements',
    icon: Icons.emoji_events_rounded,
    title: 'Достижения',
    description: 'Выполняйте действия на платформе и получайте XP. Прокачивайте уровень артиста.',
    steps: [
      'Создавайте релизы, используйте AI, заходите каждый день',
      'За каждое действие начисляется XP',
      'Открывайте новые достижения и повышайте уровень',
    ],
  );

  static const goals = OnboardingTip(
    id: 'goals',
    icon: Icons.flag_rounded,
    title: 'Цели',
    description: 'Ставьте личные цели и отслеживайте прогресс. Помогает фокусироваться на важном.',
    steps: [
      'Создайте цель: название и целевое значение',
      'Обновляйте прогресс по мере выполнения',
      'Достигнутые цели приносят XP',
    ],
  );

  static const dnk = OnboardingTip(
    id: 'dnk',
    icon: Icons.fingerprint,
    title: 'AURIX DNK',
    description: 'Творческий профиль артиста. Пройдите тесты чтобы AI лучше понимал ваш стиль и потенциал.',
    steps: [
      'Пройдите тесты по разным направлениям',
      'Результаты формируют ваш уникальный DNK-профиль',
      'AI Studio использует DNK для персональных рекомендаций',
    ],
  );

  static const index = OnboardingTip(
    id: 'index',
    icon: Icons.leaderboard_rounded,
    title: 'AURIX Рейтинг',
    description: 'Общий рейтинг артистов на платформе. Чем активнее вы — тем выше позиция.',
    steps: [
      'Рейтинг считается по стримам, релизам, активности',
      'Смотрите свою позицию и профили других артистов',
    ],
  );

  static const progress = OnboardingTip(
    id: 'progress',
    icon: Icons.trending_up_rounded,
    title: 'Прогресс',
    description: 'Ежедневный дневник артиста: заметки, привычки, чекины и стрик.',
    steps: [
      'Заходите каждый день для поддержания стрика',
      'Ведите заметки о своём прогрессе',
      'Формируйте полезные привычки',
    ],
  );

  static const navigator = OnboardingTip(
    id: 'navigator',
    icon: Icons.explore_rounded,
    title: 'Навигатор артиста',
    description: 'AI-навигатор для развития карьеры. Персональные рекомендации и образовательные материалы.',
    steps: [
      'Пройдите онбординг для персонализации',
      'Получите план развития от AI',
      'Изучайте материалы из библиотеки',
    ],
  );

  static const publicProfile = OnboardingTip(
    id: 'public_profile',
    icon: Icons.public_rounded,
    title: 'Публичный профиль',
    description: 'Ваша визитка для фанатов и индустрии. Делитесь ссылкой на свой профиль.',
  );

  static const team = OnboardingTip(
    id: 'team',
    icon: Icons.groups_rounded,
    title: 'Команда и продакшн',
    description: 'Управляйте заказами на продакшн: биты, сведение, мастеринг и другие услуги от команды.',
  );

  static const settings = OnboardingTip(
    id: 'settings',
    icon: Icons.tune_rounded,
    title: 'Настройки',
    description: 'Язык, уведомления, конфиденциальность и управление аккаунтом.',
  );

  static const credits = OnboardingTip(
    id: 'credits',
    icon: Icons.bolt_rounded,
    title: 'Кредиты',
    description: 'Внутренняя валюта для AI-генераций, обложек и других инструментов. Пополняйте баланс или получайте бонусы.',
  );
}
