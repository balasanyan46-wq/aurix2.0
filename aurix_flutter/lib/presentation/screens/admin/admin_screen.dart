import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/screens/admin/admin_releases_screen.dart';
import 'package:aurix_flutter/presentation/screens/admin/admin_reports_screen.dart';

/// Admin hub: Submissions (releases) + Reports (CSV import).
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == 'reports' ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(isAdminProvider);

    return isAdminAsync.when(
      data: (isAdmin) {
        if (!isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/home');
          });
          return const Scaffold(
            body: Center(child: Text('Доступ запрещён')),
          );
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
              onPressed: () => context.go('/home'),
            ),
            title: Text(
              'Admin',
              style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AurixTokens.orange,
              labelColor: AurixTokens.orange,
              unselectedLabelColor: AurixTokens.muted,
              tabs: const [
                Tab(text: 'Заявки'),
                Tab(text: 'Отчёты'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              AdminReleasesTabContent(),
              AdminReportsTabContent(),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
      ),
      error: (_, __) => Scaffold(
        body: Center(child: Text('Ошибка', style: TextStyle(color: AurixTokens.muted))),
      ),
    );
  }
}

class AdminReleasesTabContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AdminReleasesScreen(embedded: true);
  }
}

class AdminReportsTabContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AdminReportsScreen();
  }
}
