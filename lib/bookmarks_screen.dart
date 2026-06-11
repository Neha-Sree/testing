import 'package:flutter/material.dart';

import 'article_detail_screen.dart';
import 'models/education_models.dart';
import 'services/education_api_service.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key, required this.patientId});
  final String patientId;

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  static const _palette = _BookmarkPalette();
  final EducationApiService _api = EducationApiService();
  Future<List<Article>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = _api.listBookmarks(widget.patientId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _palette.background,
      appBar: AppBar(
        backgroundColor: _palette.background,
        foregroundColor: _palette.textDark,
        elevation: 0,
        title: const Text('Your bookmarks',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: _palette.primary,
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Article>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Could not load bookmarks: ${snap.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              );
            }
            final items = snap.data ?? const <Article>[];
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                children: [
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.bookmark_outline,
                            size: 72, color: _palette.textMute),
                        const SizedBox(height: 14),
                        Text(
                          'No bookmarks yet',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _palette.textDark,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap the bookmark icon on any article to save it for later.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _palette.textMute),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final a = items[i];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ArticleDetailScreen(
                            articleId: a.id,
                            patientId: widget.patientId,
                          ),
                        ),
                      );
                      if (mounted) _reload();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _palette.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bookmark,
                              color: _palette.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                    color: _palette.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${a.category.replaceAll('_', ' ')} \u2022 ${a.readingTimeMin} min read',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _palette.textMute,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: _palette.textMute),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BookmarkPalette {
  const _BookmarkPalette();
  Color get background => const Color(0xFFFCF7FB);
  Color get primary => const Color(0xFFE91E63);
  Color get textDark => const Color(0xFF3E2F4F);
  Color get textMute => const Color(0xFF7C6F8A);
  Color get border => const Color(0xFFEADBE7);
}
