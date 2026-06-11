import 'dart:async';

import 'package:flutter/material.dart';

import 'models/education_models.dart';
import 'services/education_api_service.dart';

/// Article reader with:
///
/// - Reading-progress tracker (debounced save to backend at intervals)
/// - Bookmark toggle in the app bar
/// - Severity banner (warning/emergency) at the top of the body
/// - "Key takeaways" callout
/// - Doctor-reviewed / source-attribution footer
class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({
    super.key,
    required this.articleId,
    required this.patientId,
  });

  final int articleId;
  final String patientId;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final EducationApiService _api = EducationApiService();
  final ScrollController _scroll = ScrollController();

  Future<Article>? _articleFuture;
  Article? _article;
  bool _bookmarked = false;
  bool _bookmarkBusy = false;
  int _progressPct = 0;
  int _lastSavedProgress = 0;
  Timer? _progressDebounce;

  @override
  void initState() {
    super.initState();
    _articleFuture = _load();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _progressDebounce?.cancel();
    // Flush final progress synchronously-ish.
    if (_progressPct > _lastSavedProgress) {
      _api
          .saveProgress(
            userId: widget.patientId,
            articleId: widget.articleId,
            progressPct: _progressPct,
          )
          .catchError((_) => <String, dynamic>{});
    }
    super.dispose();
  }

  Future<Article> _load() async {
    final article = await _api.getArticle(widget.articleId);
    final bookmarks = await _api.listBookmarks(widget.patientId);
    if (mounted) {
      setState(() {
        _article = article;
        _bookmarked = bookmarks.any((a) => a.id == article.id);
      });
    }
    return article;
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    final fraction = (_scroll.offset / max).clamp(0.0, 1.0);
    final next = (fraction * 100).round();
    if (next > _progressPct) {
      setState(() => _progressPct = next);
      _scheduleProgressSave();
    }
  }

  void _scheduleProgressSave() {
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(milliseconds: 1200), () {
      _flushProgress();
    });
  }

  Future<void> _flushProgress() async {
    if (_progressPct <= _lastSavedProgress) return;
    final value = _progressPct;
    try {
      await _api.saveProgress(
        userId: widget.patientId,
        articleId: widget.articleId,
        progressPct: value,
      );
      _lastSavedProgress = value;
    } catch (_) {
      // Soft-fail; the dispose-time flush gets one more shot.
    }
  }

  Future<void> _toggleBookmark() async {
    if (_bookmarkBusy || _article == null) return;
    setState(() => _bookmarkBusy = true);
    try {
      final res = await _api.toggleBookmark(
        articleId: _article!.id,
        userId: widget.patientId,
      );
      final bookmarked = res['bookmarked'] as bool? ?? !_bookmarked;
      if (!mounted) return;
      setState(() => _bookmarked = bookmarked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bookmarked ? 'Bookmarked' : 'Removed from bookmarks'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update bookmark: $e')),
      );
    } finally {
      if (mounted) setState(() => _bookmarkBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const palette = _LearnPalette();
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.textDark,
        elevation: 0,
        title: Text(
          _article?.title ?? 'Article',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: _bookmarked ? 'Remove bookmark' : 'Bookmark',
            icon: _bookmarkBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_bookmarked ? Icons.bookmark : Icons.bookmark_outline),
            onPressed: _toggleBookmark,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: _progressPct / 100,
            backgroundColor: palette.lavender,
            valueColor: AlwaysStoppedAnimation(palette.primary),
            minHeight: 3,
          ),
        ),
      ),
      body: FutureBuilder<Article>(
        future: _articleFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Failed to load: ${snap.error}',
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final article = snap.data!;
          return ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              _buildHeader(article, palette),
              const SizedBox(height: 16),
              if (article.severity != 'info')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _SeverityBanner(severity: article.severity, palette: palette),
                ),
              if (article.keyTakeaways.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _TakeawaysCard(takeaways: article.keyTakeaways, palette: palette),
                ),
              _MarkdownBody(
                source: article.bodyMarkdown ?? article.summary ?? '',
                palette: palette,
              ),
              const SizedBox(height: 24),
              _AttributionFooter(article: article, palette: palette),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(Article article, _LearnPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _TinyTag(label: article.category.replaceAll('_', ' '), color: palette.primary),
            if (article.trimester != null)
              _TinyTag(label: 'Trimester ${article.trimester}', color: palette.teal),
            if (article.doctorApproved)
              _TinyTag(label: 'Doctor reviewed', color: palette.teal),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          article.title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: palette.textDark,
            height: 1.25,
          ),
        ),
        if (article.summary != null) ...[
          const SizedBox(height: 6),
          Text(
            article.summary!,
            style: TextStyle(
              fontSize: 14,
              color: palette.textMute,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.schedule, size: 14, color: palette.textMute),
            const SizedBox(width: 4),
            Text(
              '${article.readingTimeMin} min read',
              style: TextStyle(fontSize: 12, color: palette.textMute),
            ),
            const SizedBox(width: 12),
            Icon(Icons.remove_red_eye_outlined, size: 14, color: palette.textMute),
            const SizedBox(width: 4),
            Text(
              '${article.viewCount} views',
              style: TextStyle(fontSize: 12, color: palette.textMute),
            ),
          ],
        ),
      ],
    );
  }
}

