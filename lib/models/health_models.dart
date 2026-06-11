// HYDRATION MODELS
class HydrationLog {
  final String id;
  final String motherId;
  final DateTime date;
  final double waterMl;
  final double dailyGoalMl;
  final String? notes;

  HydrationLog({
    required this.id,
    required this.motherId,
    required this.date,
    required this.waterMl,
    required this.dailyGoalMl,
    this.notes,
  });

  factory HydrationLog.fromJson(Map<String, dynamic> json) {
    return HydrationLog(
      id: json['id'] ?? '',
      motherId: json['motherId'] ?? '',
      date: DateTime.parse(json['date']),
      waterMl: (json['waterMl'] ?? 0.0).toDouble(),
      dailyGoalMl: (json['dailyGoalMl'] ?? 2500.0).toDouble(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'motherId': motherId,
      'date': date.toIso8601String(),
      'waterMl': waterMl,
      'dailyGoalMl': dailyGoalMl,
      'notes': notes,
    };
  }

  double get progress => (waterMl / dailyGoalMl).clamp(0.0, 1.0);
  String get waterLiters => (waterMl / 1000).toStringAsFixed(1);
  String get goalLiters => (dailyGoalMl / 1000).toStringAsFixed(1);
}

// STEPS MODELS
class StepsLog {
  final String id;
  final String motherId;
  final DateTime date;
  final int stepsCount;
  final int goalSteps;
  final double? distanceKm;
  final int? caloriesBurned;
  final Duration? activeMinutes;
  final bool isManualInput;

  StepsLog({
    required this.id,
    required this.motherId,
    required this.date,
    required this.stepsCount,
    required this.goalSteps,
    this.distanceKm,
    this.caloriesBurned,
    this.activeMinutes,
    this.isManualInput = false,
  });

  factory StepsLog.fromJson(Map<String, dynamic> json) {
    return StepsLog(
      id: json['id'] ?? '',
      motherId: json['motherId'] ?? '',
      date: DateTime.parse(json['date']),
      stepsCount: json['stepsCount'] ?? 0,
      goalSteps: json['goalSteps'] ?? 10000,
      distanceKm: json['distanceKm']?.toDouble(),
      caloriesBurned: json['caloriesBurned'],
      activeMinutes: json['activeMinutes'] != null
          ? Duration(seconds: json['activeMinutes'])
          : null,
      isManualInput: json['isManualInput'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'motherId': motherId,
      'date': date.toIso8601String(),
      'stepsCount': stepsCount,
      'goalSteps': goalSteps,
      'distanceKm': distanceKm,
      'caloriesBurned': caloriesBurned,
      'activeMinutes': activeMinutes?.inSeconds,
      'isManualInput': isManualInput,
    };
  }

  double get progress => (stepsCount / goalSteps).clamp(0.0, 1.0);
  String get stepsFormatted => stepsCount.toString().replaceAllMapped(
    RegExp(r'(?=(?:\d{3})+(?!\d))'),
    (match) => ',',
  );
  bool get goalAchieved => stepsCount >= goalSteps;
  int get remainingSteps => (goalSteps - stepsCount).clamp(0, goalSteps);
  String get distanceFormatted =>
      '${distanceKm?.toStringAsFixed(1) ?? '0.0'} km';
  String get caloriesFormatted => '$caloriesBurned cal';
  String get activeMinutesFormatted => '${activeMinutes?.inMinutes ?? 0} min';

  StepsLog copyWith({
    String? id,
    String? motherId,
    DateTime? date,
    int? stepsCount,
    int? goalSteps,
    double? distanceKm,
    int? caloriesBurned,
    Duration? activeMinutes,
    bool? isManualInput,
  }) {
    return StepsLog(
      id: id ?? this.id,
      motherId: motherId ?? this.motherId,
      date: date ?? this.date,
      stepsCount: stepsCount ?? this.stepsCount,
      goalSteps: goalSteps ?? this.goalSteps,
      distanceKm: distanceKm ?? this.distanceKm,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      isManualInput: isManualInput ?? this.isManualInput,
    );
  }
}

// WEIGHT MODELS
class WeightLog {
  final String id;
  final String motherId;
  final DateTime date;
  final double weight; // in kg
  final int pregnancyWeek;
  final String? notes;
  final bool isDoctorMeasured;

  WeightLog({
    required this.id,
    required this.motherId,
    required this.date,
    required this.weight,
    required this.pregnancyWeek,
    this.notes,
    this.isDoctorMeasured = false,
  });

  factory WeightLog.fromJson(Map<String, dynamic> json) {
    return WeightLog(
      id: json['id'] ?? '',
      motherId: json['motherId'] ?? '',
      date: DateTime.parse(json['date']),
      weight: (json['weight'] ?? 0.0).toDouble(),
      pregnancyWeek: json['pregnancyWeek'] ?? 0,
      notes: json['notes'],
      isDoctorMeasured: json['isDoctorMeasured'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'motherId': motherId,
      'date': date.toIso8601String(),
      'weight': weight,
      'pregnancyWeek': pregnancyWeek,
      'notes': notes,
      'isDoctorMeasured': isDoctorMeasured,
    };
  }

  String get weightFormatted => '${weight.toStringAsFixed(1)} kg';
}

// BLOOD MODELS
class BloodLog {
  final String id;
  final String motherId;
  final DateTime date;
  final int pregnancyWeek;
  final BloodPressure bloodPressure;
  final double hemoglobin; // g/dL
  final double sugarLevel; // mg/dL
  final String? notes;
  final bool isAbnormal;

  BloodLog({
    required this.id,
    required this.motherId,
    required this.date,
    required this.pregnancyWeek,
    required this.bloodPressure,
    required this.hemoglobin,
    required this.sugarLevel,
    this.notes,
    this.isAbnormal = false,
  });

