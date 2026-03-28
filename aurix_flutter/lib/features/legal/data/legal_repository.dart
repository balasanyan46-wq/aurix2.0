import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart' show ApiClient, asList;
import 'package:aurix_flutter/features/legal/data/legal_document_model.dart';
import 'package:aurix_flutter/features/legal/data/legal_template_model.dart';

class LegalRepository {
  /// Шаблоны из public.legal_templates с опциональным поиском и фильтром.
  Future<List<LegalTemplateModel>> fetchTemplates({
    String? query,
    LegalCategory? category,
  }) async {
    final res = await ApiClient.get('/legal-templates', query: {
      if (category != null && category != LegalCategory.all) 'category': category.name,
    });
    final rows = asList(res.data);
    var list = rows.map((e) => LegalTemplateModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    debugPrint('[LegalRepository] fetchTemplates count=${list.length}');
    if (query != null && query.trim().isNotEmpty) {
      final qq = query.trim().toLowerCase();
      list = list.where((t) {
        return t.title.toLowerCase().contains(qq) || t.description.toLowerCase().contains(qq);
      }).toList();
    }
    return list;
  }

  Future<LegalTemplateModel?> getTemplateById(String id) async {
    final res = await ApiClient.get('/legal-templates/$id');
    final row = res.data;
    if (row == null) return null;
    return LegalTemplateModel.fromJson(row is Map ? (row as Map).cast<String, dynamic>() : <String, dynamic>{});
  }

  /// Документы текущего пользователя.
  Future<List<LegalDocumentModel>> fetchMyDocuments() async {
    final res = await ApiClient.get('/legal-documents/my');
    final rows = asList(res.data);
    return rows.map((e) => LegalDocumentModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Создаёт запись документа. Возвращает созданный документ с id.
  Future<LegalDocumentModel> createDocumentRecord({
    required LegalTemplateModel template,
    required Map<String, String> payload,
  }) async {
    final payloadMap = payload.map((k, v) => MapEntry(k, v));
    final data = {
      'template_id': template.id,
      'template_version': template.version ?? 1,
      'title': template.title,
      'payload': payloadMap,
      'status': 'generated',
    };
    final response = await ApiClient.post('/legal-documents', data: data);
    final res = response.data is Map ? (response.data as Map).cast<String, dynamic>() : <String, dynamic>{};
    debugPrint('[LegalRepository] createDocumentRecord documentId=${res['id']}');
    return LegalDocumentModel.fromJson(Map<String, dynamic>.from(res));
  }

  /// Загружает PDF в storage. Путь: {userId}/{documentId}.pdf
  Future<String> uploadPdf(String userId, String documentId, Uint8List bytes) async {
    final path = '$userId/$documentId.pdf';
    await ApiClient.uploadFile('/upload/cover', bytes, '$documentId.pdf');
    debugPrint('[LegalRepository] uploadPdf path=$path');
    return path;
  }

  Future<void> updateDocumentPdfPath(String documentId, String path) async {
    await ApiClient.put('/legal-documents/$documentId', data: {'file_pdf_path': path});
    debugPrint('[LegalRepository] updateDocumentPdfPath documentId=$documentId path=$path');
  }

  /// Signed URL для PDF. path = userId/documentId.pdf (без documents/).
  Future<String?> signedPdfUrl(String path, {int expiresIn = 3600}) async {
    try {
      final res = await ApiClient.get('/legal-documents/signed-url', query: {
        'path': path,
        'expires_in': expiresIn,
      });
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final url = body['url']?.toString();
      debugPrint('[LegalRepository] signedPdfUrl path=$path ok');
      return url;
    } catch (e) {
      debugPrint('[LegalRepository] signedPdfUrl error: $e');
      return null;
    }
  }
}
