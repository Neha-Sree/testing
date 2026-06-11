import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'services/mom_api_service.dart';

/// Pills adherence history for the mother.
///
/// Pulls `/mothers/{patient_id}/pill-history?days=N` and renders:
/// - a hero stat card with overall adherence + counters
/// - one expandable card per day that has activity
/// - a single empty state when there are no prescriptions in the window
class MotherPillsHistoryScreen extends StatefulWidget {
  const MotherPillsHistoryScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<MotherPillsHistoryScreen> createState() =>
      _MotherPillsHistoryScreenState();
}

class _MotherPillsHistoryScreenState extends State<MotherPillsHistoryScreen> {
  final MomApiService _api = MomApiService();
  late Future<Map<String, dynamic>> _historyFuture;
  int _windowDays = 30;

  @override
  void initState() {
    super.initState();
    _historyFuture = _api.fetchPillHistory(widget.patientId, days: _windowDays);
  }

  void _reload(int days) {
    setState(() {
      _windowDays = days;
      _historyFuture = _api.fetchPillHistory(widget.patientId, days: days);
    });
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFFE91E63);
    const surface = Color(0xFFFFF6F9);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: const Text('Pills History'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Window',
            initialValue: _windowDays,
            onSelected: _reload,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7, child: Text('Last 7 days')),
              PopupMenuItem(value: 14, child: Text('Last 14 days')),
              PopupMenuItem(value: 30, child: Text('Last 30 days')),
              PopupMenuItem(value: 60, child: Text('Last 60 days')),
              PopupMenuItem(value: 90, child: Text('Last 90 days')),
            ],
            icon: const Icon(Icons.calendar_today),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => _reload(_windowDays),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: themeColor),
            );
          }
          if (snapshot.hasError) {
            return _errorState(snapshot.error);
          }
          final envelope = snapshot.data;
          if (envelope == null) return _emptyState(themeColor, hint: 'No data yet.');
          final days = (envelope['days'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>();
          final prescriptionCount = envelope['prescription_count'] as int?;
          final activeDays =
              days.where((d) => (d['items'] as List).isNotEmpty).toList();
          final totalTaken = (envelope['total_taken'] as int?) ?? 0;
          final totalMissed = (envelope['total_missed'] as int?) ?? 0;
          final adherence =
              (envelope['window_adherence_pct'] as int?) ?? 0;

          return RefreshIndicator(
            color: themeColor,
            onRefresh: () async => _reload(_windowDays),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _heroStats(
                  themeColor,
                  adherence: adherence,
                  taken: totalTaken,
                  missed: totalMissed,
                ),
                const SizedBox(height: 16),
                if (prescriptionCount == 0)
                  _emptyState(
                    themeColor,
                    icon: Icons.local_pharmacy_outlined,
                    title: 'No prescriptions yet',
                    hint:
                        'Your doctor hasn\'t prescribed any pills. Once they do, your daily adherence will appear here.',
                  )
                else if (activeDays.isEmpty)
                  _emptyState(
                    themeColor,
                    icon: Icons.history_toggle_off,
                    title: 'No activity in the last $_windowDays days',
                    hint:
                        'Try a longer window from the calendar icon, or start logging pills as you take them.',
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
                    child: Text(
                      'Activity (${activeDays.length} ${activeDays.length == 1 ? "day" : "days"})',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...activeDays.map((day) => _dayCard(day, themeColor)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _errorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Couldn\'t load history',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _reload(_windowDays),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(
    Color themeColor, {
    IconData icon = Icons.history,
    String title = 'Nothing here yet',
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: themeColor, size: 56),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroStats(
    Color themeColor, {
    required int adherence,
    required int taken,
    required int missed,
  }) {
    final goodColor = adherence >= 80
        ? const Color(0xFF43A047)
        : (adherence >= 50 ? const Color(0xFFFB8C00) : const Color(0xFFE53935));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [themeColor, themeColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last $_windowDays days',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$adherence% adherence',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _pillStat('Taken', taken, Icons.check_circle, Colors.white),
                    const SizedBox(width: 10),
                    _pillStat('Missed', missed, Icons.cancel, Colors.white),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: CircularProgressIndicator(
                    value: adherence / 100,
                    strokeWidth: 9,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$adherence%',
                    style: TextStyle(
                      color: goodColor.computeLuminance() < 0.4
                          ? Colors.white
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

  Widget _pillStat(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            '$label $value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(Map<String, dynamic> day, Color themeColor) {
    final dateStr = day['date'] as String?;
    final items = (day['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final taken = (day['taken'] as int?) ?? 0;
    final missed = (day['missed'] as int?) ?? 0;
    final activeCount =
        (day['active_count'] as int?) ?? (taken + missed);
    final adherence = (day['adherence_pct'] as int?) ?? 0;
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

    final now = DateTime.now();
    final isToday = date != null &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final isYesterday = date != null &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1;
    final headline = date == null
        ? (dateStr ?? '')
        : isToday
            ? 'Today'
            : isYesterday
                ? 'Yesterday'
                : DateFormat('EEE, MMM d').format(date);

    final badgeColor = missed == 0 && taken > 0
        ? const Color(0xFF43A047)
        : (adherence >= 50 ? const Color(0xFFFB8C00) : const Color(0xFFE53935));
    final badgeLabel = activeCount == 0
        ? 'logged'
        : '$adherence%';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              date != null ? DateFormat('d').format(date) : '?',
              style: TextStyle(
                color: themeColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                if (taken > 0)
                  _miniChip('Taken $taken', const Color(0xFF43A047)),
                if (missed > 0) ...[
                  if (taken > 0) const SizedBox(width: 6),
                  _miniChip('Missed $missed', const Color(0xFFE53935)),
                ],
              ],
            ),
          ),
          children: items
              .map((item) => _itemRow(item, themeColor))
              .toList(),
        ),
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item, Color themeColor) {
    final taken = item['taken'] as bool? ?? false;
    final inRange = item['in_range'] as bool? ?? true;
    final name = item['pill_name'] as String? ?? 'Medicine';
    final dosage = item['dosage'] as String? ?? '';
    final mealTime = item['meal_time'] as String? ?? '';
    final timing = item['timing'] as String? ?? '';

    final color = taken
        ? const Color(0xFF43A047)
        : (inRange ? const Color(0xFFE53935) : Colors.grey.shade500);
    final label = taken
        ? 'Taken'
        : (inRange ? 'Missed' : 'Out of range');
    final icon = taken
        ? Icons.check_circle
        : (inRange ? Icons.cancel : Icons.remove_circle_outline);

    final subtitleParts = <String>[
      if (dosage.isNotEmpty) dosage,
      if (mealTime.isNotEmpty) _formatMealTime(mealTime),
      if (timing.isNotEmpty) timing.replaceAll('_', ' '),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (subtitleParts.isNotEmpty)
                  Text(
                    subtitleParts.join(' · '),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatMealTime(String raw) {
    switch (raw.toLowerCase()) {
      case 'breakfast':
        return 'Breakfast';
      case 'mid_morning':
        return 'Mid-morning';
      case 'lunch':
        return 'Lunch';
      case 'evening':
      case 'evening_snack':
        return 'Evening';
      case 'dinner':
        return 'Dinner';
      case 'bedtime':
        return 'Bedtime';
      default:
        return raw.replaceAll('_', ' ');
    }
  }
}
