import 'package:flutter/material.dart';

import 'services/mom_api_service.dart';

/// Today's personalised diet plan view for the mother.
///
/// Backed by `/diet/plan/today/{patient_id}` and `/diet/plan/complete-meal`.
/// Mothers can:
/// - See each of the 6 meal slots with name, portion, calories and tags
/// - Tap a meal to expand the full description
/// - Mark a meal as completed (mark-eaten)
/// - See today's nutrition score and water goal
/// - Force regenerate the plan
class MotherDietScreen extends StatefulWidget {
  const MotherDietScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<MotherDietScreen> createState() => _MotherDietScreenState();
}

class _MotherDietScreenState extends State<MotherDietScreen> {
  static const _slotOrder = <String>[
    'breakfast',
    'mid_morning',
    'lunch',
    'evening_snack',
    'dinner',
    'bedtime',
  ];

  static const _slotLabels = <String, String>{
    'breakfast': 'Breakfast',
    'mid_morning': 'Mid-morning snack',
    'lunch': 'Lunch',
    'evening_snack': 'Evening snack',
    'dinner': 'Dinner',
    'bedtime': 'Bedtime',
  };

  static const _slotIcons = <String, IconData>{
    'breakfast': Icons.wb_sunny,
    'mid_morning': Icons.local_cafe,
    'lunch': Icons.lunch_dining,
    'evening_snack': Icons.cookie,
    'dinner': Icons.dinner_dining,
    'bedtime': Icons.bedtime,
  };

