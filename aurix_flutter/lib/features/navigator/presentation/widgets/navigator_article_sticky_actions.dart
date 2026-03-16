import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

class NavigatorArticleStickyActions extends StatelessWidget {
  const NavigatorArticleStickyActions({
    super.key,
    required this.isSaved,
    required this.isCompleted,
    required this.readingProgress,
    required this.onSave,
    required this.onComplete,
    required this.onAddToRoute,
    required this.onShare,
  });

  final bool isSaved;
  final bool isCompleted;
  final double readingProgress;
  final VoidCallback onSave;
  final VoidCallback onComplete;
  final VoidCallback onAddToRoute;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final canComplete = isCompleted || readingProgress >= 0.85;
    return Container(
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: AurixTokens.stroke(0.2))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SafeArea(
        top: false,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AurixTokens.glass(0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AurixTokens.stroke(0.2)),
                ),
                child: Text(
                  canComplete
                      ? 'Ты почти дочитал — зафиксируй прогресс'
                      : 'Дочитай до конца, чтобы закрыть материал',
                  style: const TextStyle(
                    color: AurixTokens.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            FilledButton(
              onPressed: onSave,
              child: Text(isSaved ? 'Сохранено' : 'Сохранить'),
            ),
            (canComplete
                ? FilledButton(
                    onPressed: onComplete,
                    child: Text(isCompleted ? 'Пройдено' : 'Отметить пройденным'),
                  )
                : const OutlinedButton(
                    onPressed: null,
                    child: Text('Отметить пройденным'),
                  )),
            OutlinedButton(
              onPressed: onAddToRoute,
              child: const Text('Добавить в маршрут'),
            ),
            OutlinedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('Поделиться'),
            ),
          ],
        ),
      ),
    );
  }
}
