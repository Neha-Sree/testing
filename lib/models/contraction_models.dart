class ContractionSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final List<ContractionPhase> phases;
  final int totalContractionSeconds;
  final int totalRelaxationSeconds;
  final int lapCount;
  final String notes;

  ContractionSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.phases,
    required this.totalContractionSeconds,
    required this.totalRelaxationSeconds,
    required this.lapCount,
    this.notes = '',
  });

  factory ContractionSession.fromJson(Map<String, dynamic> json) {
    return ContractionSession(
      id: json['id'] ?? '',
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      phases: (json['phases'] as List?)
          ?.map((phase) => ContractionPhase.fromJson(phase))
          .toList() ?? [],
      totalContractionSeconds: json['totalContractionSeconds'] ?? 0,
      totalRelaxationSeconds: json['totalRelaxationSeconds'] ?? 0,
      lapCount: json['lapCount'] ?? 0,
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'phases': phases.map((phase) => phase.toJson()).toList(),
      'totalContractionSeconds': totalContractionSeconds,
      'totalRelaxationSeconds': totalRelaxationSeconds,
      'lapCount': lapCount,
      'notes': notes,
    };
  }

  Duration get totalDuration => endTime.difference(startTime);
  String get formattedDuration => _formatDuration(totalDuration);
  String get averageContractionDuration => phases.isEmpty ? '0:00' : 
    _formatDuration(Duration(seconds: totalContractionSeconds ~/ phases.length));
  String get averageRelaxationDuration => phases.isEmpty ? '0:00' : 
    _formatDuration(Duration(seconds: totalRelaxationSeconds ~/ phases.length));

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
  String get formattedDuration => ContractionSession._formatDuration(
    Duration(seconds: duration)
  );
}

enum PhaseType {
  contraction,
  relaxation,
}
