import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/screens/services/service_detail_modal.dart';
import 'package:aurix_flutter/screens/services/service_order_form_modal.dart';

class _ServiceData {
  final String title;
  final String description;
  final bool available;
  final IconData icon;
  final String offer;
  final List<String> whatYouGet;
  final List<String> howItWorks;
  final String timeline;

  const _ServiceData({
    required this.title,
    required this.description,
    required this.available,
    required this.icon,
    required this.offer,
    required this.whatYouGet,
    required this.howItWorks,
    required this.timeline,
  });
}

/// Услуги Wide Star — Ускоритель релиза.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  static final List<_ServiceData> _services = [
    _ServiceData(
      title: 'Бит на заказ',
      description: 'Профессиональный бит под ваш трек. Делают топовые аранжировщики.',
      available: true,
      icon: Icons.music_note_rounded,
      offer: 'Уникальный бит в вашем стиле от проверенных продюсеров. Качество гарантируем.',
      whatYouGet: ['Связь с продюсером', '2–3 итерации правок', 'Стемы (отдельные дорожки)', 'Эксклюзивные права'],
      howItWorks: ['Оставьте заявку с референсами', 'Продюсер свяжется с вами', 'Обсудите детали и сроки', 'Получите готовый бит'],
      timeline: '5–14 дней в зависимости от сложности.',
    ),
    _ServiceData(
      title: 'Текст / топлайн',
      description: 'Написание или редактура текста',
      available: true,
      icon: Icons.edit_note_rounded,
      offer: 'Профессиональные тексты и топлайны для ваших треков.',
      whatYouGet: ['Оригинальный текст', 'Редактура существующего', 'Топлайн по инструменталу'],
      howItWorks: ['Отправьте демо', 'Опишите желаемое настроение', 'Получите текст и правки'],
      timeline: '3–7 дней.',
    ),
    _ServiceData(
      title: 'Сведение',
      description: 'Сведение трека в студийном качестве',
      available: true,
      icon: Icons.graphic_eq_rounded,
      offer: 'Сведение от инженеров с опытом в хип-хопе, попе и электронике.',
      whatYouGet: ['Сведение всех дорожек', 'Баланс и панорама', 'Референс до мастеринга'],
      howItWorks: ['Загрузите стемы', 'Укажите референсы', 'Получите микс и правки'],
      timeline: '5–10 дней.',
    ),
    _ServiceData(
      title: 'Мастеринг',
      description: 'Финальная подготовка к релизу',
      available: true,
      icon: Icons.volume_up_rounded,
      offer: 'Мастеринг под стриминговые платформы с учётом громкости и форматов.',
      whatYouGet: ['Мастер WAV 24-bit', 'MP3 320', 'Подготовка под платформы'],
      howItWorks: ['Отправьте финальный микс', 'Укажите формат релиза', 'Получите мастер'],
      timeline: '2–5 дней.',
    ),
    _ServiceData(
      title: 'Вокальная запись',
      description: 'Запись вокала в студии',
      available: true,
      icon: Icons.mic_rounded,
      offer: 'Запись вокала в студии с профессиональным оборудованием.',
      whatYouGet: ['Студийное оборудование', 'Работа с инженером', 'Обработанные дорожки'],
      howItWorks: ['Выберите студию', 'Запишите сессию', 'Получите готовый материал'],
      timeline: 'По договорённости.',
    ),
    _ServiceData(
      title: 'Обложка',
      description: 'Дизайн обложки под ваш релиз',
      available: true,
      icon: Icons.image_rounded,
      offer: 'Оригинальный дизайн обложки 3000×3000 для стриминга.',
      whatYouGet: ['3 концепта на выбор', 'Финальный арт в форматах', 'Стиль под релиз'],
      howItWorks: ['Отправьте референсы и идеи', 'Получите концепты', 'Правки до финала'],
      timeline: '5–10 дней.',
    ),
    _ServiceData(
      title: 'Съёмка Reels',
      description: 'Видеоконтент для соцсетей',
      available: false,
      icon: Icons.videocam_rounded,
      offer: 'Клипы и Reels для продвижения в соцсетях.',
      whatYouGet: ['Сценарий', 'Съёмка', 'Монтаж'],
      howItWorks: ['Обсуждение концепта', 'Съёмка', 'Постпродакшн'],
      timeline: 'Скоро.',
    ),
    _ServiceData(
      title: 'Продвижение',
      description: 'Комплексное продвижение релиза',
      available: true,
      icon: Icons.rocket_launch_rounded,
      offer: 'Продвижение релиза в плейлисты и соцсети.',
      whatYouGet: ['Питчи в плейлисты', 'Реклама в соцсетях', 'Отчёты'],
      howItWorks: ['Анализ целевой аудитории', 'Стратегия', 'Запуск кампании'],
      timeline: 'От 2 недель.',
    ),
    _ServiceData(
      title: 'Годовое продюсирование',
      description: 'Полное сопровождение на год',
      available: true,
      icon: Icons.star_rounded,
      offer: 'Полное продюсирование: от идеи до релизов в течение года.',
      whatYouGet: ['Стратегия на год', 'Производство треков', 'Реализация и промо'],
      howItWorks: ['Стратегическая сессия', 'План релизов', 'Ежемесячная работа'],
      timeline: '12 месяцев.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInSlide(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L10n.t(context, 'services'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Услуги Wide Star — дополнительные инструменты для вашего релиза',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          FadeInSlide(
            delayMs: 50,
            child: Text('Ускоритель релиза',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final crossAxisCount = c.maxWidth > 900 ? 3 : (c.maxWidth > 600 ? 2 : 1);
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _services.asMap().entries.map((e) {
                  final s = e.value;
                  return FadeInSlide(
                    delayMs: 80 + e.key * 40,
                    child: SizedBox(
                      width: crossAxisCount == 1 ? double.infinity : 320,
                      child: _ServiceCard(
                        service: s,
                        onMore: () => _showDetail(context, s),
                        onOrder: () => _showOrderForm(context, s.title),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, _ServiceData s) {
    showDialog(
      context: context,
      builder: (ctx) => ServiceDetailModal(
        title: s.title,
        icon: s.icon,
        offer: s.offer,
        whatYouGet: s.whatYouGet,
        howItWorks: s.howItWorks,
        timeline: s.timeline,
        available: s.available,
        onRequest: () => _showOrderForm(context, s.title),
      ),
    );
  }

  void _showOrderForm(BuildContext context, String serviceName) {
    showDialog(
      context: context,
      builder: (ctx) => ServiceOrderFormModal(serviceName: serviceName),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final _ServiceData service;
  final VoidCallback onMore;
  final VoidCallback onOrder;

  const _ServiceCard({
    required this.service,
    required this.onMore,
    required this.onOrder,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = service.available ? L10n.t(context, 'available') : L10n.t(context, 'soon');

    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(service.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: service.available
                      ? Colors.green.withValues(alpha: 0.2)
                      : AurixTokens.glass(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: service.available
                          ? Colors.green.withValues(alpha: 0.5)
                          : AurixTokens.stroke(0.2)),
                ),
                child: Text(statusText,
                    style: TextStyle(
                        color: service.available ? Colors.green : AurixTokens.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(service.description,
              style: TextStyle(
                  color: AurixTokens.muted, fontSize: 14, height: 1.4)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: [
              TextButton.icon(
                onPressed: onMore,
                icon: Icon(Icons.info_outline_rounded, size: 18, color: AurixTokens.orange),
                label: Text(L10n.t(context, 'moreInfo'),
                    style: TextStyle(color: AurixTokens.orange)),
              ),
              AurixButton(
                text: L10n.t(context, 'order'),
                icon: Icons.shopping_cart_rounded,
                onPressed: service.available ? onOrder : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
