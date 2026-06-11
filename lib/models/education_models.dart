// Data models for the Pregnancy Learning Center (articles, FAQs, daily tips).
//
// Every model has a `fromJson` factory that defensively tolerates missing or
// malformed fields so a single bad backend row never crashes the UI.

class Article {
  Article({
    required this.id,
    required this.title,
    required this.summary,
    this.bodyMarkdown,
    required this.category,
    this.trimester,
    required this.severity,
    required this.doctorApproved,
    required this.readingTimeMin,
    required this.viewCount,
    required this.bookmarkCount,
    required this.tags,
    required this.conditionTags,
    required this.keyTakeaways,
    this.illustrationUrl,
    this.sourceAttribution,
    this.source,
  });

  final int id;
  final String title;
  final String? summary;
  final String? bodyMarkdown;
  final String category;
  final int? trimester;
  final String severity; // info | warning | emergency
  final bool doctorApproved;
  final int readingTimeMin;
  final int viewCount;
  final int bookmarkCount;
  final List<String> tags;
  final List<String> conditionTags;
  final List<String> keyTakeaways;
  final String? illustrationUrl;
  final String? sourceAttribution;
  final String? source;

  static List<String> _asStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
      summary: json['summary'] as String?,
      bodyMarkdown: json['body_markdown'] as String?,
      category: (json['category'] as String?) ?? 'general',
      trimester: (json['trimester'] as num?)?.toInt(),
      severity: (json['severity'] as String?) ?? 'info',
      doctorApproved: json['doctor_approved'] as bool? ?? false,
      readingTimeMin: (json['reading_time_min'] as num?)?.toInt() ?? 3,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      bookmarkCount: (json['bookmark_count'] as num?)?.toInt() ?? 0,
      tags: _asStringList(json['tags']),
      conditionTags: _asStringList(json['condition_tags']),
      keyTakeaways: _asStringList(json['key_takeaways']),
      illustrationUrl: json['illustration_url'] as String?,
      sourceAttribution: json['source_attribution'] as String?,
      source: json['source'] as String?,
    );
  }
}

class Faq {
  Faq({
    required this.id,
    required this.question,
    required this.answerMarkdown,
    required this.category,
    required this.severity,
    required this.doctorApproved,
  });

  final int id;
  final String question;
  final String answerMarkdown;
  final String category;
  final String severity;
  final bool doctorApproved;

  factory Faq.fromJson(Map<String, dynamic> json) {
    return Faq(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: (json['question'] as String?) ?? '',
      answerMarkdown: (json['answer_markdown'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'general',
      severity: (json['severity'] as String?) ?? 'info',
      doctorApproved: json['doctor_approved'] as bool? ?? false,
    );
  }
}

class DailyTip {
  DailyTip({
    required this.id,
    required this.tipText,
    this.detailMarkdown,
    this.trimester,
    required this.category,
  });

  final int id;
  final String tipText;
  final String? detailMarkdown;
  final int? trimester;
  final String category;

  factory DailyTip.fromJson(Map<String, dynamic> json) {
    return DailyTip(
      id: (json['id'] as num?)?.toInt() ?? 0,
      tipText: (json['tip_text'] as String?) ?? '',
      detailMarkdown: json['detail_markdown'] as String?,
      trimester: (json['trimester'] as num?)?.toInt(),
      category: (json['category'] as String?) ?? 'general',
    );
  }
}

class FaqAskResult {
  FaqAskResult({
    required this.question,
    required this.severity,
    required this.emergency,
    required this.warning,
    this.fallbackMessage,
    required this.matches,
    required this.relatedArticles,
  });

  final String question;
  final String severity;
  final bool emergency;
  final bool warning;
  final String? fallbackMessage;
  final List<Faq> matches;
  final List<Article> relatedArticles;

  factory FaqAskResult.fromJson(Map<String, dynamic> json) {
    final rawMatches = json['matches'];
    final rawRelated = json['related_articles'];
    return FaqAskResult(
      question: (json['question'] as String?) ?? '',
      severity: (json['severity'] as String?) ?? 'info',
      emergency: json['emergency'] as bool? ?? false,
      warning: json['warning'] as bool? ?? false,
      fallbackMessage: json['fallback_message'] as String?,
      matches: rawMatches is List
          ? rawMatches.whereType<Map<String, dynamic>>().map(Faq.fromJson).toList(growable: false)
          : const [],
      relatedArticles: rawRelated is List
          ? rawRelated.whereType<Map<String, dynamic>>().map(Article.fromJson).toList(growable: false)
          : const [],
    );
  }
}

class RecommendedArticles {
  RecommendedArticles({
    required this.patientId,
    required this.trimester,
    required this.conditions,
    required this.articles,
  });

  final String patientId;
  final int trimester;
  final List<String> conditions;
  final List<Article> articles;

  factory RecommendedArticles.fromJson(Map<String, dynamic> json) {
    final raw = json['articles'];
    final rawConditions = json['conditions'];
    return RecommendedArticles(
      patientId: (json['patient_id'] as String?) ?? '',
      trimester: (json['trimester'] as num?)?.toInt() ?? 1,
      conditions: rawConditions is List
          ? rawConditions.map((e) => e.toString()).toList(growable: false)
          : const [],
      articles: raw is List
          ? raw.whereType<Map<String, dynamic>>().map(Article.fromJson).toList(growable: false)
          : const [],
    );
  }
}

class TodaysTipPayload {
  TodaysTipPayload({this.tip, this.trimester, required this.conditions});

  final DailyTip? tip;
  final int? trimester;
  final List<String> conditions;

  factory TodaysTipPayload.fromJson(Map<String, dynamic> json) {
    final rawTip = json['tip'];
    final rawConditions = json['conditions'];
    return TodaysTipPayload(
      tip: rawTip is Map<String, dynamic> ? DailyTip.fromJson(rawTip) : null,
      trimester: (json['trimester'] as num?)?.toInt(),
      conditions: rawConditions is List
          ? rawConditions.map((e) => e.toString()).toList(growable: false)
          : const [],
    );
  }
}

class ReadingStreak {
  ReadingStreak({required this.streakDays, required this.articlesCompleted});

  final int streakDays;
  final int articlesCompleted;

  factory ReadingStreak.fromJson(Map<String, dynamic> json) {
    return ReadingStreak(
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      articlesCompleted: (json['articles_completed'] as num?)?.toInt() ?? 0,
    );
  }
}
