import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import '../data/dnk_tests_service.dart';
import 'dnk_test_result_screen.dart';

class DnkTestResultLoaderScreen extends StatefulWidget {
  final String resultId;

  const DnkTestResultLoaderScreen({super.key, required this.resultId});

  @override
  State<DnkTestResultLoaderScreen> createState() => _DnkTestResultLoaderScreenState();
}

class _DnkTestResultLoaderScreenState extends State<DnkTestResultLoaderScreen> {
  late final Future _future = DnkTestsService().getResultById(widget.resultId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: Text(
                'Ошибка: ${snap.error}',
                style: const TextStyle(color: AurixTokens.negative),
              ),
            ),
          );
        }
        final result = snap.data;
        if (result == null) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: Text('Результат не найден', style: TextStyle(color: AurixTokens.muted)),
            ),
          );
        }
        return DnkTestResultScreen(result: result);
      },
    );
  }
}
