import 'package:aurix_flutter/core/api/api_client.dart';

class CookieConsentState {
  const CookieConsentState({
    required this.analyticsAllowed,
    required this.marketingAllowed,
  });

  final bool analyticsAllowed;
  final bool marketingAllowed;
}

class LegalComplianceRepository {
  Future<void> recordMandatoryAcceptances({
    required String source,
    required String termsVersion,
    required String privacyVersion,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await ApiClient.post('/legal-acceptances/batch', data: [
      {
        'doc_slug': 'terms',
        'version': termsVersion,
        'accepted_at': nowIso,
        'acceptance_source': source,
      },
      {
        'doc_slug': 'privacy',
        'version': privacyVersion,
        'accepted_at': nowIso,
        'acceptance_source': source,
      },
    ]);
  }

  Future<void> upsertCookieChoices({
    required bool analyticsAllowed,
    required bool marketingAllowed,
    String source = 'settings',
  }) async {
    await ApiClient.put('/cookie-consents', data: {
      'analytics_allowed': analyticsAllowed,
      'marketing_allowed': marketingAllowed,
      'source': source,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<CookieConsentState> loadOrCreateCookieChoices({
    String source = 'settings',
  }) async {
    try {
      final res = await ApiClient.get('/cookie-consents');
      final body = res.data;
      if (body is Map<String, dynamic> && body.isNotEmpty) {
        return CookieConsentState(
          analyticsAllowed: body['analytics_allowed'] as bool? ?? true,
          marketingAllowed: body['marketing_allowed'] as bool? ?? false,
        );
      }
    } catch (_) {}

    const initial = CookieConsentState(
      analyticsAllowed: true,
      marketingAllowed: false,
    );
    await upsertCookieChoices(
      analyticsAllowed: initial.analyticsAllowed,
      marketingAllowed: initial.marketingAllowed,
      source: source,
    );
    return initial;
  }
}
