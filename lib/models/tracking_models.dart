import 'package:flutter/material.dart';

// SYMPTOMS MODELS
class SymptomLog {
  final String id;
  final String motherId;
  final DateTime date;
  final List<Symptom> symptoms;
  final String? notes;
  final bool hasAlertedDoctor;

  SymptomLog({
    required this.id,
    required this.motherId,
    required this.date,
    required this.symptoms,
    this.notes,
    this.hasAlertedDoctor = false,
  });

  factory SymptomLog.fromJson(Map<String, dynamic> json) {
    return SymptomLog(
      id: json['id'] ?? '',
      motherId: json['motherId'] ?? '',
      date: DateTime.parse(json['date']),
      symptoms:
          (json['symptoms'] as List?)
              ?.map((s) => Symptom.fromJson(s))
              .toList() ??
          [],
      notes: json['notes'],
      hasAlertedDoctor: json['hasAlertedDoctor'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'motherId': motherId,
      'date': date.toIso8601String(),
      'symptoms': symptoms.map((s) => s.toJson()).toList(),
      'notes': notes,
      'hasAlertedDoctor': hasAlertedDoctor,
    };
  }

  bool get hasCriticalSymptoms => symptoms.any((s) => s.isCritical);
  List<Symptom> get criticalSymptoms =>
      symptoms.where((s) => s.isCritical).toList();
}

class Symptom {
  final SymptomType type;
  final Severity severity;
  final DateTime startTime;
  final DateTime? endTime;
  final String? description;

  Symptom({
    required this.type,
    required this.severity,
    required this.startTime,
    this.endTime,
    this.description,
  });

  factory Symptom.fromJson(Map<String, dynamic> json) {
    return Symptom(
      type: SymptomType.values.firstWhere(
        (e) => e.toString() == 'SymptomType.${json['type']}',
        orElse: () => SymptomType.other,
      ),
      severity: Severity.values.firstWhere(
        (e) => e.toString() == 'Severity.${json['severity']}',
        orElse: () => Severity.mild,
      ),
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'severity': severity.toString().split('.').last,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'description': description,
    };
  }

  bool get isCritical =>
      type.criticalSeverity && severity.index >= Severity.moderate.index;
  Duration? get duration =>
      endTime?.difference(startTime);
}

enum SymptomType {
  bleeding(false, 'Bleeding'),
  pain(true, 'Pain'),
  dizziness(true, 'Dizziness'),
  swelling(false, 'Swelling'),
  headache(false, 'Headache'),
  nausea(false, 'Nausea'),
  vomiting(true, 'Vomiting'),
  fever(true, 'Fever'),
  reducedMovement(true, 'Reduced Baby Movement'),
  contractions(true, 'Contractions'),
  discharge(false, 'Discharge'),
  other(false, 'Other');

  const SymptomType(this.criticalSeverity, this.displayName);
  final bool criticalSeverity;
  final String displayName;
}

enum Severity {
  mild('Mild', 1),
  moderate('Moderate', 2),
  severe('Severe', 3);

  const Severity(this.displayName, this.level);
  final String displayName;
  final int level;
}

// MEDICINE MODELS
class Medicine {
  final String id;
  final String motherId;
  final String name;
  final String dosage;
  final String frequency;
  final List<TimeOfDay> times;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final String? notes;

  Medicine({
    required this.id,
    required this.motherId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.notes,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] ?? '',
      motherId: json['motherId'] ?? '',
      name: json['name'] ?? '',
      dosage: json['dosage'] ?? '',
      frequency: json['frequency'] ?? '',
      times:
          (json['times'] as List?)
              ?.map(
                (t) =>
                    TimeOfDay(hour: t['hour'] ?? 0, minute: t['minute'] ?? 0),
              )
              .toList() ??
          [],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      isActive: json['isActive'] ?? true,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'motherId': motherId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'times': times.map((t) => {'hour': t.hour, 'minute': t.minute}).toList(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive,
      'notes': notes,
    };
  }
}

class MedicineLog {
  final String id;
  final String medicineId;
  final String motherId;
  final DateTime dateTime;
  final MedicineStatus status;
  final String? notes;

  MedicineLog({
    required this.id,
    required this.medicineId,
    required this.motherId,
    required this.dateTime,
    required this.status,
    this.notes,
  });

