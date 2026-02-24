import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/screens/studio_ai/studio_ai_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/tools_home_screen.dart';

class StudioScreen extends ConsumerWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccess = ref.watch(hasStudioAccessProvider);

    return hasAccess.when(
      data: (access) {
        if (access) return const _StudioTabs();
        return _PaywallScreen();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const _StudioTabs(),
    );
  }
}

class _StudioTabs extends StatefulWidget {
  const _StudioTabs();

  @override
  State<_StudioTabs> createState() => _StudioTabsState();
}

class _StudioTabsState extends State<_StudioTabs> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aurix Studio AI'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.chat_rounded), text: 'Чат'),
            Tab(icon: Icon(Icons.build_rounded), text: 'Инструменты'),
          ],
          indicatorColor: cs.primary,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          StudioAiScreen(),
          ToolsHomeScreen(),
        ],
      ),
    );
  }
}

class _PaywallScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aurix Studio AI')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Aurix Studio AI доступен в планах Прорыв и Империя',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Оформите подписку Прорыв или Империя, чтобы использовать продюсерский AI.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.push('/subscription'),
                child: const Text('К планам'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('На главную'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
