import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:aurix_flutter/app.dart';
import 'package:aurix_flutter/core/api/token_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);
  await TokenStore.read();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('AURIX FlutterError: ${details.exception}\n${details.stack}');
  };

  // Show actual error text in release mode (instead of grey box)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1A0000),
      child: Text(
        'Error: ${details.exception}',
        style: const TextStyle(color: Color(0xFFFF4444), fontSize: 12),
      ),
    );
  };

  runApp(const ProviderScope(child: AurixApp()));
}
