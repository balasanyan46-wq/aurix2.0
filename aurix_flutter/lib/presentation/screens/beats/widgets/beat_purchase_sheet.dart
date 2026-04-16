import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/models/beat_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';

class BeatPurchaseSheet extends ConsumerStatefulWidget {
  final BeatModel beat;
  final VoidCallback onPurchased;

  const BeatPurchaseSheet({
    super.key,
    required this.beat,
    required this.onPurchased,
  });

  @override
  ConsumerState<BeatPurchaseSheet> createState() => _BeatPurchaseSheetState();
}

class _BeatPurchaseSheetState extends ConsumerState<BeatPurchaseSheet> {
  String _selectedLicense = 'lease';
  bool _loading = false;
  String? _error;

  static const _licenses = [
    _LicenseInfo(
      type: 'lease',
      title: 'Лизинг',
      icon: Icons.timer_rounded,
      description: 'Стандартная лицензия для коммерческого использования',
      features: ['До 500K стримов', 'Распространение на всех площадках', 'MP3 + WAV файлы'],
    ),
    _LicenseInfo(
      type: 'unlimited',
      title: 'Безлимит',
      icon: Icons.all_inclusive_rounded,
      description: 'Расширенные права без ограничений по стримам',
      features: ['Без лимита стримов', 'Все форматы файлов', 'Право на ремикс'],
    ),
    _LicenseInfo(
      type: 'exclusive',
      title: 'Эксклюзив',
      icon: Icons.star_rounded,
      description: 'Полные права — бит снимается с продажи',
      features: ['Полные права на бит', 'Бит удаляется из каталога', 'Все исходники (stems)'],
    ),
  ];

  int get _price => widget.beat.priceForLicense(_selectedLicense);

  Future<void> _purchase() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(beatRepositoryProvider).purchaseBeat(widget.beat.id, _selectedLicense);
      if (mounted) {
        widget.onPurchased();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Бит «${widget.beat.title}» куплен!'),
            backgroundColor: AurixTokens.positive,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AurixTokens.stroke(0.2)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AurixTokens.stroke(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Beat info header
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56, height: 56,
                    child: widget.beat.coverUrl != null
                        ? Image.network(widget.beat.coverUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder())
                        : _placeholder(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.beat.title,
                        style: TextStyle(
                          fontFamily: AurixTokens.fontHeading,
                          color: AurixTokens.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.beat.sellerName ?? 'Producer',
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // License options
            Text(
              'Выбери лицензию',
              style: TextStyle(
                fontFamily: AurixTokens.fontHeading,
                color: AurixTokens.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ..._licenses.map((lic) {
              final isSelected = _selectedLicense == lic.type;
              final price = widget.beat.priceForLicense(lic.type);
              final isSold = lic.type == 'exclusive' && widget.beat.isSoldExclusive;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: isSold ? null : () => setState(() => _selectedLicense = lic.type),
                  child: AnimatedContainer(
                    duration: AurixTokens.dFast,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSold
                          ? AurixTokens.surface1.withValues(alpha: 0.5)
                          : isSelected
                              ? AurixTokens.accent.withValues(alpha: 0.08)
                              : AurixTokens.surface1,
                      borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
                      border: Border.all(
                        color: isSelected
                            ? AurixTokens.accent.withValues(alpha: 0.5)
                            : AurixTokens.stroke(0.15),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Opacity(
                      opacity: isSold ? 0.4 : 1.0,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? AurixTokens.accent.withValues(alpha: 0.15)
                                  : AurixTokens.surface2,
                            ),
                            child: Icon(lic.icon, size: 18,
                              color: isSelected ? AurixTokens.accent : AurixTokens.muted),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(lic.title, style: TextStyle(
                                      fontFamily: AurixTokens.fontHeading,
                                      color: AurixTokens.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    )),
                                    if (isSold) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AurixTokens.danger.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Продано', style: TextStyle(
                                          color: AurixTokens.danger, fontSize: 10, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(lic.description, style: const TextStyle(
                                  color: AurixTokens.muted, fontSize: 11.5)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6, runSpacing: 4,
                                  children: lic.features.map((f) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 12,
                                        color: isSelected ? AurixTokens.accent : AurixTokens.positive),
                                      const SizedBox(width: 3),
                                      Text(f, style: TextStyle(
                                        color: AurixTokens.textSecondary, fontSize: 11)),
                                    ],
                                  )).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_formatPrice(price)} \u20BD',
                            style: TextStyle(
                              fontFamily: AurixTokens.fontHeading,
                              color: isSelected ? AurixTokens.accent : AurixTokens.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AurixTokens.danger, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            // Purchase button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _purchase,
                style: FilledButton.styleFrom(
                  backgroundColor: AurixTokens.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AurixTokens.accent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AurixTokens.radiusButton),
                  ),
                  textStyle: TextStyle(
                    fontFamily: AurixTokens.fontHeading,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Купить за ${_formatPrice(_price)} \u20BD'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Платформа берёт 15% комиссии. Продавец получает 85%.',
              style: const TextStyle(color: AurixTokens.micro, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AurixTokens.surface2,
      child: const Icon(Icons.audiotrack_rounded, color: AurixTokens.muted, size: 24),
    );
  }

  String _formatPrice(int price) {
    if (price >= 1000) {
      final thousands = price ~/ 1000;
      final remainder = price % 1000;
      if (remainder == 0) return '$thousands ${thousands == 1 ? "000" : "000"}';
      return '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')}';
    }
    return price.toString();
  }
}

class _LicenseInfo {
  final String type;
  final String title;
  final IconData icon;
  final String description;
  final List<String> features;

  const _LicenseInfo({
    required this.type,
    required this.title,
    required this.icon,
    required this.description,
    required this.features,
  });
}
