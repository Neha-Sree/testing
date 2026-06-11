import 'package:flutter/material.dart';

import 'article_detail_screen.dart';
import 'models/education_models.dart';
import 'services/education_api_service.dart';

/// Searchable FAQ list combined with the rule-based "AI assistant".
///
/// Top half: a chat-style ask box. Bottom half: curated FAQ list with category
/// filters that updates on search. Emergency-level questions are highlighted
/// with a red banner urging the mother to contact her doctor.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key, required this.patientId});
  final String patientId;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  static const _palette = _FaqPalette();

  final EducationApiService _api = EducationApiService();
  final TextEditingController _askController = TextEditingController();

  Future<List<Faq>>? _faqFuture;
  FaqAskResult? _askResult;
  bool _asking = false;
  String? _selectedCategory;

  static const _categories = <(String, String?)>[
    ('All', null),
    ('Symptoms', 'symptoms'),
    ('Diet', 'diet'),
    ('Exercise', 'exercise'),
    ('Baby', 'baby_development'),
    ('Emergency', 'emergency'),
    ('Mind', 'mental_health'),
  ];

  @override
  void initState() {
    super.initState();
    _reloadFaqs();
  }

  @override
  void dispose() {
    _askController.dispose();
    super.dispose();
  }

  void _reloadFaqs() {
    setState(() {
      _faqFuture = _api.listFaqs(
        category: _selectedCategory,
        limit: 100,
      );
    });
  }

  Future<void> _ask() async {
    final q = _askController.text.trim();
    if (q.isEmpty || _asking) return;
    setState(() {
      _asking = true;
      _askResult = null;
    });
    try {
      final res = await _api.ask(question: q, patientId: widget.patientId);
      if (!mounted) return;
      setState(() => _askResult = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  void _openArticle(Article a) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(
          articleId: a.id,
          patientId: widget.patientId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _palette.background,
      appBar: AppBar(
        backgroundColor: _palette.background,
        foregroundColor: _palette.textDark,
        elevation: 0,
        title: const Text('Ask & Learn',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildAskBox(),
          if (_askResult != null) ...[
            const SizedBox(height: 16),
            _buildAskResult(_askResult!),
          ],
          const SizedBox(height: 24),
          Text(
            'Browse FAQs',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _palette.textDark,
            ),
          ),
          const SizedBox(height: 10),
          _buildCategoryChips(),
          const SizedBox(height: 16),
          _buildFaqList(),
        ],
      ),
    );
  }

  // ---- ask box ----

  Widget _buildAskBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent, color: _palette.teal),
              const SizedBox(width: 8),
              Text(
                'Ask a pregnancy question',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _palette.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'I will match your question with doctor-reviewed answers.',
            style: TextStyle(fontSize: 12.5, color: _palette.textMute),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _askController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'e.g. Can I drink coffee in the morning?',
              filled: true,
              fillColor: _palette.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _palette.primary, width: 1.4),
              ),
            ),
            onSubmitted: (_) => _ask(),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _asking ? null : _ask,
              icon: _asking
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Ask'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _palette.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAskResult(FaqAskResult res) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (res.emergency)
          _EmergencyBanner(message: res.fallbackMessage, palette: _palette)
        else if (res.warning)
          _WarningBanner(palette: _palette),
        if (res.fallbackMessage != null && !res.emergency) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _palette.lavender,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              res.fallbackMessage!,
              style: TextStyle(color: _palette.textDark),
            ),
          ),
        ],
        if (res.matches.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final m in res.matches)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FaqCard(faq: m, palette: _palette),
            ),
        ],
        if (res.relatedArticles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Related articles',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _palette.textDark,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 6),
          for (final a in res.relatedArticles)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RelatedArticleRow(
                article: a,
                palette: _palette,
                onTap: () => _openArticle(a),
              ),
            ),
        ],
      ],
    );
  }

  // ---- categories ----

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, value) = _categories[i];
          final selected = value == _selectedCategory;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) {
              setState(() => _selectedCategory = value);
              _reloadFaqs();
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

  Widget _buildFaqList() {
    return FutureBuilder<List<Faq>>(
      future: _faqFuture,
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
              'Failed to load: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }
        final faqs = snap.data ?? const <Faq>[];
        if (faqs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No FAQs match this filter.',
              style: TextStyle(color: _palette.textMute),
            ),
          );
        }
        return Column(
          children: [
            for (final f in faqs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FaqCard(faq: f, palette: _palette),
              ),
          ],
        );
      },
    );
  }
}

class _FaqCard extends StatefulWidget {
  const _FaqCard({required this.faq, required this.palette});
  final Faq faq;
  final _FaqPalette palette;
  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  Color _severityColor() {
    switch (widget.faq.severity) {
      case 'emergency':
        return widget.palette.danger;
      case 'warning':
        return widget.palette.warning;
      default:
        return widget.palette.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: widget.palette.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 22,
                    margin: const EdgeInsets.only(top: 2, right: 10),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.faq.question,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: widget.palette.textDark,
                        height: 1.35,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _expanded ? 0.5 : 0,
                    child: Icon(Icons.keyboard_arrow_down, color: widget.palette.textMute),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState:
                    _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    widget.faq.answerMarkdown,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: widget.palette.textDark,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner({required this.message, required this.palette});
  final String? message;
  final _FaqPalette palette;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.danger.withValues(alpha: 0.1),
        border: Border.all(color: palette.danger),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.emergency_share, color: palette.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This sounds urgent',
                  style: TextStyle(
                    color: palette.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message ?? 'Please contact your doctor or go to the nearest hospital immediately.',
                  style: TextStyle(color: palette.textDark, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.palette});
  final _FaqPalette palette;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.1),
        border: Border.all(color: palette.warning),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: palette.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'If symptoms get worse, do mention this to your doctor.',
              style: TextStyle(color: palette.textDark, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedArticleRow extends StatelessWidget {
  const _RelatedArticleRow({
    required this.article,
    required this.palette,
    required this.onTap,
  });
  final Article article;
  final _FaqPalette palette;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, color: palette.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  article.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: palette.textDark,
                    fontSize: 13.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

class _FaqPalette {
  const _FaqPalette();
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
