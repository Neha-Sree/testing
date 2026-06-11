import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum MissedNotificationType { sleep, pill, hydration, appointment }

class MissedNotificationItem {
  MissedNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.missedAt,
    this.dismissed = false,
  });

  final String id;
  final MissedNotificationType type;
  final String title;
  final String body;
  final DateTime missedAt;
  final bool dismissed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'missed_at': missedAt.toIso8601String(),
        'dismissed': dismissed,
      };

  factory MissedNotificationItem.fromJson(Map<String, dynamic> json) {
    return MissedNotificationItem(
      id: '${json['id']}',
      type: MissedNotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MissedNotificationType.sleep,
      ),
      title: '${json['title']}',
      body: '${json['body']}',
      missedAt: DateTime.parse('${json['missed_at']}'),
      dismissed: json['dismissed'] == true,
    );
  }

  MissedNotificationItem copyWith({bool? dismissed}) {
    return MissedNotificationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      missedAt: missedAt,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}

class MissedNotificationsStore {
  MissedNotificationsStore._();
  static final MissedNotificationsStore instance = MissedNotificationsStore._();

  String _key(String patientId) => 'missed_notifications_${patientId.trim().toUpperCase()}';

  Future<List<MissedNotificationItem>> load(String patientId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(patientId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => MissedNotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MissedNotificationItem>> loadActive(String patientId) async {
    final all = await load(patientId);
    return all.where((n) => !n.dismissed).toList()
      ..sort((a, b) => b.missedAt.compareTo(a.missedAt));
  }

  Future<int> activeCount(String patientId) async {
    return (await loadActive(patientId)).length;
  }

  Future<void> _save(String patientId, List<MissedNotificationItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(patientId),
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addIfMissing({
    required String patientId,
    required String id,
    required MissedNotificationType type,
    required String title,
    required String body,
    required DateTime missedAt,
  }) async {
    final items = await load(patientId);
    if (items.any((n) => n.id == id)) return;
    items.add(
      MissedNotificationItem(
        id: id,
        type: type,
        title: title,
        body: body,
        missedAt: missedAt,
      ),
    );
    await _save(patientId, items);
  }

  Future<void> dismiss(String patientId, String id) async {
    final items = await load(patientId);
    final updated = items
        .map((n) => n.id == id ? n.copyWith(dismissed: true) : n)
        .toList();
    await _save(patientId, updated);
  }

  Future<void> dismissAll(String patientId) async {
    final items = await load(patientId);
    final updated = items.map((n) => n.copyWith(dismissed: true)).toList();
    await _save(patientId, updated);
  }
}