  factory BloodLog.fromJson(Map<String, dynamic> json) {
    return BloodLog(
      id: json['id'] ?? '',
      motherId: json['motherId'] ?? '',
      date: DateTime.parse(json['date']),
      pregnancyWeek: json['pregnancyWeek'] ?? 0,
      bloodPressure: BloodPressure.fromJson(json['bloodPressure'] ?? {}),
      hemoglobin: (json['hemoglobin'] ?? 0.0).toDouble(),
      sugarLevel: (json['sugarLevel'] ?? 0.0).toDouble(),
      notes: json['notes'],
      isAbnormal: json['isAbnormal'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'motherId': motherId,
      'date': date.toIso8601String(),
      'pregnancyWeek': pregnancyWeek,
      'bloodPressure': bloodPressure.toJson(),
      'hemoglobin': hemoglobin,
      'sugarLevel': sugarLevel,
      'notes': notes,
      'isAbnormal': isAbnormal,
    };
  }

  bool get hasAbnormalBP => bloodPressure.isAbnormal;
  bool get hasLowHemoglobin => hemoglobin < 11.0;
  bool get hasAbnormalSugar => sugarLevel < 70 || sugarLevel > 140;
}

class BloodPressure {
  final int systolic; // Upper value
  final int diastolic; // Lower value

  BloodPressure({required this.systolic, required this.diastolic});

  factory BloodPressure.fromJson(Map<String, dynamic> json) {
    return BloodPressure(
      systolic: json['systolic'] ?? 0,
      diastolic: json['diastolic'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'systolic': systolic, 'diastolic': diastolic};
  }

  String get formatted => '$systolic/$diastolic mmHg';
  bool get isAbnormal => systolic >= 140 || diastolic >= 90;
  bool get isLow => systolic < 90 || diastolic < 60;
}

// DIET MODELS
class DietLog {
  final String id;
  final String motherId;
  final DateTime date;
  final MealType mealType;
  final List<DietItem> items;
  final List<String> imageUrls;
  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final String? notes;

  DietLog({
    required this.id,
    required this.motherId,
    required this.date,
    required this.mealType,
    required this.items,
    this.imageUrls = const [],
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    this.notes,
  });

  factory DietLog.fromJson(Map<String, dynamic> json) {
    return DietLog(
      id: json['id'] ?? '',
      motherId: json['motherId'] ?? '',
      date: DateTime.parse(json['date']),
      mealType: MealType.values.firstWhere(
        (e) => e.toString() == 'MealType.${json['mealType']}',
        orElse: () => MealType.breakfast,
      ),
      items:
          (json['items'] as List?)
              ?.map((item) => DietItem.fromJson(item))
              .toList() ??
          [],
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      totalCalories: json['totalCalories'] ?? 0,
      totalProtein: (json['totalProtein'] ?? 0.0).toDouble(),
      totalCarbs: (json['totalCarbs'] ?? 0.0).toDouble(),
      totalFat: (json['totalFat'] ?? 0.0).toDouble(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'motherId': motherId,
      'date': date.toIso8601String(),
      'mealType': mealType.toString().split('.').last,
      'items': items.map((item) => item.toJson()).toList(),
      'imageUrls': imageUrls,
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalCarbs': totalCarbs,
      'totalFat': totalFat,
      'notes': notes,
    };
  }
}

class DietItem {
  final String name;
  final double quantity;
  final String unit;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  DietItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory DietItem.fromJson(Map<String, dynamic> json) {
    return DietItem(
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 0.0).toDouble(),
      unit: json['unit'] ?? '',
      calories: json['calories'] ?? 0,
      protein: (json['protein'] ?? 0.0).toDouble(),
      carbs: (json['carbs'] ?? 0.0).toDouble(),
      fat: (json['fat'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }
}

enum MealType { breakfast, lunch, dinner, snacks }

// APPOINTMENT MODELS
class Appointment {
  final String id;
  final String motherId;
  final String doctorId;
  final String healthWorkerId;
  final DateTime dateTime;
  final AppointmentType type;
  final AppointmentStatus status;
  final String? notes;
  final String? location;
  final bool isVirtual;

  Appointment({
    required this.id,
    required this.motherId,
    required this.doctorId,
    required this.healthWorkerId,
    required this.dateTime,
    required this.type,
    required this.status,
    this.notes,
    this.location,
    this.isVirtual = false,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] ?? '',
      motherId: json['motherId'] ?? '',
      doctorId: json['doctorId'] ?? '',
      healthWorkerId: json['healthWorkerId'] ?? '',
      dateTime: DateTime.parse(json['dateTime']),
      type: AppointmentType.values.firstWhere(
        (e) => e.toString() == 'AppointmentType.${json['type']}',
        orElse: () => AppointmentType.checkup,
      ),
      status: AppointmentStatus.values.firstWhere(
        (e) => e.toString() == 'AppointmentStatus.${json['status']}',
        orElse: () => AppointmentStatus.scheduled,
      ),
      notes: json['notes'],
      location: json['location'],
      isVirtual: json['isVirtual'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'motherId': motherId,
      'doctorId': doctorId,
      'healthWorkerId': healthWorkerId,
      'dateTime': dateTime.toIso8601String(),
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'notes': notes,
      'location': location,
      'isVirtual': isVirtual,
    };
  }

  bool get isUpcoming => dateTime.isAfter(DateTime.now());
  bool get isToday =>
      dateTime.day == DateTime.now().day &&
      dateTime.month == DateTime.now().month &&
      dateTime.year == DateTime.now().year;
}

enum AppointmentType { checkup, ultrasound, emergency, followup, consultation }

enum AppointmentStatus { scheduled, completed, cancelled, rescheduled }
