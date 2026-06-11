import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'services/missed_notifications_store.dart';
import 'services/reminder_coordinator.dart';
import 'theme/mom_ui.dart';

class MissedNotificationsScreen extends StatefulWidget {
  const MissedNotificationsScreen({
    super.key,
    required this.patientId,
    this.onChanged,
  });

  final String patientId;
  final VoidCallback? onChanged;

  @override
  State<MissedNotificationsScreen> createState() => _MissedNotificationsScreenState();
}

class _MissedNotificationsScreenState extends State<MissedNotificationsScreen> {
  final MissedNotificationsStore _store = MissedNotificationsStore.instance;
  List<MissedNotificationItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await ReminderCoordinator.instance.reconcileMissed(widget.patientId);
    final items = await _store.loadActive(widget.patientId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  IconData _iconFor(MissedNotificationType type) {
    switch (type) {
      case MissedNotificationType.sleep:
        return Icons.bedtime_rounded;
      case MissedNotificationType.pill:
        return Icons.medication_rounded;
      case MissedNotificationType.hydration:
        return Icons.water_drop_rounded;
      case MissedNotificationType.appointment:
        return Icons.event_busy_rounded;
    }
  }

  Color _colorFor(MissedNotificationType type) {
    switch (type) {
      case MissedNotificationType.sleep:
        return const Color(0xFF5C6BC0);
      case MissedNotificationType.pill:
        return MomUi.pink;
      case MissedNotificationType.hydration:
        return const Color(0xFF42A5F5);
      case MissedNotificationType.appointment:
        return const Color(0xFFFF7043);
    }
  }

  Future<void> _openItem(MissedNotificationItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderCoordinator.screenForType(widget.patientId, item.type),
      ),
    );
    await _load();
    widget.onChanged?.call();
  }

  Future<void> _dismiss(MissedNotificationItem item) async {
    await _store.dismiss(widget.patientId, item.id);
    await _load();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomUi.background,
      appBar: AppBar(
        title: const Text('Missed reminders'),
        backgroundColor: MomUi.surface,
        foregroundColor: MomUi.pink,
        elevation: 0,
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: () async {
                await _store.dismissAll(widget.patientId);
                await _load();
                widget.onChanged?.call();
              },
              child: const Text('Clear all'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: MomUi.pink))
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_active_outlined, size: 56, color: MomUi.pink.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'All caught up!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sleep, pills, hydration and appointment reminders will appear here if you miss them.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: MomUi.pink,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final color = _colorFor(item.type);
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openItem(item),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(_iconFor(item.type), color: color),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.body,
                                        style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        DateFormat('MMM d · h:mm a').format(item.missedAt),
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 20),
                                  color: Colors.grey.shade500,
                                  onPressed: () => _dismiss(item),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
