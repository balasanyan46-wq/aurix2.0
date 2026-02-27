import 'package:aurix_flutter/app/auth/auth_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authStoreProvider = ChangeNotifierProvider<AuthStore>((ref) {
  final store = AuthStore();
  // Init is awaited in main(), but keep a safety init for hot-reload/dev.
  // ignore: discarded_futures
  store.init();
  ref.onDispose(store.dispose);
  return store;
});

