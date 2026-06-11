class DietLog {
  final String id;
  final DateTime date;
  final MealType mealType;
  final List<FoodItem> foodItems;
  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final String notes;

  DietLog({
    required this.id,
    required this.date,
    required this.mealType,
    required this.foodItems,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    this.notes = '',
  });

  factory DietLog.fromJson(Map<String, dynamic> json) {
    return DietLog(
      id: json['id'] ?? '',
      date: DateTime.parse(json['date']),
      mealType: MealType.values.firstWhere(
        (e) => e.toString() == 'MealType.${json['mealType']}',
        orElse: () => MealType.breakfast,
      ),
      foodItems: (json['foodItems'] as List?)
          ?.map((item) => FoodItem.fromJson(item))
          .toList() ?? [],
      totalCalories: json['totalCalories'] ?? 0,
      totalProtein: (json['totalProtein'] ?? 0.0).toDouble(),
      totalCarbs: (json['totalCarbs'] ?? 0.0).toDouble(),
      totalFat: (json['totalFat'] ?? 0.0).toDouble(),
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'mealType': mealType.toString().split('.').last,
      'foodItems': foodItems.map((item) => item.toJson()).toList(),
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalCarbs': totalCarbs,
      'totalFat': totalFat,
      'notes': notes,
    };
  }

  DietLog copyWith({
    String? id,
    DateTime? date,
    MealType? mealType,
    List<FoodItem>? foodItems,
    int? totalCalories,
    double? totalProtein,
    double? totalCarbs,
    double? totalFat,
    String? notes,
  }) {
    return DietLog(
      id: id ?? this.id,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      foodItems: foodItems ?? this.foodItems,
      totalCalories: totalCalories ?? this.totalCalories,
      totalProtein: totalProtein ?? this.totalProtein,
      totalCarbs: totalCarbs ?? this.totalCarbs,
      totalFat: totalFat ?? this.totalFat,
      notes: notes ?? this.notes,
    );
  }
}

class FoodItem {
  final String id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double quantity;
  final String unit;

  FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.quantity,
    required this.unit,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      calories: json['calories'] ?? 0,
      protein: (json['protein'] ?? 0.0).toDouble(),
      carbs: (json['carbs'] ?? 0.0).toDouble(),
      fat: (json['fat'] ?? 0.0).toDouble(),
      quantity: (json['quantity'] ?? 0.0).toDouble(),
      unit: json['unit'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'quantity': quantity,
      'unit': unit,
    };
  }
}

enum MealType {
  breakfast,
  lunch,
  dinner,
  snacks,
}

class DailyNutritionGoals {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  DailyNutritionGoals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  static DailyNutritionGoals get defaultGoals => DailyNutritionGoals(
    calories: 2000,
    protein: 50.0,
    carbs: 250.0,
    fat: 65.0,
  );
}
