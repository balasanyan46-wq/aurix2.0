import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart' show ApiClient, asList;
import 'package:aurix_flutter/data/models/tool_result_model.dart';

class ToolService {
  Future<({int status, Map<String, dynamic> body})> _invokeViaHttp({
    required String fnName,
    required String releaseId,
    required Map<String, dynamic> enrichedInputs,
  }) async {
    try {
      final res = await ApiClient.post('/tools/$fnName', data: {
        'releaseId': releaseId,
        'inputs': enrichedInputs,
      });
      final data = res.data;
      final body = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      return (status: res.statusCode ?? 200, body: body);
    } catch (e) {
      debugPrint('[ToolService] _invokeViaHttp error: $e');
      return (status: 500, body: <String, dynamic>{'error': e.toString()});
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

  Future<ToolResultModel?> getSaved(String releaseId, String toolKey) async {
    try {
      final res = await ApiClient.get('/release-tools/latest', query: {
        'release_id': releaseId,
        'tool_key': toolKey,
      });
      final row = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
      if (row == null) return null;
      return ToolResultModel.fromJson(row);
    } catch (e) {
      debugPrint('[ToolService] getSaved($toolKey) error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _buildRichContext(String releaseId) async {
    final ctx = <String, dynamic>{};
    try {
      final profileRes = await ApiClient.get('/profiles/me');
      final profile = profileRes.data is Map ? Map<String, dynamic>.from(profileRes.data as Map) : null;
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
      final releaseRes = releaseResponse.data is Map ? Map<String, dynamic>.from(releaseResponse.data as Map) : null;
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

      final tracksResponse = await ApiClient.get('/tracks/release/$releaseId');
      final tracksRes = asList(tracksResponse.data);
      if (tracksRes.isNotEmpty) {
        ctx['tracks'] = tracksRes.map((t) => {
              'title': t['title'] ?? '',
              'isrc': t['isrc'] ?? '',
              'version': t['version'] ?? 'original',
              'explicit': t['explicit'] ?? false,
            }).toList();
      }

      final myReleasesResponse = await ApiClient.get('/releases/my');
      final otherReleases = asList(myReleasesResponse.data);
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
      final richContext = await _buildRichContext(releaseId);
      final inputContext = inputs['context'];
      final mergedContext = inputContext is Map
          ? <String, dynamic>{...richContext, ...inputContext.cast<String, dynamic>()}
          : richContext;

      final enrichedInputs = <String, dynamic>{
        ...inputs,
        'context': mergedContext,
      };

      final fnName = _functionMap[toolKey] ?? toolKey;
      debugPrint('[ToolService] generate($toolKey) invoke $fnName');

      final httpRes = await _invokeViaHttp(
        fnName: fnName,
        releaseId: releaseId,
        enrichedInputs: enrichedInputs,
      );

      final body = httpRes.body;
      debugPrint('[ToolService] generate($toolKey) status=${httpRes.status}');

      if (httpRes.status == 200 && body['data'] is Map) {
        return (
          ok: true,
          isDemo: body['is_demo'] as bool? ?? false,
          data: body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : <String, dynamic>{},
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
