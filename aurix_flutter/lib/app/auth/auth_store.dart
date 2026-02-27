import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single source of truth for auth state.
///
/// Guarantees:
/// - [ready] becomes true only after an explicit session restore attempt.
/// - [session]/[userId] are updated only from Supabase session events.
class AuthStore extends ChangeNotifier {
  bool _ready = false;
  Session? _session;
  StreamSubscription<AuthState>? _sub;

  bool get ready => _ready;
  Session? get session => _session;
  bool get isAuthed => _session != null;
  String? get userId => _session?.user.id;

  Future<void> init() async {
    if (_sub != null) return;

    // Supabase.initialize() restores session from storage asynchronously.
    // We mark [ready] only after the first auth-state emission (or a short timeout),
    // so UI cannot flash user-specific data from a stale session.
    _session = Supabase.instance.client.auth.currentSession;
    final first = Completer<void>();

    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      _session = state.session;
      if (!_ready) {
        _ready = true;
        notifyListeners();
        if (!first.isCompleted) first.complete();
        return;
      }
      notifyListeners();
    });

    // Safety: don't block forever if platform doesn't emit promptly.
    await Future.any([first.future, Future.delayed(const Duration(milliseconds: 650))]);
    if (!_ready) {
      _ready = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}

