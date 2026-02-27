import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import '../data/dnk_models.dart';
import '../data/questions_bank.dart';

class DnkResultScreen extends StatefulWidget {
  final DnkResult result;
  final String? sessionId;
  final VoidCallback? onRegenerate;
  final VoidCallback? onRegenerateHard;
  final VoidCallback? onStartNew;

  const DnkResultScreen({
    super.key,
    required this.result,
    this.sessionId,
    this.onRegenerate,
    this.onRegenerateHard,
    this.onStartNew,
  });

  @override
  State<DnkResultScreen> createState() => _DnkResultScreenState();
}

class _DnkResultScreenState extends State<DnkResultScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.fingerprint, color: AurixTokens.accent, size: 28),
              const SizedBox(width: 10),
              Text(
                'Твой Aurix DNK',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AurixTokens.text,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              if (widget.onStartNew != null)
                IconButton(
                  icon: const Icon(Icons.refresh, color: AurixTokens.textSecondary),
                  tooltip: 'Пройти заново',
                  onPressed: widget.onStartNew,
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Tags
          if (r.tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: r.tags
                  .map((t) => Chip(
                        label: Text(t, style: const TextStyle(fontSize: 12, color: AurixTokens.text)),
                        backgroundColor: AurixTokens.bg2,
                        side: BorderSide(color: AurixTokens.border),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],

          // ═══════════════════════════════════════════════════
          // 1) PASSPORT HERO — structured A-G
          // ═══════════════════════════════════════════════════
          _buildPassportHero(r.passportHero, r.profileShort),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════════════════
          // 2) MIRROR OF PEOPLE — social magnetism
          // ═══════════════════════════════════════════════════
          _buildMirrorSection(r.socialSummary),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════════════════
          // 3) TABOOS
          // ═══════════════════════════════════════════════════
          _buildTaboosSection(r.socialSummary.taboos),
          const SizedBox(height: 16),

          // ═══════════════════════════════════════════════════
          // 4) SCRIPTS
          // ═══════════════════════════════════════════════════
          _buildScriptsSection(r.socialSummary.scripts),
          const SizedBox(height: 16),

          // Social axes chart
          _buildSocialAxesChart(r.socialAxes),
          const SizedBox(height: 16),

          // Core axes chart
          _buildAxesChart(r.axes),
          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════════
          // 5) TABS: Music/Content/Behavior/Visual/Prompts
          // ═══════════════════════════════════════════════════
          Container(
            decoration: BoxDecoration(
              color: AurixTokens.bg1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AurixTokens.border),
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  indicatorColor: AurixTokens.accent,
                  labelColor: AurixTokens.text,
                  unselectedLabelColor: AurixTokens.muted,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(text: 'Музыка'),
                    Tab(text: 'Контент'),
                    Tab(text: 'Поведение'),
                    Tab(text: 'Визуал'),
                    Tab(text: 'Промпты'),
                  ],
                ),
                SizedBox(
                  height: 420,
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildRecTab(_musicTab(r.recommendations.music)),
                      _buildRecTab(_contentTab(r.recommendations.content)),
                      _buildRecTab(_behaviorTab(r.recommendations.behavior)),
                      _buildRecTab(_visualTab(r.recommendations.visual)),
                      _buildPromptsTab(r.prompts),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Regenerate buttons
          if (widget.onRegenerate != null) ...[
            Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onRegenerate,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Перегенерировать'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AurixTokens.accent,
                      side: const BorderSide(color: AurixTokens.accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (widget.onRegenerateHard != null)
                    FilledButton.icon(
                      onPressed: widget.onRegenerateHard,
                      icon: const Icon(Icons.whatshot, size: 18),
                      label: const Text('Жёстче'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // PASSPORT HERO — structured 7 sections
  // ═══════════════════════════════════════════════════════════
  Widget _buildPassportHero(DnkPassportHero p, String profileShort) {
    final hasSections = !p.isEmpty;

    if (!hasSections) {
      return _buildWowCard(
        icon: Icons.badge_outlined,
        title: 'Паспорт героя',
        accentColor: AurixTokens.accent,
        child: SelectableText(
          profileShort.isNotEmpty ? profileShort : 'Нет данных',
          style: const TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w500, height: 1.6),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          colors: [AurixTokens.accent.withValues(alpha: 0.08), AurixTokens.bg1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, color: AurixTokens.accent, size: 22),
              const SizedBox(width: 8),
              Text('Паспорт героя', style: TextStyle(
                color: AurixTokens.accent,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              )),
            ],
          ),
          const SizedBox(height: 16),

          // A) HOOK
          if (p.hook.isNotEmpty) ...[
            SelectableText(
              p.hook,
              style: const TextStyle(
                color: AurixTokens.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
          ],

          // B) HOW PEOPLE FEEL YOU
          if (p.howPeopleFeelYou.isNotEmpty) ...[
            _passportSectionTitle('КАК ТЕБЯ СЧИТЫВАЮТ'),
            const SizedBox(height: 4),
            SelectableText(
              p.howPeopleFeelYou,
              style: const TextStyle(color: AurixTokens.text, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 14),
          ],

          // C) MAGNET
          if (p.magnet.isNotEmpty) ...[
            _passportSectionTitle('МАГНИТ'),
            const SizedBox(height: 6),
            ...p.magnet.map((m) => _passportBullet(m, const Color(0xFF22C55E))),
            const SizedBox(height: 14),
          ],

          // D) REPULSION
          if (p.repulsion.isNotEmpty) ...[
            _passportSectionTitle('ОТТАЛКИВАЕТ'),
            const SizedBox(height: 6),
            ...p.repulsion.map((r) => _passportBullet(r, const Color(0xFFEF4444))),
            const SizedBox(height: 14),
          ],

          // E) SHADOW
          if (p.shadow.isNotEmpty) ...[
            _passportSectionTitle('ТЕНЬ'),
            const SizedBox(height: 4),
            SelectableText(
              p.shadow,
              style: TextStyle(
                color: AurixTokens.text.withValues(alpha: 0.85),
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
          ],

          // F) TABOO
          if (p.taboo.isNotEmpty) ...[
            _passportSectionTitle('ЗАКОНЫ'),
            const SizedBox(height: 6),
            ...p.taboo.map((t) => _passportBullet(t, const Color(0xFFF59E0B), icon: Icons.block)),
            const SizedBox(height: 14),
          ],

          // G) NEXT 7 DAYS
          if (p.next7Days.isNotEmpty) ...[
            _passportSectionTitle('ЗАДАНИЯ НА 7 ДНЕЙ'),
            const SizedBox(height: 6),
            ...p.next7Days.asMap().entries.map((e) => _passportNumbered(e.key + 1, e.value)),
          ],
        ],
      ),
    );
  }

  Widget _passportSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AurixTokens.accent,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _passportBullet(String text, Color dotColor, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 8),
            child: icon != null
                ? Icon(icon, size: 14, color: dotColor)
                : Container(width: 7, height: 7, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          ),
          Expanded(
            child: SelectableText(text, style: const TextStyle(color: AurixTokens.text, fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _passportNumbered(int n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: BoxDecoration(
              color: AurixTokens.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text('$n', style: TextStyle(color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(
            child: SelectableText(text, style: const TextStyle(color: AurixTokens.text, fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // WOW CARD wrapper
  // ═══════════════════════════════════════════════════════════
  Widget _buildWowCard({
    required IconData icon,
    required String title,
    required Widget child,
    Color accentColor = AurixTokens.accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.05),
            AurixTokens.bg1,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 2) MIRROR — magnets / repellers / come for / leave when
  // ═══════════════════════════════════════════════════════════
  Widget _buildMirrorSection(DnkSocialSummary s) {
    if (s.isEmpty) {
      return _buildWowCard(
        icon: Icons.people_outline,
        title: 'Зеркало людей',
        accentColor: const Color(0xFF8B5CF6),
        child: const Text('Нет данных', style: TextStyle(color: AurixTokens.muted)),
      );
    }

    return _buildWowCard(
      icon: Icons.people_outline,
      title: 'Зеркало людей',
      accentColor: const Color(0xFF8B5CF6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.magnets.isNotEmpty) ...[
            _mirrorLabel('Притягивает', const Color(0xFF22C55E), Icons.favorite),
            ...s.magnets.map((m) => _mirrorItem(m, const Color(0xFF22C55E))),
            const SizedBox(height: 14),
          ],
          if (s.repellers.isNotEmpty) ...[
            _mirrorLabel('Отталкивает', const Color(0xFFEF4444), Icons.block),
            ...s.repellers.map((m) => _mirrorItem(m, const Color(0xFFEF4444))),
            const SizedBox(height: 14),
          ],
          if (s.peopleComeFor.isNotEmpty) ...[
            _singleLine('Люди приходят за:', s.peopleComeFor, const Color(0xFF38BDF8)),
            const SizedBox(height: 8),
          ],
          if (s.peopleLeaveWhen.isNotEmpty)
            _singleLine('Люди уходят, когда:', s.peopleLeaveWhen, const Color(0xFFFB923C)),
        ],
      ),
    );
  }

  Widget _mirrorLabel(String text, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _mirrorItem(String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AurixTokens.text, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _singleLine(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.arrow_right_rounded, color: color, size: 20),
        const SizedBox(width: 4),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, height: 1.4),
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(color: AurixTokens.text),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 3) TABOOS
  // ═══════════════════════════════════════════════════════════
  Widget _buildTaboosSection(List<String> taboos) {
    if (taboos.isEmpty) {
      return _buildWowCard(
        icon: Icons.do_not_disturb_alt_outlined,
        title: 'Запреты',
        accentColor: const Color(0xFFEF4444),
        child: const Text('Нет данных', style: TextStyle(color: AurixTokens.muted)),
      );
    }

    return _buildWowCard(
      icon: Icons.do_not_disturb_alt_outlined,
      title: 'Запреты',
      accentColor: const Color(0xFFEF4444),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Нарушишь — бренд и харизма ломаются:',
            style: TextStyle(color: AurixTokens.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ...taboos.asMap().entries.map((e) {
            if (e.value.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${e.key + 1}',
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.value,
                      style: const TextStyle(
                        color: AurixTokens.text,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 4) SCRIPTS
  // ═══════════════════════════════════════════════════════════
  Widget _buildScriptsSection(DnkSocialScripts scripts) {
    final sections = <_ScriptSection>[
      _ScriptSection('Ответ на хейт', Icons.local_fire_department, const Color(0xFFFB923C), scripts.hateReply),
      _ScriptSection('Интервью', Icons.mic_external_on, const Color(0xFF38BDF8), scripts.interviewStyle),
      _ScriptSection('Конфликт', Icons.flash_on, const Color(0xFFEF4444), scripts.conflictStyle),
      _ScriptSection('Команда', Icons.group_work, const Color(0xFF22C55E), scripts.teamworkRule),
    ];

    final hasAny = sections.any((s) => s.items.isNotEmpty);

    return _buildWowCard(
      icon: Icons.theater_comedy_outlined,
      title: 'Сценарии поведения',
      accentColor: const Color(0xFFFB923C),
      child: hasAny
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections.map((s) {
                if (s.items.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(s.icon, color: s.color, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            s.label,
                            style: TextStyle(color: s.color, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...s.items.where((t) => t.isNotEmpty).map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 22),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: s.color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: s.color.withValues(alpha: 0.2)),
                              ),
                              child: SelectableText(
                                t,
                                style: const TextStyle(
                                  color: AurixTokens.text,
                                  fontSize: 13,
                                  height: 1.4,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                );
              }).toList(),
            )
          : const Text('Нет данных', style: TextStyle(color: AurixTokens.muted)),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Social axes chart
  // ═══════════════════════════════════════════════════════════
  Widget _buildSocialAxesChart(DnkSocialAxes socialAxes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withValues(alpha: 0.05),
            AurixTokens.bg1,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 20),
              SizedBox(width: 8),
              Text(
                'Социальный магнетизм',
                style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...dnkSocialAxesInfo.map((info) {
            final value = socialAxes[info.key];
            return _buildAxisBar(info, value, 1.0, accentOverride: const Color(0xFF8B5CF6));
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Core axes chart
  // ═══════════════════════════════════════════════════════════
  Widget _buildAxesChart(DnkAxes axes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Оси профиля',
            style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...dnkAxesInfo.map((info) {
            final value = axes[info.key];
            final conf = axes.confidence[info.key] ?? 0.5;
            return _buildAxisBar(info, value, conf);
          }),
        ],
      ),
    );
  }

  Widget _buildAxisBar(DnkAxisInfo info, int value, double confidence, {Color? accentOverride}) {
    final color = accentOverride ?? _axisColor(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  info.label,
                  style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$value',
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              if (accentOverride == null) ...[
                const SizedBox(width: 6),
                Text(
                  '${(confidence * 100).round()}%',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 11),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AurixTokens.bg2,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: value / 100,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(info.lowLabel, style: TextStyle(color: AurixTokens.muted, fontSize: 10)),
              Text(info.highLabel, style: TextStyle(color: AurixTokens.muted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Color _axisColor(int value) {
    if (value < 30) return const Color(0xFF38BDF8);
    if (value < 50) return AurixTokens.positive;
    if (value < 70) return AurixTokens.accent;
    return const Color(0xFFEF4444);
  }

  // ═══════════════════════════════════════════════════════════
  // Tabs helpers (same as before)
  // ═══════════════════════════════════════════════════════════
  Widget _buildRecTab(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  List<Widget> _musicTab(Map<String, dynamic> m) {
    return [
      _chipRow('Жанры', m['genres']),
      _textLine('Темп', '${_formatList(m['tempo_range_bpm'], join: '–')} BPM'),
      _chipRow('Настроение', m['mood']),
      _bulletList('Тексты', m['lyrics']),
      _bulletList('Делай', m['do']),
      _bulletList('Избегай', m['avoid']),
    ];
  }

  List<Widget> _contentTab(Map<String, dynamic> c) {
    return [
      _chipRow('Платформы', c['platform_focus']),
      _chipRow('Контент-столпы', c['content_pillars']),
      _textLine('Ритм постинга', c['posting_rhythm']?.toString() ?? '-'),
      _bulletList('Хуки', c['hooks']),
      _bulletList('Делай', c['do']),
      _bulletList('Избегай', c['avoid']),
    ];
  }

  List<Widget> _behaviorTab(Map<String, dynamic> b) {
    return [
      _bulletList('Командная работа', b['teamwork']),
      _textLine('Стиль конфликтов', b['conflict_style']?.toString() ?? '-'),
      _bulletList('Публичные ответы', b['public_replies']),
      _bulletList('Протокол стресса', b['stress_protocol']),
    ];
  }

  List<Widget> _visualTab(Map<String, dynamic> v) {
    return [
      _chipRow('Палитра', v['palette']),
      _chipRow('Материалы', v['materials']),
      _bulletList('Референсы', v['references']),
      _bulletList('Гардероб', v['wardrobe']),
      _bulletList('Делай', v['do']),
      _bulletList('Избегай', v['avoid']),
    ];
  }

  Widget _buildPromptsTab(DnkPrompts p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _promptCard('Концепция трека', p.trackConcept),
          _promptCard('Текст (seed)', p.lyricsSeed),
          _promptCard('Обложка (DALL-E)', p.coverPrompt),
          _promptCard('Серия Reels/Shorts', p.reelsSeries),
        ],
      ),
    );
  }

  Widget _promptCard(String title, String prompt) {
    if (prompt.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AurixTokens.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AurixTokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: AurixTokens.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: prompt));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Скопировано'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: const Icon(Icons.copy, size: 16, color: AurixTokens.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              prompt,
              style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipRow(String label, dynamic list) {
    final items = _toStringList(list);
    if (items.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: items
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AurixTokens.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(t,
                          style: const TextStyle(
                              color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w500)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _bulletList(String label, dynamic list) {
    final items = _toStringList(list);
    if (items.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...items.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13)),
                    Expanded(
                      child: Text(t,
                          style: const TextStyle(
                              color: AurixTokens.textSecondary, fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _textLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                  color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  List<String> _toStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  String _formatList(dynamic v, {String join = ', '}) {
    if (v is List) return v.map((e) => e.toString()).join(join);
    return v?.toString() ?? '-';
  }
}

class _ScriptSection {
  final String label;
  final IconData icon;
  final Color color;
  final List<String> items;
  const _ScriptSection(this.label, this.icon, this.color, this.items);
}
