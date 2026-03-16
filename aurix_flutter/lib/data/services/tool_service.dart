import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/core/api/token_store.dart';
import 'package:aurix_flutter/config/app_config.dart';
import 'package:aurix_flutter/data/models/tool_result_model.dart';

class ToolService {
  bool _looksLikeJwt(String token) {
    final parts = token.split('.');
    return parts.length == 3 && parts[0].isNotEmpty && parts[1].isNotEmpty;
  }

  bool _isJwtExpiredOrNearExpiry(String token, {int skewSeconds = 30}) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload);
      if (map is! Map || map['exp'] == null) return false;
      final exp = (map['exp'] as num).toInt();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return now >= (exp - skewSeconds);
    } catch (e) {
      debugPrint('[ToolService] JWT parse failed: $e');
      // If payload cannot be parsed, treat token as expired to force refresh.
      return true;
    }
  }

  Future<String?> _resolveAccessToken({bool forceRefresh = false}) async {
    final token = forceRefresh ? await TokenStore.read() : (TokenStore.cachedToken ?? await TokenStore.read());
    if (token == null || !_looksLikeJwt(token) || _isJwtExpiredOrNearExpiry(token)) {
      return null;
    }
    return token;
  }

  Future<({int status, Map<String, dynamic> body})> _invokeViaHttp({
    required String fnName,
    required String token,
    required String releaseId,
    required Map<String, dynamic> enrichedInputs,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tools/$fnName');
    final res = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'releaseId': releaseId, 'inputs': enrichedInputs}),
    );
    final raw = res.body.trim();
    if (raw.isEmpty) return (status: res.statusCode, body: <String, dynamic>{});
    try {
      return (
        status: res.statusCode,
        body: (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (e) {
      debugPrint('[ToolService] JSON parse failed: $e');
      return (
        status: res.statusCode,
        body: <String, dynamic>{'error': raw},
      );
    }
  }

  static const _functionMap = {
    'growth-plan': 'release-growth-plan',
    'budget-plan': 'release-budget-plan',
    'release-packaging': 'release-packaging',
    'content-plan-14': 'content-plan-14',
    'playlist-pitch-pack': 'playlist-pitch-pack',
    'dnk-content-bridge': 'dnk-content-bridge',
  };

  bool _isStudioToolPayload(Map<String, dynamic> payload) {
    final toolId = payload['tool_id'];
    final answers = payload['answers'];
    final outputFormat = payload['output_format'];
    return toolId is String &&
        toolId.trim().isNotEmpty &&
        answers is Map &&
        (outputFormat == null || outputFormat.toString().toLowerCase() == 'json');
  }

  Uri _workerChatUri() {
    final base = AppConfig.cfBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/api/ai/chat');
  }

  Uri _workerToolUri(String toolKey) {
    final base = AppConfig.cfBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/v1/tools/$toolKey');
  }

  Map<String, dynamic>? _extractWorkerData(Map<String, dynamic> body) {
    if (body['status']?.toString() == 'ok' && body['data'] is Map) {
      return <String, dynamic>{
        'status': body['status'],
        'tool_id': body['tool_id'],
        'version': body['version'],
        'data': (body['data'] as Map).cast<String, dynamic>(),
        'meta': body['meta'] is Map ? (body['meta'] as Map).cast<String, dynamic>() : <String, dynamic>{},
      };
    }
    return null;
  }

  String? _expectedContractToolId(String toolKey) {
    switch (toolKey) {
      case 'growth-plan':
        return 'growth_plan';
      case 'budget-plan':
        return 'budget_plan';
      case 'release-packaging':
        return 'packaging';
      case 'content-plan-14':
        return 'content_plan';
      case 'playlist-pitch-pack':
        return 'pitch_pack';
      default:
        return null;
    }
  }

  Map<String, dynamic>? _extractStrictResult(Map<String, dynamic> body) {
    final direct = _extractWorkerData(body);
    if (direct != null) return direct;
    if (body['ok'] == true && body['data'] is Map) {
      final nested = (body['data'] as Map).cast<String, dynamic>();
      return _extractWorkerData(nested);
    }
    return null;
  }

  Future<({bool ok, Map<String, dynamic> data, String? error})> _invokeWorkerToolEndpoint({
    required String toolKey,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final res = await http
          .post(
            _workerToolUri(toolKey),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 45));
      final raw = res.body.trim();
      if (raw.isEmpty) {
        return (ok: false, data: const <String, dynamic>{}, error: 'Worker tool endpoint returned empty body');
      }
      final body = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final data = _extractWorkerData(body);
      if (res.statusCode == 200 && data != null) {
        return (ok: true, data: data, error: null);
      }
      final msg = (body['message'] as String?) ?? (body['error'] as String?) ?? 'Worker tool endpoint failed (${res.statusCode})';
      return (ok: false, data: const <String, dynamic>{}, error: msg);
    } catch (e) {
      return (ok: false, data: const <String, dynamic>{}, error: e.toString());
    }
  }

  Future<({bool ok, Map<String, dynamic> data, String? error})> _invokeStudioWorker(
    String toolKey,
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await http
          .post(
            _workerChatUri(),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 45));
      final raw = res.body.trim();
      Map<String, dynamic> body = <String, dynamic>{};
      if (raw.isNotEmpty) {
        try {
          body = (jsonDecode(raw) as Map).cast<String, dynamic>();
        } catch (e) {
          debugPrint('[ToolService] worker response parse failed: $e');
          return (ok: false, data: const <String, dynamic>{}, error: 'Worker non-JSON response');
        }
      }
      if (res.statusCode != 200) {
        final msg = (body['message'] as String?) ?? (body['error'] as String?) ?? 'Worker chat failed (${res.statusCode})';
        final fallback = await _invokeWorkerToolEndpoint(toolKey: toolKey, payload: payload);
        if (fallback.ok) return fallback;
        return (ok: false, data: const <String, dynamic>{}, error: '$msg | tools fallback: ${fallback.error}');
      }
      final data = _extractWorkerData(body);
      if (data != null) {
        final expectedToolId = _expectedContractToolId(toolKey);
        final actualToolId = body['tool_id']?.toString();
        if (expectedToolId != null && actualToolId != expectedToolId) {
          return (ok: false, data: const <String, dynamic>{}, error: 'Worker returned mismatched tool_id');
        }
        return (ok: true, data: data, error: null);
      }
      final fallback = await _invokeWorkerToolEndpoint(toolKey: toolKey, payload: payload);
      if (fallback.ok) return fallback;
      return (ok: false, data: const <String, dynamic>{}, error: 'Worker studio mode payload mismatch | tools fallback: ${fallback.error}');
    } catch (e) {
      final fallback = await _invokeWorkerToolEndpoint(toolKey: toolKey, payload: payload);
      if (fallback.ok) return fallback;
      return (ok: false, data: const <String, dynamic>{}, error: '${e.toString()} | tools fallback: ${fallback.error}');
    }
  }

  Future<ToolResultModel?> getSaved(String releaseId, String toolKey) async {
    try {
      final res = await ApiClient.get('/release-tools/latest', query: {
        'release_id': releaseId,
        'tool_key': toolKey,
      });
      final row = res.data as Map<String, dynamic>?;
      if (row == null) return null;
      return ToolResultModel.fromJson(row);
    } catch (e) {
      debugPrint('[ToolService] getSaved($toolKey) error: $e');
      return null;
    }
  }

  /// Собирает полный контекст об артисте и релизе для персонализации AI.
  Future<Map<String, dynamic>> _buildRichContext(String releaseId) async {
    final ctx = <String, dynamic>{};
    try {
      final profileRes = await ApiClient.get('/profiles/me');
      final profile = (profileRes.data as Map<String, dynamic>?);
      if (profile != null) {
        ctx['artist'] = {
          'name': profile['artist_name'] ?? profile['display_name'] ?? profile['name'] ?? '',
          'real_name': profile['name'] ?? '',
          'city': profile['city'] ?? '',
          'bio': profile['bio'] ?? '',
          'plan': profile['plan'] ?? 'start',
        };
      }

      final releaseResponse = await ApiClient.get('/releases/$releaseId');
      final releaseRes = releaseResponse.data as Map<String, dynamic>?;
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
      final tracksResponse = await ApiClient.get('/tracks/release/$releaseId');
      final tracksRes = (tracksResponse.data as List?) ?? const [];
      if (tracksRes.isNotEmpty) {
        ctx['tracks'] = tracksRes.map((t) => {
              'title': t['title'] ?? '',
              'isrc': t['isrc'] ?? '',
              'version': t['version'] ?? 'original',
              'explicit': t['explicit'] ?? false,
            }).toList();
      }

      final myReleasesResponse = await ApiClient.get('/releases/my');
      final otherReleases = (myReleasesResponse.data as List?) ?? const [];
      if (otherReleases.isNotEmpty) {
        ctx['catalog'] = otherReleases
            .where((r) => (r['id'] ?? '').toString() != releaseId)
            .take(10)
            .map((r) => '${r['artist'] ?? ''} — ${r['title']} (${r['release_type']}, ${r['status']})')
            .toList();
      }
    } catch (e) {
      debugPrint('[ToolService] _buildRichContext error: $e');
    }
    return ctx;
  }

  Future<bool> deleteSaved(String releaseId, String toolKey) async {
    try {
      await ApiClient.delete('/release-tools/$releaseId/$toolKey');
      return true;
    } catch (e) {
      debugPrint('[ToolService] deleteSaved($toolKey) error: $e');
      return false;
    }
  }

  Future<({bool ok, bool isDemo, Map<String, dynamic> data, String? error})>
      generate(String releaseId, String toolKey, Map<String, dynamic> inputs) async {
    try {
      final useDirectWorker = AppConfig.studioToolsDirectWorker;
      final richContext = await _buildRichContext(releaseId);
      final inputContext = inputs['context'];
      final mergedContext = inputContext is Map
          ? <String, dynamic>{...richContext, ...inputContext.cast<String, dynamic>()}
          : richContext;

      final enrichedInputs = <String, dynamic>{
        ...inputs,
        'context': mergedContext,
      };
      final isStudioPayload = _isStudioToolPayload(enrichedInputs);

      if (isStudioPayload && useDirectWorker) {
        final workerRes = await _invokeStudioWorker(toolKey, enrichedInputs);
        if (workerRes.ok) {
          debugPrint('[ToolService] generate($toolKey) transport=worker status=ok parse=strict');
          return (ok: true, isDemo: false, data: workerRes.data, error: null);
        }
        debugPrint('[ToolService] generate($toolKey) transport=worker status=error reason=${workerRes.error}');
      }

      final token = await _resolveAccessToken();
      if (token == null) {
        if (isStudioPayload && useDirectWorker) {
          final workerRes = await _invokeStudioWorker(toolKey, enrichedInputs);
          if (workerRes.ok) {
            debugPrint('[ToolService] generate($toolKey) worker fallback without JWT success');
            return (ok: true, isDemo: false, data: workerRes.data, error: null);
          }
          debugPrint('[ToolService] generate($toolKey) worker fallback without JWT failed: ${workerRes.error}');
        }
        return (
          ok: false,
          isDemo: false,
          data: <String, dynamic>{},
          error: 'Нужен повторный вход в аккаунт.',
        );
      }
      final fnName = _functionMap[toolKey] ?? toolKey;
      debugPrint('[ToolService] generate($toolKey) invoke $fnName');
      final httpRes = await _invokeViaHttp(
        fnName: fnName,
        token: token,
        releaseId: releaseId,
        enrichedInputs: enrichedInputs,
      );
      final payload = httpRes.body;
      debugPrint('[ToolService] generate($toolKey) status=${httpRes.status}');
      debugPrint(
        '[ToolService] generate($toolKey) body=${payload.toString().length > 500 ? payload.toString().substring(0, 500) : payload.toString()}',
      );

      final body = payload;

      final strictResponse = _extractStrictResult(body);
      if (httpRes.status == 200 && strictResponse != null) {
        return (
          ok: true,
          isDemo: body['is_demo'] as bool? ?? false,
          data: strictResponse,
          error: null,
        );
      }

      final errorMsg =
          (body['error'] as String?) ??
          (body['message'] as String?) ??
          'Unknown error (${httpRes.status})';
      return (ok: false, isDemo: false, data: <String, dynamic>{}, error: errorMsg);
    } catch (e, st) {
      debugPrint('[ToolService] generate($toolKey) error: $e');
      debugPrint('[ToolService] stackTrace: $st');
      return (ok: false, isDemo: false, data: <String, dynamic>{}, error: e.toString());
    }
  }
}
