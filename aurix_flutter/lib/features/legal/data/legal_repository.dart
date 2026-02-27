import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:aurix_flutter/data/supabase_client.dart';
import 'package:aurix_flutter/features/legal/data/legal_document_model.dart';
import 'package:aurix_flutter/features/legal/data/legal_template_model.dart';

const _bucket = 'documents';

class LegalRepository {
  /// Шаблоны из public.legal_templates с опциональным поиском и фильтром.
  Future<List<LegalTemplateModel>> fetchTemplates({
    String? query,
    LegalCategory? category,
  }) async {
    if (supabase.auth.currentUser == null) return [];
    var q = supabase.from('legal_templates').select();
    if (category != null && category != LegalCategory.all) {
      q = q.eq('category', category.name);
    }
    final res = await q.order('category').order('title');
    var list = (res as List).map((e) => LegalTemplateModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
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
    if (supabase.auth.currentUser == null) return null;
    final res =
        await supabase.from('legal_templates').select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return LegalTemplateModel.fromJson(res);
  }

  /// Документы текущего пользователя.
  Future<List<LegalDocumentModel>> fetchMyDocuments() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];
    logSupabaseRequest(
        table: 'legal_documents', operation: 'select', userId: userId);
    final res = await supabase
        .from('legal_documents')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (res as List).map((e) => LegalDocumentModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Создаёт запись документа. Возвращает созданный документ с id.
  Future<LegalDocumentModel> createDocumentRecord({
    required LegalTemplateModel template,
    required Map<String, String> payload,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');
    final payloadMap = payload.map((k, v) => MapEntry(k, v));
    final data = {
      'user_id': userId,
      'template_id': template.id,
      'template_version': template.version ?? 1,
      'title': template.title,
      'payload': payloadMap,
      'status': 'generated',
    };
    logSupabaseRequest(
        table: 'legal_documents', operation: 'insert', payload: data, userId: userId);
    final res = await supabase
        .from('legal_documents')
        .insert(data)
        .select()
        .single();
    debugPrint('[LegalRepository] createDocumentRecord documentId=${res['id']}');
    return LegalDocumentModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Загружает PDF в storage. Путь: {userId}/{documentId}.pdf
  Future<String> uploadPdf(String userId, String documentId, Uint8List bytes) async {
    final path = '$userId/$documentId.pdf';
    logSupabaseRequest(
        table: 'storage', operation: 'upload', payload: {'path': path}, userId: userId);
    await supabase.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'application/pdf'),
        );
    debugPrint('[LegalRepository] uploadPdf path=$path');
    return path;
  }

  Future<void> updateDocumentPdfPath(String documentId, String path) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await supabase.from('legal_documents').update({'file_pdf_path': path}).eq('id', documentId).eq('user_id', userId);
    debugPrint('[LegalRepository] updateDocumentPdfPath documentId=$documentId path=$path');
  }

  /// Signed URL для PDF. path = userId/documentId.pdf (без documents/).
  Future<String?> signedPdfUrl(String path, {int expiresIn = 3600}) async {
    try {
      final url =
          await supabase.storage.from(_bucket).createSignedUrl(path, expiresIn);
      debugPrint('[LegalRepository] signedPdfUrl path=$path ok');
      return url;
    } catch (e) {
      debugPrint('[LegalRepository] signedPdfUrl error: $e');
      return null;
    }
  }
}
