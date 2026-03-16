import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import '../data/dnk_tests_models.dart';
import '../data/dnk_tests_service.dart';
import 'dnk_test_interview_screen.dart';
import 'dnk_test_result_screen.dart';

class DnkTestLaunchScreen extends ConsumerStatefulWidget {
  final String testSlug;

  const DnkTestLaunchScreen({super.key, required this.testSlug});

  @override
  ConsumerState<DnkTestLaunchScreen> createState() => _DnkTestLaunchScreenState();
}

class _DnkTestLaunchScreenState extends ConsumerState<DnkTestLaunchScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Нужна авторизация';
      });
      return;
    }
    final service = DnkTestsService();
    try {
      final catalog = await service.getCatalog();
      final item = catalog.firstWhere(
        (x) => x.slug == widget.testSlug,
        orElse: () => DnkTestCatalogItem(
          slug: widget.testSlug,
          title: widget.testSlug,
          description: '',
          whatGives: '',
          exampleResult: '',
          exampleJson: const {},
        ),
      );
      final start = await service.startSession(userId: user.id, testSlug: widget.testSlug);
      if (!mounted) return;
      final result = await Navigator.of(context).push<DnkTestResult>(
        MaterialPageRoute(
          builder: (_) => DnkTestInterviewScreen(
            testTitle: item.title,
            startResponse: start,
          ),
        ),
      );
      if (!mounted) return;
      if (result != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DnkTestResultScreen(result: result)),
        );
      }
      if (mounted) context.go('/dnk/tests');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error ?? 'Не удалось запустить тест',
            style: const TextStyle(color: AurixTokens.negative),
          ),
        ),
      ),
    );
  }
}
