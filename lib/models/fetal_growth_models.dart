class FetalGrowthRecord {
  final String id;
  final DateTime date;
  final int week;
  final double weight; // in grams
  final double length; // in cm
  final double heartRate; // bpm
  final String doctorNotes;
  final String ultrasoundImage; // path to image

  FetalGrowthRecord({
    required this.id,
    required this.date,
    required this.week,
    required this.weight,
    required this.length,
    required this.heartRate,
    this.doctorNotes = '',
    this.ultrasoundImage = '',
  });

  factory FetalGrowthRecord.fromJson(Map<String, dynamic> json) {
    return FetalGrowthRecord(
      id: json['id'] ?? '',
      date: DateTime.parse(json['date']),
      week: json['week'] ?? 0,
      weight: (json['weight'] ?? 0.0).toDouble(),
      length: (json['length'] ?? 0.0).toDouble(),
      heartRate: (json['heartRate'] ?? 0.0).toDouble(),
      doctorNotes: json['doctorNotes'] ?? '',
      ultrasoundImage: json['ultrasoundImage'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'week': week,
      'weight': weight,
      'length': length,
      'heartRate': heartRate,
      'doctorNotes': doctorNotes,
      'ultrasoundImage': ultrasoundImage,
    };
  }

  String get babySize => _getBabySize(week);
  String get weightFormatted => '${weight.toStringAsFixed(0)}g';
  String get lengthFormatted => '${length.toStringAsFixed(1)}cm';
  String get heartRateFormatted => '${heartRate.toStringAsFixed(0)} bpm';

  static String _getBabySize(int week) {
    final sizes = {
      5: 'apple seed',
      6: 'lentil',
      7: 'blueberry',
      8: 'kidney bean',
      9: 'grape',
      10: 'strawberry',
      11: 'fig',
      12: 'lime',
      13: 'pea pod',
      14: 'lemon',
      15: 'apple',
      16: 'avocado',
      17: 'turnip',
      18: 'bell pepper',
      19: 'tomato',
      20: 'banana',
      21: 'carrot',
      22: 'spaghetti squash',
      23: 'large mango',
      24: 'ear of corn',
      25: 'acorn squash',
      26: 'scallion',
      27: 'cauliflower',
      28: 'eggplant',
      29: 'butternut squash',
      30: 'cabbage',
      31: 'coconut',
      32: 'jicama',
      33: 'pineapple',
      34: 'cantaloupe',
      35: 'honeydew',
      36: 'head of lettuce',
      37: 'winter melon',
      38: 'leek',
      39: 'watermelon',
      40: 'pumpkin',
    };
    return sizes[week] ?? 'watermelon';
  }
}

class FetalGrowthStandard {
  final int week;
  final double minWeight;
  final double maxWeight;
  final double avgWeight;
  final double minLength;
  final double maxLength;
  final double avgLength;

  FetalGrowthStandard({
    required this.week,
    required this.minWeight,
    required this.maxWeight,
    required this.avgWeight,
    required this.minLength,
    required this.maxLength,
    required this.avgLength,
  });

  factory FetalGrowthStandard.fromJson(Map<String, dynamic> json) {
    return FetalGrowthStandard(
      week: json['week'] ?? 0,
      minWeight: (json['minWeight'] ?? 0.0).toDouble(),
      maxWeight: (json['maxWeight'] ?? 0.0).toDouble(),
      avgWeight: (json['avgWeight'] ?? 0.0).toDouble(),
      minLength: (json['minLength'] ?? 0.0).toDouble(),
      maxLength: (json['maxLength'] ?? 0.0).toDouble(),
      avgLength: (json['avgLength'] ?? 0.0).toDouble(),
    );
  }

  bool isWeightNormal(double weight) => weight >= minWeight && weight <= maxWeight;
  bool isLengthNormal(double length) => length >= minLength && length <= maxLength;
}
