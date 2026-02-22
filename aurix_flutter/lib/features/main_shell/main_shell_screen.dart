import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/dashboard/dashboard_screen.dart';
import 'package:aurix_flutter/features/legal/legal_screen.dart';
import 'package:aurix_flutter/features/main_shell/main_shell_provider.dart';
import 'package:aurix_flutter/features/releases/releases_screen.dart';
import 'package:aurix_flutter/features/studio/studio_screen.dart';
import 'package:aurix_flutter/features/profile/profile_screen.dart';

/// Shell с BottomNavigationBar и IndexedStack.
/// Сохраняет состояние экранов при переключении вкладок.
class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(mainShellTabProvider);

    const tabs = [
      (icon: Icons.home_rounded, label: 'Главная'),
      (icon: Icons.album_rounded, label: 'Релизы'),
      (icon: Icons.auto_awesome_rounded, label: 'Studio AI'),
      (icon: Icons.gavel_rounded, label: 'Юридика'),
      (icon: Icons.person_rounded, label: 'Профиль'),
    ];

    const screens = [
      DashboardScreen(),
      ReleasesScreen(),
      StudioScreen(),
      LegalScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AurixTokens.bg1,
          border: Border(top: BorderSide(color: AurixTokens.stroke())),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(tabs.length, (i) {
                final t = tabs[i];
                final selected = currentIndex == i;
                return InkWell(
                  onTap: () => ref.read(mainShellTabProvider.notifier).state = i,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          t.icon,
                          size: 24,
                          color: selected ? AurixTokens.orange : AurixTokens.muted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? AurixTokens.orange : AurixTokens.muted,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
