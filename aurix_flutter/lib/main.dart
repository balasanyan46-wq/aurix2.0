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

  // Show minimal error in release mode (instead of grey box)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const SizedBox.shrink();
  };

  runApp(const ProviderScope(child: AurixApp()));
}
