import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:aurix_flutter/config/app_mode.dart';
import 'package:aurix_flutter/presentation/design/design_app.dart';
import 'package:aurix_flutter/app.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/core/api/token_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);
  // Pre-load cached JWT token for ApiClient interceptor.
  await TokenStore.read();
  if (kDesignMode) {
    FlutterError.onError = (details) {
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };
    ErrorWidget.builder = (details) => _DesignErrorFallback(details: details);
    runApp(const ProviderScope(child: DesignApp()));
    return;
  }
  runApp(const ProviderScope(child: AurixApp()));
}

class _DesignErrorFallback extends StatelessWidget {
  final FlutterErrorDetails details;

  const _DesignErrorFallback({required this.details});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AurixTokens.bg0,
      child: SafeArea(
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            color: AurixTokens.glass(0.15),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: AurixTokens.orange, size: 48),
                  const SizedBox(height: 16),
                  const Text('Something went wrong'),
                  const SizedBox(height: 8),
                  Text(details.exceptionAsString(), style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
