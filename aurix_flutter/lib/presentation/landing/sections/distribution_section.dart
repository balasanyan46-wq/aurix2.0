import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class DistributionSection extends StatelessWidget {
  const DistributionSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AurixTokens.bg0,
            AurixTokens.accent.withValues(alpha: 0.03),
            AurixTokens.bg0,
          ],
        ),
      ),
      child: LandingSection(
        child: Column(
          children: [
            const SectionLabel(text: 'ДИСТРИБУЦИЯ'),
            const SizedBox(height: 24),
            Text(
              'Дистрибуция нового поколения',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AurixTokens.text,
                fontSize: desktop ? 40 : 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(
                'AURIX — это не просто upload → release. Это интеллектуальный процесс: от загрузки трека до оптимизации следующих релизов.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AurixTokens.muted, fontSize: desktop ? 16 : 14, height: 1.6),
              ),
            ),
            SizedBox(height: desktop ? 64 : 48),
            // Timeline
            const TimelineFlow(
              steps: [
                TimelineStep(
                  icon: Icons.cloud_upload_outlined,
                  label: 'Загрузка',
                  description: 'Загрузи трек на платформу',
                ),
                TimelineStep(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI анализ',
                  description: 'Мгновенный разбор трека',
                ),
                TimelineStep(
                  icon: Icons.route_rounded,
                  label: 'Стратегия',
                  description: 'AI план релиза',
                ),
                TimelineStep(
                  icon: Icons.public_rounded,
                  label: 'Дистрибуция',
                  description: 'Релиз на площадки',
                ),
                TimelineStep(
                  icon: Icons.trending_up_rounded,
                  label: 'Рост',
                  description: 'Анализ и оптимизация',
                ),
              ],
            ),
            SizedBox(height: desktop ? 56 : 40),
            // Bottom explainer
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(desktop ? 32 : 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: AurixTokens.surface1.withValues(alpha: 0.5),
                border: Border.all(color: AurixTokens.stroke(0.08)),
              ),
              child: desktop
                  ? Row(
                      children: const [
                        Expanded(child: _DistroFeature(icon: Icons.album_rounded, title: 'Релиз музыки', text: 'Выпускай треки на все платформы')),
                        SizedBox(width: 24),
                        Expanded(child: _DistroFeature(icon: Icons.insights_rounded, title: 'Анализ результатов', text: 'Отслеживай метрики и реакцию')),
                        SizedBox(width: 24),
                        Expanded(child: _DistroFeature(icon: Icons.tune_rounded, title: 'Оптимизация', text: 'Улучшай следующие релизы')),
                      ],
                    )
                  : Column(
                      children: const [
                        _DistroFeature(icon: Icons.album_rounded, title: 'Релиз музыки', text: 'Выпускай треки на все платформы'),
                        SizedBox(height: 20),
                        _DistroFeature(icon: Icons.insights_rounded, title: 'Анализ результатов', text: 'Отслеживай метрики и реакцию'),
                        SizedBox(height: 20),
                        _DistroFeature(icon: Icons.tune_rounded, title: 'Оптимизация', text: 'Улучшай следующие релизы'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistroFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _DistroFeature({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AurixTokens.accent.withValues(alpha: 0.6), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(text, style: TextStyle(color: AurixTokens.muted, fontSize: 12.5, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
