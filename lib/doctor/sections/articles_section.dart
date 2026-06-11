import 'package:flutter/material.dart';

import '../../models/education_models.dart';
import '../../services/education_api_service.dart';
import '../doctor_theme.dart';

class ArticlesSection extends StatefulWidget {
  const ArticlesSection({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<ArticlesSection> createState() => _ArticlesSectionState();
}

class _ArticlesSectionState extends State<ArticlesSection> {
  final _edu = EducationApiService();
  List<Article> _articles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _edu.listArticles(onlyApproved: false, limit: 80);
      if (mounted) {
        setState(() {
          _articles = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _articles.length,
        itemBuilder: (context, i) {
          final a = _articles[i];
          return ListTile(
            title: Text(a.title),
            subtitle: Text('${a.category} · approved=${a.doctorApproved}'),
            trailing: a.doctorApproved
                ? const Icon(
                    Icons.check_circle,
                    color: DoctorTheme.healthyGreen,
                  )
                : TextButton(
                    onPressed: () async {
                      try {
                        await _edu.approveArticle(
                          articleId: a.id,
                          doctorId: widget.doctorId,
                        );
                        await _load();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
                    child: const Text('Approve'),
                  ),
          );
        },
      ),
    );
  }
}
