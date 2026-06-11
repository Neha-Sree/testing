import 'package:flutter/material.dart';

import 'article_detail_screen.dart';
import 'baby_vaccination_tracker_screen.dart';
import 'bookmarks_screen.dart';
import 'faq_screen.dart';
import 'models/education_models.dart';
import 'services/education_api_service.dart';
import 'postpartum_care_screen.dart';
import 'services/mom_api_service.dart';
import 'theme/mom_ui.dart';

/// Mother-facing "Pregnancy Learning Center".
///
/// Hub layout, top to bottom:
///
/// 1.  Reading-streak chip + "Bookmarks" / "Ask AI" quick actions
/// 2.  Today's personalised pregnancy tip card
/// 3.  Recommended articles (personalised by trimester + medical conditions)
/// 4.  Category chip filters (trimester / nutrition / exercise / emergency /
///     mental_health / baby_dev)
/// 5.  Searchable article list
class LearningCenterScreen extends StatefulWidget {
  const LearningCenterScreen({
    super.key,
    required this.patientId,
    this.embedded = false,
  });

  final String patientId;
  /// When true, omits the outer [Scaffold] app bar (for use inside [IndexedStack] on the mother dashboard).
  final bool embedded;

  @override
  State<LearningCenterScreen> createState() => _LearningCenterScreenState();
}

class _LearningCenterScreenState extends State<LearningCenterScreen> {
  static const _palette = _LearnPalette();

  final EducationApiService _api = EducationApiService();
  final MomApiService _momApi = MomApiService();

  Future<TodaysTipPayload>? _tipFuture;
  Future<RecommendedArticles>? _recommendedFuture;
  Future<ReadingStreak>? _streakFuture;
  Future<List<Article>>? _articlesFuture;
  Future<Map<String, dynamic>?>? _newbornFuture;

  String? _selectedCategory;

  static const _categories = <_CategoryDef>[
    _CategoryDef('All', null, Icons.menu_book_rounded),
    _CategoryDef('Trimester', 'trimester', Icons.pregnant_woman),
    _CategoryDef('Nutrition', 'nutrition', Icons.restaurant_menu),
    _CategoryDef('Exercise', 'exercise', Icons.self_improvement),
    _CategoryDef('Emergency', 'emergency', Icons.emergency_outlined),
    _CategoryDef('Mind', 'mental_health', Icons.spa),
    _CategoryDef('Baby', 'baby_dev', Icons.child_care),
  ];

  @override
  void initState() {
    super.initState();
    _newbornFuture = _loadNewborn();
    _refreshAll();
  }

  Future<Map<String, dynamic>?> _loadNewborn() async {
    try {
      return await _momApi.getMotherNewborn(widget.patientId);
    } catch (_) {
      return null;
    }
  }

  void _refreshAll() {
    setState(() {
      _tipFuture = _api.getTodaysTip(widget.patientId);
      _recommendedFuture = _api.getRecommended(widget.patientId, limit: 6);
      _streakFuture = _api.getStreak(widget.patientId);
      _articlesFuture = _api.listArticles(
        category: _selectedCategory,
        limit: 50,
      );
    });
  }

  void _reloadArticlesOnly() {
    setState(() {
      _articlesFuture = _api.listArticles(
        category: _selectedCategory,
        limit: 50,
      );
    });
  }

