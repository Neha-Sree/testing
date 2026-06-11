/// Data classes for the Health Worker portal.
///
/// Mirrors the JSON payloads returned by the FastAPI backend
/// (`backend/app/health_worker_endpoints.py`).
library;

class HealthWorker {
  HealthWorker({
    required this.workerId,
    required this.fullName,
    this.phone,
    this.region,
    this.profileImagePath,
  });

  final String workerId;
  final String fullName;
  final String? phone;
  final String? region;
  final String? profileImagePath;

  factory HealthWorker.fromJson(Map<String, dynamic> json) => HealthWorker(
        workerId: json['worker_id'] as String,
        fullName: json['full_name'] as String,
        phone: json['phone'] as String?,
        region: json['region'] as String?,
        profileImagePath: json['profile_image_path'] as String?,
      );
}

/// Risk level returned by the rule-based engine.
enum RiskLevel { green, yellow, red, critical }

RiskLevel parseRiskLevel(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'critical':
      return RiskLevel.critical;
    case 'red':
      return RiskLevel.red;
    case 'yellow':
      return RiskLevel.yellow;
    default:
      return RiskLevel.green;
  }
}

class RiskAssessment {
  RiskAssessment({required this.level, required this.score, required this.reasons});

  final RiskLevel level;
  final int score;
  final List<String> reasons;

  factory RiskAssessment.fromJson(Map<String, dynamic> json) => RiskAssessment(
        level: parseRiskLevel(json['level'] as String?),
        score: (json['score'] as num?)?.toInt() ?? 0,
        reasons: (json['reasons'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
      );

  static const empty = RiskAssessment._empty();

  const RiskAssessment._empty()
      : level = RiskLevel.green,
        score = 0,
        reasons = const [];
}

/// Mother summary returned by `/health-workers/{id}/mothers`.
class AssignedMother {
  AssignedMother({
    required this.patientId,
    required this.fullName,
    required this.risk,
    this.age,
    this.pregnantWeeks,
    this.dueDate,
    this.bloodGroup,
    this.phone,
    this.address,
    this.doctorId,
  });

  final String patientId;
  final String fullName;
  final int? age;
  final int? pregnantWeeks;
  final DateTime? dueDate;
  final String? bloodGroup;
  final String? phone;
  final String? address;
  final String? doctorId;
  final RiskAssessment risk;

  factory AssignedMother.fromJson(Map<String, dynamic> json) => AssignedMother(
        patientId: json['patient_id'] as String,
        fullName: json['full_name'] as String,
        age: (json['age'] as num?)?.toInt(),
        pregnantWeeks: (json['pregnant_weeks'] as num?)?.toInt(),
        dueDate: _parseDate(json['due_date']),
        bloodGroup: json['blood_group'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        doctorId: json['doctor_id'] as String?,
        risk: RiskAssessment(
          level: parseRiskLevel(json['risk_level'] as String?),
          score: (json['risk_score'] as num?)?.toInt() ?? 0,
          reasons: (json['risk_reasons'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(growable: false),
        ),
      );
}

class HomeVisit {
  HomeVisit({
    required this.id,
    required this.patientId,
    required this.healthWorkerId,
    required this.scheduledDate,
    required this.status,
    this.completedAt,
    this.gpsLat,
    this.gpsLon,
    this.address,
    this.notes,
    this.observations,
    this.photoPath,
  });

  final int id;
  final String patientId;
  final String healthWorkerId;
  final DateTime scheduledDate;
  final DateTime? completedAt;
  final double? gpsLat;
  final double? gpsLon;
  final String? address;
  final String? notes;
  final String? observations;
  final String? photoPath;
  final String status;

  factory HomeVisit.fromJson(Map<String, dynamic> json) => HomeVisit(
        id: (json['id'] as num).toInt(),
        patientId: json['patient_id'] as String,
        healthWorkerId: json['health_worker_id'] as String,
        scheduledDate: _parseDate(json['scheduled_date'])!,
        completedAt: _parseDate(json['completed_at']),
        gpsLat: (json['gps_lat'] as num?)?.toDouble(),
        gpsLon: (json['gps_lon'] as num?)?.toDouble(),
        address: json['address'] as String?,
        notes: json['notes'] as String?,
        observations: json['observations'] as String?,
        photoPath: json['photo_path'] as String?,
        status: (json['status'] as String?) ?? 'scheduled',
      );
}

class LabTest {
  LabTest({
    required this.id,
    required this.patientId,
    required this.testDate,
    this.measuredBy,
    this.hemoglobin,
    this.bloodSugarFasting,
    this.bloodSugarPost,
    this.urineSugar,
    this.urineProtein,
    this.thyroidTsh,
    this.ironFerritin,
    this.calcium,
    this.infectionNotes,
    this.notes,
  });

  final int id;
  final String patientId;
  final DateTime testDate;
  final String? measuredBy;
  final double? hemoglobin;
  final double? bloodSugarFasting;
  final double? bloodSugarPost;
  final String? urineSugar;
  final String? urineProtein;
  final double? thyroidTsh;
  final double? ironFerritin;
  final double? calcium;
  final String? infectionNotes;
  final String? notes;

  factory LabTest.fromJson(Map<String, dynamic> json) => LabTest(
        id: (json['id'] as num).toInt(),
        patientId: json['patient_id'] as String,
        testDate: _parseDate(json['test_date']) ?? DateTime.now(),
        measuredBy: json['measured_by'] as String?,
        hemoglobin: (json['hemoglobin'] as num?)?.toDouble(),
        bloodSugarFasting: (json['blood_sugar_fasting'] as num?)?.toDouble(),
        bloodSugarPost: (json['blood_sugar_post'] as num?)?.toDouble(),
        urineSugar: json['urine_sugar'] as String?,
        urineProtein: json['urine_protein'] as String?,
        thyroidTsh: (json['thyroid_tsh'] as num?)?.toDouble(),
        ironFerritin: (json['iron_ferritin'] as num?)?.toDouble(),
        calcium: (json['calcium'] as num?)?.toDouble(),
        infectionNotes: json['infection_notes'] as String?,
        notes: json['notes'] as String?,
      );
}

class PatientReport {
  PatientReport({
    required this.id,
    required this.patientId,
    required this.reportType,
    required this.filePath,
    required this.fileName,
    this.uploadedBy,
    this.uploaderType,
    this.reportDate,
    this.notes,
    this.createdAt,
  });

  final int id;
  final String patientId;
  final String reportType;
  final String filePath;
  final String fileName;
  final String? uploadedBy;
  final String? uploaderType;
  final DateTime? reportDate;
  final String? notes;
  final DateTime? createdAt;

  factory PatientReport.fromJson(Map<String, dynamic> json) => PatientReport(
        id: (json['id'] as num).toInt(),
        patientId: json['patient_id'] as String,
        reportType: json['report_type'] as String,
        filePath: json['file_path'] as String,
        fileName: json['file_name'] as String,
        uploadedBy: json['uploaded_by'] as String?,
        uploaderType: json['uploader_type'] as String?,
        reportDate: _parseDate(json['report_date']),
        notes: json['notes'] as String?,
        createdAt: _parseDate(json['created_at']),
      );
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
