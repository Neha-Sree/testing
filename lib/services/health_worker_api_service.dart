import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/health_worker_models.dart';
import 'auth_session_service.dart';
import 'mom_api_base_url.dart';

class HealthWorkerApiException implements Exception {
  HealthWorkerApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Backend client for the Health Worker portal.
///
/// Uses the same base URL convention as [MomApiService] so a single
/// `--dart-define=MOM_API_BASE_URL=...` flag works for the whole app.
class HealthWorkerApiService {
  HealthWorkerApiService({http.Client? client})
    : _client = client ?? AuthenticatedClient();

  final http.Client _client;

  static String get _baseUrl => momApiBaseUrl();

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Never _throw(http.Response response, String fallback) {
    String message = fallback;
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['detail'] != null) {
        message = body['detail'].toString();
      }
    } catch (_) {
      /* keep fallback */
    }
    throw HealthWorkerApiException(message, statusCode: response.statusCode);
  }

  Future<HealthWorker> upsertHealthWorker({
    required String workerId,
    required String fullName,
    String? phone,
    String? password,
    String? region,
  }) async {
    final request =
        http.MultipartRequest('POST', _uri('/health-workers/onboarding'))
          ..fields['worker_id'] = workerId
          ..fields['full_name'] = fullName;
    if (phone != null && phone.isNotEmpty) {
      request.fields['phone'] = phone;
    }
    if (password != null && password.isNotEmpty) {
      request.fields['password'] = password;
    }
    if (region != null && region.isNotEmpty) {
      request.fields['region'] = region;
    }

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throw(response, 'Failed to save health worker');
    }
    return HealthWorker.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<HealthWorker?> fetchHealthWorker(String workerId) async {
    final response = await _client.get(
      _uri('/health-workers/${workerId.trim().toUpperCase()}'),
    );
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      _throw(response, 'Failed to load health worker');
    }
    return HealthWorker.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> assignMother({
    required String workerId,
    required String patientId,
  }) async {
    final response = await _client.post(
      _uri(
        '/health-workers/${workerId.trim().toUpperCase()}/assign-mother/${patientId.trim().toUpperCase()}',
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throw(response, 'Failed to assign mother');
    }
  }

  Future<List<AssignedMother>> fetchAssignedMothers(String workerId) async {
    final response = await _client.get(
      _uri('/health-workers/${workerId.trim().toUpperCase()}/mothers'),
    );
    if (response.statusCode != 200) {
      _throw(response, 'Failed to load assigned mothers');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => AssignedMother.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<RiskAssessment> fetchPatientRisk(String patientId) async {
    final response = await _client.get(
      _uri('/risk/${patientId.trim().toUpperCase()}'),
    );
    if (response.statusCode != 200) {
      _throw(response, 'Failed to load risk');
    }
    return RiskAssessment.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<HomeVisit> scheduleHomeVisit({
    required String patientId,
    required String workerId,
    required DateTime scheduledDate,
    String? notes,
  }) async {
    final body = <String, String>{
      'patient_id': patientId.trim().toUpperCase(),
      'health_worker_id': workerId.trim().toUpperCase(),
      'scheduled_date': scheduledDate.toIso8601String(),
    };
    final trimmedNotes = notes?.trim();
    if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
      body['notes'] = trimmedNotes;
    }
    final response = await _client.post(_uri('/home-visits'), body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throw(response, 'Failed to schedule visit');
    }
    return HomeVisit.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<HomeVisit> completeHomeVisit({
    required int visitId,
    double? gpsLat,
    double? gpsLon,
    String? address,
    String? observations,
    String? notes,
    Uint8List? photoBytes,
    String? photoFileName,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      _uri('/home-visits/$visitId/complete'),
    );
    if (gpsLat != null) {
      request.fields['gps_lat'] = gpsLat.toString();
    }
    if (gpsLon != null) {
      request.fields['gps_lon'] = gpsLon.toString();
    }
    if (address != null) {
      request.fields['address'] = address;
    }
    if (observations != null) {
      request.fields['observations'] = observations;
    }
    if (notes != null) {
      request.fields['notes'] = notes;
    }
    final bytes = photoBytes;
    final fname = photoFileName;
    if (bytes != null && fname != null) {
      request.files.add(
        http.MultipartFile.fromBytes('photo', bytes, filename: fname),
      );
    }

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throw(response, 'Failed to complete visit');
    }
    return HomeVisit.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<HomeVisit>> fetchHealthWorkerVisits(String workerId) async {
    final response = await _client.get(
      _uri('/home-visits/health-worker/${workerId.trim().toUpperCase()}'),
    );
    if (response.statusCode != 200) {
      _throw(response, 'Failed to load visits');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => HomeVisit.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<HomeVisit>> fetchPatientVisits(String patientId) async {
    final response = await _client.get(
      _uri('/home-visits/patient/${patientId.trim().toUpperCase()}'),
    );
    if (response.statusCode != 200) {
      _throw(response, 'Failed to load patient visits');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => HomeVisit.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Returns `{ "lab_test": {...}, "risk": {...} }` so callers can show
  /// the newly computed risk level right after submitting.
  Future<({LabTest lab, RiskAssessment risk})> createLabTest({
    required String patientId,
    required DateTime testDate,
    String? measuredBy,
    double? hemoglobin,
    double? bloodSugarFasting,
    double? bloodSugarPost,
    String? urineSugar,
    String? urineProtein,
    double? thyroidTsh,
    double? ironFerritin,
    double? calcium,
    String? infectionNotes,
    double? femurLengthCm,
    double? headCircumferenceCm,
    String? notes,
  }) async {
    final form = <String, String>{
      'patient_id': patientId.trim().toUpperCase(),
      'test_date': testDate.toIso8601String(),
      if (measuredBy != null && measuredBy.isNotEmpty)
        'measured_by': measuredBy,
      if (hemoglobin != null) 'hemoglobin': hemoglobin.toString(),
      if (bloodSugarFasting != null)
        'blood_sugar_fasting': bloodSugarFasting.toString(),
      if (bloodSugarPost != null) 'blood_sugar_post': bloodSugarPost.toString(),
      if (urineSugar != null && urineSugar.isNotEmpty)
        'urine_sugar': urineSugar,
      if (urineProtein != null && urineProtein.isNotEmpty)
        'urine_protein': urineProtein,
      if (thyroidTsh != null) 'thyroid_tsh': thyroidTsh.toString(),
      if (ironFerritin != null) 'iron_ferritin': ironFerritin.toString(),
      if (calcium != null) 'calcium': calcium.toString(),
      if (infectionNotes != null && infectionNotes.isNotEmpty)
        'infection_notes': infectionNotes,
      if (femurLengthCm != null) 'femur_length_cm': femurLengthCm.toString(),
      if (headCircumferenceCm != null)
        'head_circumference_cm': headCircumferenceCm.toString(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    final response = await _client.post(_uri('/lab-tests'), body: form);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throw(response, 'Failed to save lab test');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      lab: LabTest.fromJson(decoded['lab_test'] as Map<String, dynamic>),
      risk: RiskAssessment.fromJson(decoded['risk'] as Map<String, dynamic>),
    );
  }

  Future<List<LabTest>> fetchLabTests(String patientId) async {
    final response = await _client.get(
      _uri('/lab-tests/${patientId.trim().toUpperCase()}'),
    );
    if (response.statusCode != 200) {
      _throw(response, 'Failed to load lab tests');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => LabTest.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Vital signs entry. Returns the new risk assessment after recompute.
  Future<RiskAssessment> recordVitalSigns({
    required String patientId,
    double? weightKg,
    int? bpSystolic,
    int? bpDiastolic,
    int? heartRateBpm,
    double? bloodSugar,
    double? temperatureCelsius,
    double? oxygenSaturation,
    String? fetalMovement,
    String? swelling,
    String? measuredBy,
    String? notes,
  }) async {
    final form = <String, String>{
      'patient_id': patientId.trim().toUpperCase(),
      if (weightKg != null) 'weight_kg': weightKg.toString(),
      if (bpSystolic != null) 'blood_pressure_systolic': bpSystolic.toString(),
      if (bpDiastolic != null)
        'blood_pressure_diastolic': bpDiastolic.toString(),
      if (heartRateBpm != null) 'heart_rate_bpm': heartRateBpm.toString(),
      if (bloodSugar != null) 'blood_sugar': bloodSugar.toString(),
      if (temperatureCelsius != null)
        'temperature_celsius': temperatureCelsius.toString(),
      if (oxygenSaturation != null)
        'oxygen_saturation': oxygenSaturation.toString(),
      if (fetalMovement != null && fetalMovement.isNotEmpty)
        'fetal_movement': fetalMovement,
      if (swelling != null && swelling.isNotEmpty) 'swelling': swelling,
      if (measuredBy != null && measuredBy.isNotEmpty)
        'measured_by': measuredBy,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final response = await _client.post(_uri('/health-metrics'), body: form);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throw(response, 'Failed to save vitals');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return RiskAssessment.fromJson(decoded['risk'] as Map<String, dynamic>);
  }

  Future<RiskAssessment> createFetalGrowth({
    required String patientId,
    required int pregnantWeeks,
    String? measuredBy,
    double? fetalWeightGrams,
    double? fetalLengthCm,
    int? heartRateBpm,
    double? fundalHeightCm,
    double? amnioticFluidIndex,
    double? femurLengthCm,
    double? headCircumferenceCm,
    String? notes,
  }) async {
    final form = <String, String>{
      'patient_id': patientId.trim().toUpperCase(),
      'pregnant_weeks': pregnantWeeks.toString(),
      if (measuredBy != null && measuredBy.isNotEmpty) 'measured_by': measuredBy,
      if (fetalWeightGrams != null) 'fetal_weight_grams': fetalWeightGrams.toString(),
      if (fetalLengthCm != null) 'fetal_length_cm': fetalLengthCm.toString(),
      if (heartRateBpm != null) 'heart_rate_bpm': heartRateBpm.toString(),
      if (fundalHeightCm != null) 'fundal_height_cm': fundalHeightCm.toString(),
      if (amnioticFluidIndex != null) 'amniotic_fluid_index': amnioticFluidIndex.toString(),
      if (femurLengthCm != null) 'femur_length_cm': femurLengthCm.toString(),
      if (headCircumferenceCm != null)
        'head_circumference_cm': headCircumferenceCm.toString(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final response = await _client.post(_uri('/fetal-growth'), body: form);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throw(response, 'Failed to save fetal growth');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return RiskAssessment.fromJson(decoded['risk'] as Map<String, dynamic>);
  }

  Future<PatientReport> uploadReport({
    required String patientId,
    required String reportType,
    required Uint8List fileBytes,
    required String fileName,
    String? uploadedBy,
    String? uploaderType,
    DateTime? reportDate,
    String? notes,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/reports/upload'));
    request.fields['patient_id'] = patientId.trim().toUpperCase();
    request.fields['report_type'] = reportType.trim().toLowerCase();
    if (uploadedBy != null && uploadedBy.isNotEmpty) {
      request.fields['uploaded_by'] = uploadedBy;
    }
    if (uploaderType != null && uploaderType.isNotEmpty) {
      request.fields['uploader_type'] = uploaderType;
    }
    if (reportDate != null) {
      request.fields['report_date'] = reportDate.toIso8601String();
    }
    if (notes != null && notes.isNotEmpty) {
      request.fields['notes'] = notes;
    }
    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throw(response, 'Failed to upload report');
    }
    return PatientReport.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> uploadReportAndExtract({
    required String patientId,
    required String reportType,
    required Uint8List fileBytes,
    required String fileName,
    String? uploadedBy,
    String? uploaderType,
    DateTime? reportDate,
    String? notes,
    bool autoApply = false,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/reports/upload-and-extract'),
    );
    request.fields['patient_id'] = patientId.trim().toUpperCase();
    request.fields['report_type'] = reportType.trim().toLowerCase();
    if (uploadedBy != null && uploadedBy.isNotEmpty) {
      request.fields['uploaded_by_id'] = uploadedBy;
    }
    if (uploaderType != null && uploaderType.isNotEmpty) {
      request.fields['uploaded_by_role'] = uploaderType;
    }
    if (reportDate != null) {
      request.fields['report_date'] = reportDate.toIso8601String();
    }
    if (notes != null && notes.isNotEmpty) {
      request.fields['notes'] = notes;
    }
    request.fields['auto_apply'] = autoApply ? 'true' : 'false';
    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );

    final streamed = await _client.send(request).timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throw(response, 'Failed to upload and extract report');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<PatientReport>> fetchReports(String patientId) async {
    final response = await _client.get(
      _uri('/reports/${patientId.trim().toUpperCase()}'),
    );
    if (response.statusCode != 200) _throw(response, 'Failed to load reports');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => PatientReport.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}

/// Helper to log API errors uniformly.
void debugLogHealthWorkerApi(Object error, [StackTrace? stack]) {
  if (kDebugMode) {
    debugPrint('[HealthWorkerApi] $error');
    if (stack != null) debugPrint('$stack');
  }
}