class _SeverityBanner extends StatelessWidget {
  const _SeverityBanner({required this.severity, required this.palette});
  final String severity;
  final _LearnPalette palette;
  @override
  Widget build(BuildContext context) {
    final isEmergency = severity == 'emergency';
    final color = isEmergency ? palette.danger : palette.warning;
    final title = isEmergency
        ? 'Emergency awareness'
        : 'Read with care';
    final message = isEmergency
        ? 'This article covers signs that need urgent medical attention. '
          'If you have any of these symptoms, contact your doctor or go to '
          'the nearest hospital right away.'
        : 'This article includes warning signs. If you notice any of them, '
          'mention it to your doctor at your next visit.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isEmergency ? Icons.emergency_share : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: palette.textDark,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TakeawaysCard extends StatelessWidget {
  const _TakeawaysCard({required this.takeaways, required this.palette});
  final List<String> takeaways;
  final _LearnPalette palette;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.lavender,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_outlined, color: palette.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                'Key takeaways',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: palette.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final t in takeaways)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: palette.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: palette.textDark,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AttributionFooter extends StatelessWidget {
  const _AttributionFooter({required this.article, required this.palette});
  final Article article;
  final _LearnPalette palette;
  @override
  Widget build(BuildContext context) {
    final source = article.sourceAttribution;
    if (source == null && !article.doctorApproved) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: palette.teal, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (article.doctorApproved)
                  Text(
                    'Reviewed for the platform.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: palette.textDark,
                    ),
                  ),
                if (source != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    source,
                    style: TextStyle(fontSize: 12, color: palette.textMute, height: 1.35),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'This article is educational. It does not replace advice from your doctor.',
                  style: TextStyle(fontSize: 11.5, color: palette.textMute, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small, dependency-free Markdown-ish renderer.
///
/// Supports: `##`/`###` headings, `>` block quotes, `-` bullet lists and
/// numbered lists, and `**bold**` inline emphasis. Not a full markdown
/// implementation — kept intentionally tiny so we don't pull in another
/// package just for article bodies.
class _MarkdownBody extends StatelessWidget {
  const _MarkdownBody({required this.source, required this.palette});
  final String source;
  final _LearnPalette palette;

  @override
  Widget build(BuildContext context) {
    final lines = source.split('\n');
    final widgets = <Widget>[];
    final buffer = StringBuffer();

    void flushParagraph() {
      final text = buffer.toString().trim();
      buffer.clear();
      if (text.isEmpty) return;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _RichTextLine(line: text, palette: palette, baseSize: 14.5),
      ));
    }

    for (var raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        flushParagraph();
        continue;
      }
      if (line.startsWith('### ')) {
        flushParagraph();
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            line.substring(4),
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: palette.textDark,
            ),
          ),
        ));
      } else if (line.startsWith('## ')) {
        flushParagraph();
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Text(
            line.substring(3),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: palette.textDark,
            ),
          ),
        ));
      } else if (line.startsWith('> ')) {
        flushParagraph();
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.lavender,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote, color: palette.primary, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: _RichTextLine(
                    line: line.substring(2),
                    palette: palette,
                    baseSize: 13.5,
                    italic: true,
                  ),
                ),
              ],
            ),
          ),
        ));
      } else if (line.startsWith('- ')) {
        flushParagraph();
        widgets.add(_BulletItem(text: line.substring(2), palette: palette));
      } else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        flushParagraph();
        final match = RegExp(r'^(\d+)\.\s(.*)').firstMatch(line)!;
        widgets.add(_NumberedItem(
          number: match.group(1)!,
          text: match.group(2) ?? '',
          palette: palette,
        ));
      } else if (line.startsWith('|') && line.endsWith('|')) {
        // Lightweight table: render rows as plain mono-style text.
        flushParagraph();
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            line,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              color: palette.textDark,
            ),
          ),
        ));
      } else {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(line);
      }
    }
    flushParagraph();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text, required this.palette});
  final String text;
  final _LearnPalette palette;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: palette.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: _RichTextLine(line: text, palette: palette, baseSize: 14.5)),
        ],
      ),
    );
  }
}

class _NumberedItem extends StatelessWidget {
  const _NumberedItem({
    required this.number,
    required this.text,
    required this.palette,
  });
  final String number;
  final String text;
  final _LearnPalette palette;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 8),
            child: Text(
              '$number.',
              style: TextStyle(
                color: palette.primary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(child: _RichTextLine(line: text, palette: palette, baseSize: 14.5)),
        ],
      ),
    );
  }
}

class _RichTextLine extends StatelessWidget {
  const _RichTextLine({
    required this.line,
    required this.palette,
    required this.baseSize,
    this.italic = false,
  });

  final String line;
  final _LearnPalette palette;
  final double baseSize;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    int cursor = 0;
    for (final match in pattern.allMatches(line)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: line.substring(cursor, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1) ?? '',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ));
      cursor = match.end;
    }
    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor)));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: line));
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: baseSize,
          height: 1.55,
          color: palette.textDark,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
        children: spans,
      ),
    );
  }
}

// Local palette duplicated to keep this file self-contained.
class _LearnPalette {
  const _LearnPalette();
  Color get background => const Color(0xFFFCF7FB);
  Color get primary => const Color(0xFFE91E63);
  Color get lavender => const Color(0xFFEFE3F7);
  Color get teal => const Color(0xFF26A69A);
  Color get textDark => const Color(0xFF3E2F4F);
  Color get textMute => const Color(0xFF7C6F8A);
  Color get border => const Color(0xFFEADBE7);
  Color get warning => const Color(0xFFFFA000);
  Color get danger => const Color(0xFFE53935);
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
