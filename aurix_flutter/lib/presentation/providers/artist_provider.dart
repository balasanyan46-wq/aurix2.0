import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurix_flutter/app/auth/auth_store_provider.dart';
import 'package:aurix_flutter/presentation/screens/studio/models/artist_profile.dart';
import 'package:aurix_flutter/presentation/screens/studio/models/ai_memory.dart';

// ─── Keys ────────────────────────────────────────────────────
String _profileKey(String uid) => 'artist_profile_$uid';
String _memoryKey(String uid) => 'ai_memory_$uid';

// ─── Artist Profile ──────────────────────────────────────────
final artistProfileProvider =
    StateNotifierProvider<ArtistProfileNotifier, ArtistProfile>((ref) {
  final uid = ref.watch(authStoreProvider).userId ?? 'anon';
  return ArtistProfileNotifier(uid);
});

class ArtistProfileNotifier extends StateNotifier<ArtistProfile> {
  final String _uid;

  ArtistProfileNotifier(this._uid) : super(ArtistProfile()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey(_uid));
    if (raw != null && raw.isNotEmpty) {
      state = ArtistProfile.decode(raw);
    }
  }

  Future<void> save(ArtistProfile profile) async {
    state = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey(_uid), profile.encode());
  }

  Future<void> incrementSessions() async {
    final updated = state;
    updated.sessionsCount++;
    await save(updated);
  }

  /// Award XP for a character action and persist.
  Future<void> awardXp(XpAction action) async {
    final updated = state;
    updated.addXp(action);
    updated.sessionsCount++;
    await save(updated);
  }

  /// Award pipeline completion bonus.
  Future<void> awardPipelineBonus() async {
    final updated = state;
    updated.addXp(XpAction.pipeline);
    await save(updated);
  }

  /// Set artist goal.
  Future<void> setGoal(String goal) async {
    final updated = state;
    updated.goal = goal;
    await save(updated);
  }
}

// ─── AI Memory ───────────────────────────────────────────────
final aiMemoryProvider =
    StateNotifierProvider<AiMemoryNotifier, AiMemory>((ref) {
  final uid = ref.watch(authStoreProvider).userId ?? 'anon';
  return AiMemoryNotifier(uid);
});

class AiMemoryNotifier extends StateNotifier<AiMemory> {
  final String _uid;

  AiMemoryNotifier(this._uid) : super(AiMemory()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_memoryKey(_uid));
    if (raw != null && raw.isNotEmpty) {
      state = AiMemory.decode(raw);
    }
  }

  Future<void> addEntry(String characterId, String idea, String result) async {
    state.add(characterId, idea, result);
    state = AiMemory(entries: state.entries);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_memoryKey(_uid), state.encode());
  }
}

/// Whether the artist profile has been filled (onboarding complete).
final hasArtistProfileProvider = Provider<bool>((ref) {
  final profile = ref.watch(artistProfileProvider);
  return !profile.isEmpty;
});
