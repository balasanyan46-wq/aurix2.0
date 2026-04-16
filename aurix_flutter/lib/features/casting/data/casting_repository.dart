import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/features/casting/domain/casting_application.dart';

class CastingRepository {
  CastingRepository._();
  static final instance = CastingRepository._();

  Future<Map<String, dynamic>> getPlans() async {
    final resp = await ApiClient.dio.get('/casting/plans');
    return resp.data['plans'] as Map<String, dynamic>;
  }

  Future<CastingSlots> getSlots(String city) async {
    final resp = await ApiClient.dio.get('/casting/slots', queryParameters: {'city': city});
    return CastingSlots.fromJson(resp.data['slots']);
  }

  Future<Map<String, dynamic>> purchase({
    required String name,
    required String phone,
    required String city,
    required String plan,
    int quantity = 1,
  }) async {
    final resp = await ApiClient.dio.post('/casting/purchase', data: {
      'name': name,
      'phone': phone,
      'city': city,
      'plan': plan,
      if (plan == 'audience' && quantity > 1) 'quantity': quantity,
    });
    return resp.data['data'] as Map<String, dynamic>;
  }

  Future<CastingApplication?> getOrder(String orderId) async {
    final resp = await ApiClient.dio.get('/casting/order/$orderId');
    if (resp.data['application'] == null) return null;
    return CastingApplication.fromJson(resp.data['application']);
  }

  // Admin
  Future<List<CastingApplication>> adminGetAll({String? city, String? status, String? search}) async {
    final params = <String, String>{};
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final resp = await ApiClient.dio.get('/casting/admin/all', queryParameters: params);
    final list = resp.data['applications'] as List;
    return list.map((e) => CastingApplication.fromJson(e)).toList();
  }

  Future<CastingStats> adminGetStats() async {
    final resp = await ApiClient.dio.get('/casting/admin/stats');
    return CastingStats.fromJson(resp.data['stats']);
  }

  Future<CastingApplication> adminUpdateStatus(int id, String status) async {
    final resp = await ApiClient.dio.patch('/casting/admin/$id/status', data: {'status': status});
    return CastingApplication.fromJson(resp.data['application']);
  }
}