  factory MedicineLog.fromJson(Map<String, dynamic> json) {
    return MedicineLog(
      id: json['id'] ?? '',
      medicineId: json['medicineId'] ?? '',
      motherId: json['motherId'] ?? '',
      dateTime: DateTime.parse(json['dateTime']),
      status: MedicineStatus.values.firstWhere(
        (e) => e.toString() == 'MedicineStatus.${json['status']}',
        orElse: () => MedicineStatus.taken,
      ),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicineId': medicineId,
      'motherId': motherId,
      'dateTime': dateTime.toIso8601String(),
      'status': status.toString().split('.').last,
      'notes': notes,
    };
  }
}

enum MedicineStatus { taken, missed, skipped }

// CONTRACTION MODELS
class ContractionSession {
  final String id;
  final String motherId;
  final DateTime startTime;
  final DateTime endTime;
  final List<ContractionPhase> phases;
  final int totalContractionSeconds;
  final int totalRelaxationSeconds;
  final int lapCount;
  final String? notes;

  ContractionSession({
    required this.id,
    required this.motherId,
    required this.startTime,
    required this.endTime,
    required this.phases,
    required this.totalContractionSeconds,
    required this.totalRelaxationSeconds,
    required this.lapCount,
    this.notes,
  });

  factory ContractionSession.fromJson(Map<String, dynamic> json) {
    return ContractionSession(
      id: json['id'] ?? '',
      motherId: json['motherId'] ?? '',
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      phases:
          (json['phases'] as List?)
              ?.map((p) => ContractionPhase.fromJson(p))
              .toList() ??
          [],
      totalContractionSeconds: json['totalContractionSeconds'] ?? 0,
      totalRelaxationSeconds: json['totalRelaxationSeconds'] ?? 0,
      lapCount: json['lapCount'] ?? 0,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'motherId': motherId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'phases': phases.map((p) => p.toJson()).toList(),
      'totalContractionSeconds': totalContractionSeconds,
      'totalRelaxationSeconds': totalRelaxationSeconds,
      'lapCount': lapCount,
      'notes': notes,
    };
  }

  Duration get totalDuration => endTime.difference(startTime);
  String get formattedDuration => _formatDuration(totalDuration);
  String get averageContractionDuration => phases.isEmpty
      ? '0:00'
      : _formatDuration(
          Duration(seconds: totalContractionSeconds ~/ phases.length),
        );
  String get averageRelaxationDuration => phases.isEmpty
      ? '0:00'
      : _formatDuration(
          Duration(seconds: totalRelaxationSeconds ~/ phases.length),
        );

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class ContractionPhase {
  final DateTime startTime;
  final DateTime endTime;
  final PhaseType type;

  ContractionPhase({
    required this.startTime,
    required this.endTime,
    required this.type,
  });

  factory ContractionPhase.fromJson(Map<String, dynamic> json) {
    return ContractionPhase(
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      type: PhaseType.values.firstWhere(
        (e) => e.toString() == 'PhaseType.${json['type']}',
        orElse: () => PhaseType.contraction,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'type': type.toString().split('.').last,
    };
  }

  int get duration => endTime.difference(startTime).inSeconds;
  String get formattedDuration =>
      ContractionSession._formatDuration(Duration(seconds: duration));
}

enum PhaseType { contraction, relaxation }

// KICK COUNTER MODELS
class KickSession {
  final String id;
  final String motherId;
  final DateTime startTime;
  final DateTime endTime;
  final List<DateTime> kickTimes;
  final int totalKicks;
  final Duration sessionDuration;
  final String? notes;

  KickSession({
    required this.id,
    required this.motherId,
    required this.startTime,
    required this.endTime,
    required this.kickTimes,
    required this.totalKicks,
    required this.sessionDuration,
    this.notes,
  });

  factory KickSession.fromJson(Map<String, dynamic> json) {
    return KickSession(
      id: json['id'] ?? '',
      motherId: json['motherId'] ?? '',
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      kickTimes:
          (json['kickTimes'] as List?)
              ?.map((t) => DateTime.parse(t))
              .toList() ??
          [],
      totalKicks: json['totalKicks'] ?? 0,
      sessionDuration: Duration(seconds: json['sessionDuration'] ?? 0),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'motherId': motherId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'kickTimes': kickTimes.map((t) => t.toIso8601String()).toList(),
      'totalKicks': totalKicks,
      'sessionDuration': sessionDuration.inSeconds,
      'notes': notes,
    };
  }

  double get kicksPerHour =>
      totalKicks / (sessionDuration.inHours == 0 ? 1 : sessionDuration.inHours);
  bool get isLowMovement => kicksPerHour < 10 && sessionDuration.inHours >= 1;
}

// NOTIFICATION MODELS
class Notification {
  final String id;
  final String userId;
  final String motherId;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  Notification({
    required this.id,
    required this.userId,
    this.motherId = '',
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      motherId: json['motherId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${json['type']}',
        orElse: () => NotificationType.systemInfo,
      ),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'] ?? false,
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'motherId': motherId,
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'data': data,
    };
  }
}

enum NotificationType {
  medicineReminder,
  hydrationReminder,
  appointmentReminder,
  symptomAlert,
  criticalAlert,
  doctorMessage,
  systemInfo,
  kickReminder,
}