  final MomApiService _api = MomApiService();
  late Future<Map<String, dynamic>> _planFuture;
  Map<String, dynamic>? _aiPlan;
  bool _aiPlanLoading = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _planFuture = _api.fetchTodayDietPlan(widget.patientId);
    _loadSavedAiPlan();
  }

  Future<void> _loadSavedAiPlan() async {
    setState(() => _aiPlanLoading = true);
    try {
      final plan = await _api.fetchLatestAiDietAssistantPlan(widget.patientId);
      if (mounted) setState(() => _aiPlan = plan);
    } catch (_) {
      // Non-fatal — user can tap Generate.
    } finally {
      if (mounted) setState(() => _aiPlanLoading = false);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _planFuture = _api.fetchTodayDietPlan(widget.patientId);
    });
    await _loadSavedAiPlan();
  }

  Future<void> _regenerate() async {
    setState(() => _busy = true);
    try {
      await _api.regenerateDietPlan(widget.patientId);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fresh plan generated for today.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to regenerate: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateAiPlan({String? dislikeFeedback}) async {
    setState(() {
      _busy = true;
      _aiPlanLoading = true;
    });
    try {
      final plan = await _api.generateAiDietAssistantPlan(
        widget.patientId,
        dislikeFeedback: dislikeFeedback,
      );
      if (!mounted) return;
      setState(() => _aiPlan = plan);
      final source = (plan['source'] as String?) ?? '';
      final message = (plan['message'] as String?) ??
          (source == 'gemini'
              ? 'Gemini diet assistant updated your plan.'
              : 'Showing safe rule-based pregnancy diet plan.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on MomApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate AI plan: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not generate AI plan. Check backend is running and try again. ($e)',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _aiPlanLoading = false;
        });
      }
    }
  }

  Future<void> _regenerateAiPlanWithFeedback() async {
    final controller = TextEditingController();
    final feedback = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Get a new AI plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tell us what you did not like (foods, taste, portion size, etc.). '
              'We will generate a different plan for your trimester, blood levels, and allergies.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. too much rice, want more protein, vegetarian only',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Generate new plan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (feedback == null || feedback.isEmpty) return;
    await _generateAiPlan(dislikeFeedback: feedback);
  }

  Future<void> _toggleMeal({
    required int planId,
    required String slot,
    required bool currentlyCompleted,
  }) async {
    setState(() => _busy = true);
    try {
      await _api.markMealComplete(
        planId: planId,
        slot: slot,
        completed: !currentlyCompleted,
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update meal: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF26A69A);
    const surface = Color(0xFFF6FBF9);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: const Text('Today\'s Diet Plan'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Regenerate today\'s plan',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _regenerate,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _planFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primary),
            );
          }
          if (snapshot.hasError) {
            return _buildError(snapshot.error);
          }
          final plan = snapshot.data;
          if (plan == null) {
            return const Center(child: Text('No plan yet'));
          }
          return RefreshIndicator(
            onRefresh: _reload,
            color: primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildAiAssistantSection(primary),
                const SizedBox(height: 16),
                _buildSummaryCard(plan, primary),
                const SizedBox(height: 12),
                if (plan['rationale'] != null &&
                    (plan['rationale'] as String).trim().isNotEmpty)
                  _buildRationaleCard(plan['rationale'] as String, primary),
                const SizedBox(height: 16),
                ..._slotOrder.map((slot) {
                  final meals = plan['meals'] as Map<String, dynamic>? ?? {};
                  final meal = meals[slot] as Map<String, dynamic>?;
                  return _buildMealCard(
                    slot: slot,
                    meal: meal ?? const {'name': '—'},
                    planId: plan['id'] as int,
                    primary: primary,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.grey, size: 48),
            const SizedBox(height: 12),
            Text(
              'Could not load your plan.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _reload, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> plan, Color primary) {
    final score = (plan['score'] is Map)
        ? (plan['score']['score'] as num?)?.toInt() ?? 0
        : 0;
    final calories = (plan['daily_calories'] as num?)?.toInt() ?? 0;
    final iron = (plan['daily_iron_mg'] as num?)?.toDouble() ?? 0;
    final calcium = (plan['daily_calcium_mg'] as num?)?.toDouble() ?? 0;
    final water = (plan['water_goal_ml'] as num?)?.toInt() ?? 2500;
    final trimester = plan['trimester'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trimester != null ? 'Trimester $trimester' : 'Pregnancy',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const Spacer(),
              const Icon(Icons.restaurant_menu, color: Colors.white, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Nutrition score: $score / 100',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat('Cal', '$calories', Icons.local_fire_department),
              _miniStat('Iron', '${iron.toStringAsFixed(1)}mg', Icons.bolt),
              _miniStat('Ca', '${calcium.toStringAsFixed(0)}mg', Icons.spa),
              _miniStat(
                'Water',
                '${(water / 1000).toStringAsFixed(1)}L',
                Icons.water_drop,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiAssistantSection(Color primary) {
    final plan = _aiPlan;
    return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primary.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primary.withValues(alpha: 0.12),
                    child: Icon(Icons.auto_awesome, color: primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gemini AI Diet Assistant',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Based on latest health-worker data and doctor restrictions.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Educational support only. For urgent symptoms or diet restrictions, contact your doctor.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_busy || _aiPlanLoading) ? null : _generateAiPlan,
                  icon: _aiPlanLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.psychology),
                  label: Text(
                    _aiPlanLoading
                        ? 'Generating plan (may take up to 1 min)...'
                        : 'Generate AI diet plan',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              if (plan != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _regenerateAiPlanWithFeedback,
                    icon: const Icon(Icons.refresh),
                    label: const Text('I do not like this plan — get another'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
              if (plan == null && !_aiPlanLoading) ...[
                const SizedBox(height: 10),
                Text(
                  'Tap Generate to create a personalised plan from your trimester, labs, and allergies.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
              if (plan != null) ...[
                const SizedBox(height: 14),
                _buildAiSourceBanner(plan, primary),
                const SizedBox(height: 10),
                ..._slotOrder.map((slot) {
                  final meals = _stringMap(plan['meals']);
                  final meal = _stringMap(meals[slot]);
                  return _buildAiMealRow(slot, meal, primary);
                }),
                _buildAiInfoList(
                  title: 'Hydration',
                  icon: Icons.water_drop,
                  values: [(plan['hydration_recommendation'] as String?) ?? ''],
                  primary: primary,
                ),
                _buildAiInfoList(
                  title: 'Warnings',
                  icon: Icons.warning_amber,
                  values: _stringList(plan['warnings']),
                  primary: primary,
                ),
                _buildAiInfoList(
                  title: 'Questions for doctor',
                  icon: Icons.medical_information,
                  values: _stringList(plan['questions_for_doctor']),
                  primary: primary,
                ),
              ],
            ],
          ),
        );
  }

  Widget _buildAiSourceBanner(Map<String, dynamic> plan, Color primary) {
    final source = (plan['source'] as String?) ?? '';
    final fallbackMessage =
        (plan['message'] as String?) ??
        'AI key not configured; showing safe rule-based pregnancy diet plan.';
    final generatedAt = plan['generated_at'] as String?;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: source == 'gemini'
            ? primary.withValues(alpha: 0.08)
            : Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            source == 'gemini' ? Icons.auto_awesome : Icons.shield,
            color: source == 'gemini' ? primary : Colors.orange.shade700,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              source == 'gemini'
                  ? 'Gemini plan generated${generatedAt != null ? ' at ${_formatDateTime(generatedAt)}' : ''}.'
                  : fallbackMessage,
              style: TextStyle(
                color: source == 'gemini' ? primary : Colors.orange.shade900,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiMealRow(
    String slot,
    Map<String, dynamic> meal,
    Color primary,
  ) {
    if (meal.isEmpty) return const SizedBox.shrink();
    final nutrients = _stringList(meal['nutrients_focus']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCFA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _slotIcons[slot] ?? Icons.restaurant,
                color: primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _slotLabels[slot] ?? slot,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (meal['calories'] != null)
                Text(
                  '${meal['calories']} kcal',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            (meal['name'] as String?) ?? 'Suggested meal',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if ((meal['portion'] as String?)?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                meal['portion'] as String,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ),
          if ((meal['rationale'] as String?)?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                meal['rationale'] as String,
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          if (nutrients.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final nutrient in nutrients)
                  Chip(
                    label: Text(nutrient),
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(color: primary, fontSize: 11),
                    backgroundColor: primary.withValues(alpha: 0.08),
                    side: BorderSide.none,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiInfoList({
    required String title,
    required IconData icon,
    required List<String> values,
    required Color primary,
  }) {
    final cleanValues = values.where((v) => v.trim().isNotEmpty).toList();
    if (cleanValues.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primary, size: 18),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ...cleanValues.map(
            (value) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $value',
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRationaleCard(String rationale, Color primary) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates, color: primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rationale,
              style: TextStyle(color: primary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard({
    required String slot,
    required Map<String, dynamic> meal,
    required int planId,
    required Color primary,
  }) {
    final completed = meal['completed'] as bool? ?? false;
    final name = (meal['name'] as String?) ?? '—';
    final description = meal['description'] as String?;
    final portion = meal['portion'] as String?;
    final calories = meal['calories'];
    final tags = (meal['tags'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: completed
              ? primary.withValues(alpha: 0.6)
              : Colors.grey.shade200,
          width: completed ? 1.5 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            backgroundColor: primary.withValues(alpha: 0.12),
            child: Icon(
              _slotIcons[slot] ?? Icons.restaurant,
              color: primary,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  _slotLabels[slot] ?? slot,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (calories != null)
                Text(
                  '$calories kcal',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                color: completed ? Colors.grey : Colors.black87,
                decoration: completed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          trailing: IconButton(
            tooltip: completed ? 'Mark as not eaten' : 'Mark as eaten',
            icon: Icon(
              completed ? Icons.check_circle : Icons.radio_button_unchecked,
              color: completed ? primary : Colors.grey.shade400,
              size: 28,
            ),
            onPressed: _busy
                ? null
                : () => _toggleMeal(
                    planId: planId,
                    slot: slot,
                    currentlyCompleted: completed,
                  ),
          ),
          children: [
            if (portion != null && portion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.straighten,
                      color: Colors.grey.shade500,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      portion,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            if (description != null && description.isNotEmpty)
              Text(
                description,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        t.replaceAll('_', ' '),
                        style: TextStyle(color: primary, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _stringMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value == null) return const [];
    return [value.toString()];
  }

  String _formatDateTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return raw;
    }
  }
}
