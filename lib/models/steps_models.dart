class StepsLog {
  final String id;
  final DateTime date;
  final int stepsCount;
  final int goalSteps;
  final double? distanceKm;
  final int? caloriesBurned;
  final Duration? activeMinutes;

  StepsLog({
    required this.id,
    required this.date,
    required this.stepsCount,
    required this.goalSteps,
    this.distanceKm,
    this.caloriesBurned,
    this.activeMinutes,
  });

  factory StepsLog.fromJson(Map<String, dynamic> json) {
    return StepsLog(
      id: json['id'] ?? '',
      date: DateTime.parse(json['date']),
      stepsCount: json['stepsCount'] ?? 0,
      goalSteps: json['goalSteps'] ?? 10000,
      distanceKm: json['distanceKm']?.toDouble(),
      caloriesBurned: json['caloriesBurned'],
      activeMinutes: json['activeMinutes'] != null
          ? Duration(seconds: json['activeMinutes'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'stepsCount': stepsCount,
      'goalSteps': goalSteps,
      'distanceKm': distanceKm,
      'caloriesBurned': caloriesBurned,
      'activeMinutes': activeMinutes?.inSeconds,
    };
  }

  double get progress => (stepsCount / goalSteps).clamp(0.0, 1.0);
  String get stepsFormatted => stepsCount.toString().replaceAllMapped(
    RegExp(r'(?=(?:\d{3})+(?!\d))'),
    (match) => ',',
  );
  String get distanceFormatted =>
      distanceKm != null ? '${distanceKm!.toStringAsFixed(1)} km' : '-- km';
  String get caloriesFormatted =>
      caloriesBurned != null ? '${caloriesBurned!.toString()} cal' : '-- cal';
  String get activeMinutesFormatted => activeMinutes != null
      ? '${(activeMinutes!.inMinutes).toString()} min'
      : '-- min';
  int get remainingSteps => (goalSteps - stepsCount).clamp(0, goalSteps);
  bool get goalAchieved => stepsCount >= goalSteps;

  StepsLog copyWith({
    String? id,
    DateTime? date,
    int? stepsCount,
    int? goalSteps,
    double? distanceKm,
    int? caloriesBurned,
    Duration? activeMinutes,
  }) {
    return StepsLog(
      id: id ?? this.id,
      date: date ?? this.date,
      stepsCount: stepsCount ?? this.stepsCount,
      goalSteps: goalSteps ?? this.goalSteps,
      distanceKm: distanceKm ?? this.distanceKm,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      activeMinutes: activeMinutes ?? this.activeMinutes,
    );
  }
}

class StepsGoal {
  final String id;
  final int dailySteps;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;

  StepsGoal({
    required this.id,
    required this.dailySteps,
    required this.startDate,
    this.endDate,
    this.isActive = true,
  });

  factory StepsGoal.fromJson(Map<String, dynamic> json) {
    return StepsGoal(
      id: json['id'] ?? '',
      dailySteps: json['dailySteps'] ?? 10000,
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dailySteps': dailySteps,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive,
    };
  }

  static StepsGoal get defaultGoal =>
      StepsGoal(id: 'default', dailySteps: 10000, startDate: DateTime.now());
}
