import 'package:flutter/material.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';

/// Модал детали услуги: заголовок, offer, what you get, how it works, CTA.
class ServiceDetailModal extends StatelessWidget {
  final String title;
  final IconData icon;
  final String offer;
  final List<String> whatYouGet;
  final List<String> howItWorks;
  final String timeline;
  final bool available;
  final VoidCallback onRequest;

  const ServiceDetailModal({
    super.key,
    required this.title,
    required this.icon,
    required this.offer,
    required this.whatYouGet,
    required this.howItWorks,
    required this.timeline,
    required this.available,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AurixTokens.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AurixTokens.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: AurixTokens.orange, size: 28),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Text(title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(offer, style: TextStyle(color: AurixTokens.text, fontSize: 16, height: 1.5)),
                const SizedBox(height: 24),
                Text(L10n.t(context, 'whatYouGetDetails'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...whatYouGet.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, size: 18, color: AurixTokens.orange),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s, style: TextStyle(color: AurixTokens.text, fontSize: 14))),
                    ],
                  ),
                )),
                const SizedBox(height: 20),
                Text(L10n.t(context, 'howItWorksProcess'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...howItWorks.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AurixTokens.orange.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${e.key + 1}', style: TextStyle(
                            color: AurixTokens.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          )),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.value, style: TextStyle(color: AurixTokens.text, fontSize: 14))),
                    ],
                  ),
                )),
                const SizedBox(height: 20),
                Text('Сроки и результат', style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(timeline, style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                const SizedBox(height: 28),
                AurixButton(
                  text: L10n.t(context, 'submitRequest'),
                  icon: Icons.send_rounded,
                  onPressed: available ? () {
                    Navigator.pop(context);
                    onRequest();
                  } : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
