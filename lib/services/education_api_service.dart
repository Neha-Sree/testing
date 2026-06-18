import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/education_models.dart';
import 'auth_session_service.dart';
import 'mom_api_base_url.dart';

class EducationApiException implements Exception {
  EducationApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Thin REST client for the `/education/*` backend.
class EducationApiService {
  EducationApiService({http.Client? client}) : _client = client ?? AuthenticatedClient();

  final http.Client _client;

  static String get _baseUrl => momApiBaseUrl();

  // --------- Articles ---------

  Future<List<Article>> listArticles({
    String? category,
    int? trimester,
    String? query,
    String? severity,
    bool onlyApproved = true,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'only_approved': onlyApproved.toString(),
    };
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (trimester != null) params['trimester'] = '$trimester';
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (severity != null) params['severity'] = severity;
    final uri = Uri.parse('$_baseUrl/education/articles').replace(queryParameters: params);
    return _listGet(uri, Article.fromJson);
  }

  Future<Article> getArticle(int articleId) async {
    final uri = Uri.parse('$_baseUrl/education/articles/$articleId');
    final res = await _client.get(uri);
    _ensureOk(res);
    return Article.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> approveArticle({
    required int articleId,
    required String doctorId,
  }) async {
    final uri = Uri.parse('$_baseUrl/education/articles/$articleId/approve');
    final res = await _client.post(
      uri,
      body: {'doctor_id': doctorId.trim().toUpperCase()},
    );
    _ensureOk(res);
  }

  Future<RecommendedArticles> getRecommended(String patientId, {int limit = 8}) async {
    final uri = Uri.parse('$_baseUrl/education/articles/recommended/$patientId')
        .replace(queryParameters: {'limit': '$limit'});
    final res = await _client.get(uri);
    _ensureOk(res);
    return RecommendedArticles.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> toggleBookmark({
    required int articleId,
    required String userId,
  }) async {
    final uri = Uri.parse('$_baseUrl/education/articles/$articleId/bookmark');
    final res = await _client.post(uri, body: {'user_id': userId});
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Article>> listBookmarks(String userId) async {
    final uri = Uri.parse('$_baseUrl/education/bookmarks/$userId');
    return _listGet(uri, Article.fromJson);
  }

  Future<Map<String, dynamic>> saveProgress({
    required String userId,
    required int articleId,
    required int progressPct,
  }) async {
    final uri = Uri.parse('$_baseUrl/education/progress');
    final res = await _client.post(uri, body: {
      'user_id': userId,
      'article_id': '$articleId',
      'progress_pct': '$progressPct',
    });
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<ReadingStreak> getStreak(String userId) async {
    final uri = Uri.parse('$_baseUrl/education/streak/$userId');
    final res = await _client.get(uri);
    _ensureOk(res);
    return ReadingStreak.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // --------- FAQs ---------

  Future<List<Faq>> listFaqs({String? category, String? query, int limit = 50}) async {
    final params = <String, String>{'limit': '$limit'};
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (query != null && query.isNotEmpty) params['q'] = query;
    final uri = Uri.parse('$_baseUrl/education/faqs').replace(queryParameters: params);
    return _listGet(uri, Faq.fromJson);
  }

  Future<FaqAskResult> ask({required String question, String? patientId}) async {
    final uri = Uri.parse('$_baseUrl/education/ask');
    final body = <String, String>{'question': question};
    if (patientId != null && patientId.isNotEmpty) body['patient_id'] = patientId;
    final res = await _client.post(uri, body: body);
    _ensureOk(res);
    return FaqAskResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // --------- Daily tip ---------

  Future<TodaysTipPayload> getTodaysTip(String patientId) async {
    final uri = Uri.parse('$_baseUrl/education/tips/today/$patientId');
    final res = await _client.get(uri);
    _ensureOk(res);
    return TodaysTipPayload.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // --------- Helpers ---------

  Future<List<T>> _listGet<T>(Uri uri, T Function(Map<String, dynamic>) fromJson) async {
    final res = await _client.get(uri);
    _ensureOk(res);
    final data = jsonDecode(res.body);
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
  }

  void _ensureOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw EducationApiException(
        'HTTP ${res.statusCode}: ${res.body}',
        statusCode: res.statusCode,
      );
    }
  }
}
