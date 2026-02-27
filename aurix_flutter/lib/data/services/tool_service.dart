import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:aurix_flutter/core/supabase_client.dart';
import 'package:aurix_flutter/config/app_config.dart';
import 'package:aurix_flutter/data/models/tool_result_model.dart';

class ToolService {
  static const _functionMap = {
    'growth-plan': 'release-growth-plan',
    'budget-plan': 'release-budget-plan',
    'release-packaging': 'release-packaging',
    'content-plan-14': 'content-plan-14',
    'playlist-pitch-pack': 'playlist-pitch-pack',
  };

  Future<String?> _refreshAccessToken() async {
    try {
      final res = await supabase.auth.refreshSession();
      final token = res.session?.accessToken ?? supabase.auth.currentSession?.accessToken;
      debugPrint('[ToolService] refreshSession: token=${token != null ? "ok" : "null"}');
      return token;
    } catch (e) {
      debugPrint('[ToolService] refreshSession error: $e');
      return supabase.auth.currentSession?.accessToken;
    }
  }

  Future<http.Response> _postWithAuthRetry(Uri url, Map<String, dynamic> body) async {
    Future<http.Response> doPost(String token) {
      return http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'apikey': AppConfig.supabaseAnonKey,
        },
        body: jsonEncode(body),
      );
    }

    final token = supabase.auth.currentSession?.accessToken;
    if (token == null) {
      return http.Response('{"ok":false,"error":"Not authenticated"}', 401);
    }

    var res = await doPost(token);
    if (res.statusCode != 401) return res;

    // Token may be expired; refresh and retry once.
    final refreshed = await _refreshAccessToken();
    if (refreshed == null || refreshed == token) return res;
    res = await doPost(refreshed);
    return res;
  }

  Future<ToolResultModel?> getSaved(String releaseId, String toolKey) async {
    try {
      final uid = supabase.auth.currentUser?.id;
      debugPrint('[ToolService] getSaved($toolKey) uid=$uid releaseId=$releaseId');
      if (uid == null) return null;
      final res = await supabase
          .from('release_tools')
          .select()
          .eq('release_id', releaseId)
          .eq('user_id', uid)
          .eq('tool_key', toolKey)
          .maybeSingle();
      debugPrint('[ToolService] getSaved($toolKey) result=${res != null ? "found" : "null"}');
      if (res == null) return null;
      return ToolResultModel.fromJson(res);
    } catch (e) {
      debugPrint('[ToolService] getSaved($toolKey) error: $e');
      return null;
    }
  }

  /// Собирает полный контекст об артисте и релизе для персонализации AI.
  Future<Map<String, dynamic>> _buildRichContext(String releaseId) async {
    final ctx = <String, dynamic>{};
    try {
      final uid = supabase.auth.currentUser?.id;

      // 1. Профиль артиста
      if (uid != null) {
        final profileRes = await supabase
            .from('profiles')
            .select()
            .eq('user_id', uid)
            .maybeSingle();
        if (profileRes != null) {
          ctx['artist'] = {
            'name': profileRes['artist_name'] ?? profileRes['display_name'] ?? profileRes['name'] ?? '',
            'real_name': profileRes['name'] ?? '',
            'city': profileRes['city'] ?? '',
            'bio': profileRes['bio'] ?? '',
            'plan': profileRes['plan'] ?? 'start',
          };
        }
      }

      // 2. Данные релиза
      final releaseRes = await supabase
          .from('releases')
          .select()
          .eq('id', releaseId)
          .maybeSingle();
      if (releaseRes != null) {
        ctx['release'] = {
          'title': releaseRes['title'] ?? '',
          'artist': releaseRes['artist'] ?? '',
          'genre': releaseRes['genre'] ?? '',
          'language': releaseRes['language'] ?? '',
          'release_type': releaseRes['release_type'] ?? '',
          'release_date': releaseRes['release_date'] ?? '',
          'upc': releaseRes['upc'] ?? '',
          'label': releaseRes['label'] ?? '',
          'explicit': releaseRes['explicit'] ?? false,
        };
      }

      // 3. Треки релиза
      final tracksRes = await supabase
          .from('tracks')
          .select()
          .eq('release_id', releaseId)
          .order('track_number');
      if (tracksRes.isNotEmpty) {
        ctx['tracks'] = tracksRes.map((t) => {
              'title': t['title'] ?? '',
              'isrc': t['isrc'] ?? '',
              'version': t['version'] ?? 'original',
              'explicit': t['explicit'] ?? false,
            }).toList();
      }

      // 4. Другие релизы артиста (для понимания каталога)
      if (uid != null) {
        final otherReleases = await supabase
            .from('releases')
            .select('title, artist, genre, release_type, status')
            .eq('owner_id', uid)
            .neq('id', releaseId)
            .order('created_at', ascending: false)
            .limit(10);
        if (otherReleases.isNotEmpty) {
          ctx['catalog'] = otherReleases
              .map((r) => '${r['artist'] ?? ''} — ${r['title']} (${r['release_type']}, ${r['status']})')
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[ToolService] _buildRichContext error: $e');
    }
    return ctx;
  }

  Future<bool> deleteSaved(String releaseId, String toolKey) async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return false;
      await supabase
          .from('release_tools')
          .delete()
          .eq('release_id', releaseId)
          .eq('user_id', uid)
          .eq('tool_key', toolKey);
      return true;
    } catch (e) {
      debugPrint('[ToolService] deleteSaved($toolKey) error: $e');
      return false;
    }
  }

  Future<({bool ok, bool isDemo, Map<String, dynamic> data, String? error})>
      generate(String releaseId, String toolKey, Map<String, dynamic> inputs) async {
    try {
      final richContext = await _buildRichContext(releaseId);

      final enrichedInputs = <String, dynamic>{
        ...inputs,
        'context': richContext,
      };

      final fnName = _functionMap[toolKey] ?? toolKey;
      final url = Uri.parse('${AppConfig.supabaseUrl}/functions/v1/$fnName');
      debugPrint('[ToolService] generate($toolKey) POST $url');

      final response = await _postWithAuthRetry(
        url,
        {'releaseId': releaseId, 'inputs': enrichedInputs},
      );

      debugPrint('[ToolService] generate($toolKey) status=${response.statusCode}');
      debugPrint('[ToolService] generate($toolKey) body=${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');

      Map<String, dynamic> body;
      try {
        body = (jsonDecode(response.body) as Map).cast<String, dynamic>();
      } catch (e) {
        final raw = response.body.trim();
        final msg = raw.isEmpty ? 'HTTP ${response.statusCode}' : raw;
        return (ok: false, isDemo: false, data: <String, dynamic>{}, error: msg);
      }

      if (response.statusCode == 200 && body['ok'] == true) {
        return (
          ok: true,
          isDemo: body['is_demo'] as bool? ?? false,
          data: body['data'] as Map<String, dynamic>? ?? {},
          error: null,
        );
      }

      if (response.statusCode == 401) {
        return (
          ok: false,
          isDemo: false,
          data: <String, dynamic>{},
          error: 'Сессия истекла. Перезайдите в аккаунт.',
        );
      }

      final errorMsg =
          (body['error'] as String?) ??
          (body['message'] as String?) ??
          'Unknown error (${response.statusCode})';
      return (ok: false, isDemo: false, data: <String, dynamic>{}, error: errorMsg);
    } catch (e, st) {
      debugPrint('[ToolService] generate($toolKey) error: $e');
      debugPrint('[ToolService] stackTrace: $st');
      return (ok: false, isDemo: false, data: <String, dynamic>{}, error: e.toString());
    }
  }
}