  Future<void> _openArticle(Article article) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(
          articleId: article.id,
          patientId: widget.patientId,
        ),
      ),
    );
    if (mounted) {
      // Streak/progress might have changed; refresh just the streak.
      setState(() => _streakFuture = _api.getStreak(widget.patientId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      color: _palette.primary,
      onRefresh: () async {
        _newbornFuture = _loadNewborn();
        await _newbornFuture;
        _refreshAll();
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, widget.embedded ? 12 : 8, 16, 32),
        children: [
          if (widget.embedded)
            MomUi.embeddedHeader(icon: Icons.menu_book_rounded, title: 'Articles'),
          _buildDeliveryAwareBundle(),
          const SizedBox(height: 16),
          _buildStreakAndQuickActions(),
          const SizedBox(height: 16),
          _buildTodayTip(),
          const SizedBox(height: 24),
          _buildSectionHeading('Recommended for you'),
          const SizedBox(height: 12),
          _buildRecommended(),
          const SizedBox(height: 24),
          _buildSectionHeading('Browse by category'),
          const SizedBox(height: 12),
          _buildCategoryChips(),
          const SizedBox(height: 16),
          _buildArticlesList(),
        ],
      ),
    );

    if (widget.embedded) {
      return ColoredBox(color: _palette.background, child: body);
    }

    return Scaffold(
      backgroundColor: _palette.background,
      appBar: AppBar(
        backgroundColor: _palette.background,
        foregroundColor: _palette.textDark,
        elevation: 0,
        title: const Text(
          'Pregnancy Learning Center',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Bookmarks',
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BookmarksScreen(patientId: widget.patientId),
              ),
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  // ------------------------------------------------------------- streak

  Widget _buildStreakAndQuickActions() {
    return FutureBuilder<ReadingStreak>(
      future: _streakFuture,
      builder: (context, snap) {
        final streak = snap.data;
        return Row(
          children: [
            Expanded(
              child: _GlassCard(
                gradient: LinearGradient(
                  colors: [_palette.primary.withValues(alpha: 0.9), _palette.accent],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${streak?.streakDays ?? 0}-day reading streak',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${streak?.articlesCompleted ?? 0} articles completed',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _QuickActionButton(
              icon: Icons.question_answer_outlined,
              label: 'Ask AI',
              color: _palette.teal,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FaqScreen(patientId: widget.patientId),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------------- today's tip

  Widget _buildTodayTip() {
    return FutureBuilder<TodaysTipPayload>(
      future: _tipFuture,
      builder: (context, snap) {
        final tip = snap.data?.tip;
        if (snap.connectionState == ConnectionState.waiting) {
          return _GlassCard(
            color: Colors.white,
            child: const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
          );
        }
        if (tip == null) {
          return _GlassCard(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No tip available yet. Pull down to refresh.',
                style: TextStyle(color: _palette.textMute),
              ),
            ),
          );
        }
        return _GlassCard(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_palette.lavender, Colors.white],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _palette.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wb_sunny_outlined, color: _palette.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Today's tip",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _palette.textDark,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (snap.data?.trimester != null)
                          _TinyTag(label: 'Trimester ${snap.data!.trimester}', color: _palette.primary),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tip.tipText,
                      style: TextStyle(
                        fontSize: 15.5,
                        color: _palette.textDark,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ----------------------------------------------------- recommended (horizontal)

  Widget _buildRecommended() {
    return FutureBuilder<RecommendedArticles>(
      future: _recommendedFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || snap.data == null || snap.data!.articles.isEmpty) {
          return _GlassCard(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                snap.hasError
                    ? 'Could not load recommendations.\n${snap.error}'
                    : 'No personalised recommendations yet.',
                style: TextStyle(color: _palette.textMute),
              ),
            ),
          );
        }
        final rec = snap.data!;
        return SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: rec.articles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _RecommendedCard(
              article: rec.articles[i],
              palette: _palette,
              onTap: () => _openArticle(rec.articles[i]),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- categories

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = cat.value == _selectedCategory;
          return ChoiceChip(
            avatar: Icon(
              cat.icon,
              size: 16,
              color: selected ? Colors.white : _palette.textDark,
            ),
            label: Text(cat.label),
            selected: selected,
            onSelected: (_) {
              setState(() => _selectedCategory = cat.value);
              _reloadArticlesOnly();
            },
            backgroundColor: Colors.white,
            selectedColor: _palette.primary,
            labelStyle: TextStyle(
              color: selected ? Colors.white : _palette.textDark,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _palette.border),
            ),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------- article list

  Widget _buildArticlesList() {
    return FutureBuilder<List<Article>>(
      future: _articlesFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Failed to load articles: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }
        final articles = snap.data ?? const <Article>[];
        if (articles.isEmpty) {
          return _GlassCard(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No articles match this filter.',
                style: TextStyle(color: _palette.textMute),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final a in articles)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ArticleRow(
                  article: a,
                  palette: _palette,
                  onTap: () => _openArticle(a),
                ),
              ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------- helpers

  Widget _buildSectionHeading(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: _palette.textDark,
        ),
      ),
    );
  }

  Widget _buildDeliveryAwareBundle() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _newbornFuture,
      builder: (context, snap) {
        final newborn = snap.data;
        if (newborn == null || newborn.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeading('Baby & postpartum articles'),
            const SizedBox(height: 12),
            _PostDeliveryCard(
              title: 'Newborn care basics',
              summary: 'Feeding, diaper counts, sleep, and when to call the doctor.',
              icon: Icons.crib,
              color: _palette.teal,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PostpartumCareScreen(patientId: widget.patientId),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _PostDeliveryCard(
              title: 'Baby vaccine checklist',
              summary: 'Month-by-month immunization checklist you can tick and save.',
              icon: Icons.vaccines,
              color: _palette.primary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BabyVaccinationTrackerScreen(patientId: widget.patientId),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _PostDeliveryCard(
              title: 'Postpartum mood and depression warning signs',
              summary: 'Mood check, warning symptoms, and helpline guidance.',
              icon: Icons.favorite,
              color: _palette.danger,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PostpartumCareScreen(patientId: widget.patientId),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Small private widgets
// ---------------------------------------------------------------------------

class _CategoryDef {
  const _CategoryDef(this.label, this.value, this.icon);
  final String label;
  final String? value;
  final IconData icon;
}

class _LearnPalette {
  const _LearnPalette();
  Color get background => const Color(0xFFFCF7FB);
  Color get primary => const Color(0xFFE91E63);
  Color get accent => const Color(0xFFFF8A80);
  Color get lavender => const Color(0xFFEFE3F7);
  Color get teal => const Color(0xFF26A69A);
  Color get textDark => const Color(0xFF3E2F4F);
  Color get textMute => const Color(0xFF7C6F8A);
  Color get border => const Color(0xFFEADBE7);
  Color get warning => const Color(0xFFFFA000);
  Color get danger => const Color(0xFFE53935);
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({this.color, this.gradient, required this.child});
  final Color? color;
  final Gradient? gradient;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3E2F4F).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostDeliveryCard extends StatelessWidget {
  const _PostDeliveryCard({
    required this.title,
    required this.summary,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String summary;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const palette = _LearnPalette();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: palette.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      style: TextStyle(color: palette.textMute, height: 1.35),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.textMute),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  const _RecommendedCard({
    required this.article,
    required this.palette,
    required this.onTap,
  });
  final Article article;
  final _LearnPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isEmergency = article.severity == 'emergency';
    final isWarning = article.severity == 'warning';
    return SizedBox(
      width: 260,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TinyTag(
                      label: article.category.replaceAll('_', ' '),
                      color: palette.primary,
                    ),
                    const SizedBox(width: 6),
                    if (article.trimester != null)
                      _TinyTag(label: 'T${article.trimester}', color: palette.teal),
                    const Spacer(),
                    if (isEmergency)
                      Icon(Icons.warning_amber_rounded, color: palette.danger, size: 18)
                    else if (isWarning)
                      Icon(Icons.info_outline, color: palette.warning, size: 18),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.textDark,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                if (article.summary != null)
                  Expanded(
                    child: Text(
                      article.summary!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.textMute,
                        height: 1.35,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 13, color: palette.textMute),
                    const SizedBox(width: 4),
                    Text(
                      '${article.readingTimeMin} min',
                      style: TextStyle(fontSize: 11.5, color: palette.textMute),
                    ),
                    const Spacer(),
                    if (article.doctorApproved)
                      Row(
                        children: [
                          Icon(Icons.verified, size: 14, color: palette.teal),
                          const SizedBox(width: 2),
                          Text(
                            'Doctor reviewed',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleRow extends StatelessWidget {
  const _ArticleRow({
    required this.article,
    required this.palette,
    required this.onTap,
  });
  final Article article;
  final _LearnPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isEmergency = article.severity == 'emergency';
    final isWarning = article.severity == 'warning';
    final accent = isEmergency
        ? palette.danger
        : isWarning
            ? palette.warning
            : palette.primary;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconFor(article.category), color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textDark,
                        height: 1.3,
                      ),
                    ),
                    if (article.summary != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        article.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: palette.textMute,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 12, color: palette.textMute),
                        const SizedBox(width: 3),
                        Text(
                          '${article.readingTimeMin} min',
                          style: TextStyle(fontSize: 11, color: palette.textMute),
                        ),
                        const SizedBox(width: 10),
                        _TinyTag(
                          label: article.category.replaceAll('_', ' '),
                          color: palette.teal,
                        ),
                        if (article.trimester != null) ...[
                          const SizedBox(width: 6),
                          _TinyTag(label: 'T${article.trimester}', color: palette.primary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: palette.textMute),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'trimester':
        return Icons.pregnant_woman;
      case 'nutrition':
        return Icons.restaurant_menu;
      case 'exercise':
        return Icons.self_improvement;
      case 'emergency':
        return Icons.emergency_outlined;
      case 'mental_health':
        return Icons.spa;
      case 'baby_dev':
        return Icons.child_care;
      default:
        return Icons.menu_book_rounded;
    }
  }
}
