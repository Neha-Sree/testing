import 'package:flutter/material.dart';

class HydrationLog {
  final String id;
  final DateTime date;
  final double waterMl;
  final double goalMl;

  HydrationLog({
    required this.id,
    required this.date,
    required this.waterMl,
    required this.goalMl,
  });

  factory HydrationLog.fromJson(Map<String, dynamic> json) {
    return HydrationLog(
      id: json['id'] ?? '',
      date: DateTime.parse(json['date']),
      waterMl: (json['waterMl'] ?? 0.0).toDouble(),
      goalMl: (json['goalMl'] ?? 2500.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'waterMl': waterMl,
      'goalMl': goalMl,
    };
  }

  double get progress => (waterMl / goalMl).clamp(0.0, 1.0);
  String get waterLiters => (waterMl / 1000).toStringAsFixed(1);
  String get goalLiters => (goalMl / 1000).toStringAsFixed(1);
}

class HydrationReminder {
  final String id;
  final String title;
  final TimeOfDay time;
  final List<int> weekdays; // 1-7 (Monday-Sunday)
  final bool isEnabled;

  HydrationReminder({
    required this.id,
    required this.title,
    required this.time,
    required this.weekdays,
    this.isEnabled = true,
  });

  factory HydrationReminder.fromJson(Map<String, dynamic> json) {
    return HydrationReminder(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      time: TimeOfDay(hour: json['hour'] ?? 9, minute: json['minute'] ?? 0),
      weekdays:
          (json['weekdays'] as List?)?.map((e) => e as int).toList() ??
          [1, 2, 3, 4, 5],
      isEnabled: json['isEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'hour': time.hour,
      'minute': time.minute,
      'weekdays': weekdays,
      'isEnabled': isEnabled,
    };
  }
}
