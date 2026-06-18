import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_session_service.dart';
import 'mom_api_base_url.dart';

class MomApiException implements Exception {
  MomApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class MomApiService {
  MomApiService({http.Client? client}) : _client = client ?? AuthenticatedClient();

  final http.Client _client;

  static String get _baseUrl => momApiBaseUrl();

  Future<Map<String, dynamic>> login({
    required String userId,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/login');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId.trim().toUpperCase(),
        'password': password,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['access_token']?.toString();
      final role = data['role']?.toString();
      final normalizedUserId = data['user_id']?.toString() ?? userId.trim().toUpperCase();
      if (token != null && token.isNotEmpty && role != null && role.isNotEmpty) {
        await AuthSessionService.save(
          accessToken: token,
          userId: normalizedUserId,
          role: role,
        );
      }
      return data;
    }

    String message = 'Login failed';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'];
      }
    } catch (_) {}

    throw MomApiException(message, statusCode: response.statusCode);
  }

  Future<Map<String, dynamic>> createAccount({
    required String role,
    required String userId,
    required String fullName,
    required String phone,
    required String password,
  }) async {
    final normalizedRole = role.trim().toLowerCase();
    late final Uri uri;
    late final String idField;

    if (normalizedRole == 'mother') {
      uri = Uri.parse('$_baseUrl/mothers/onboarding');
      idField = 'patient_id';
    } else if (normalizedRole == 'doctor') {
      uri = Uri.parse('$_baseUrl/doctors/onboarding');
      idField = 'doctor_id';
    } else if (normalizedRole == 'health worker') {
      uri = Uri.parse('$_baseUrl/health-workers/onboarding');
      idField = 'worker_id';
    } else {
      throw MomApiException('Unsupported role: $role');
    }

    final request = http.MultipartRequest('POST', uri)
      ..fields[idField] = userId.trim().toUpperCase()
      ..fields['full_name'] = fullName.trim()
      ..fields['phone'] = phone.trim()
      ..fields['password'] = password;

    late final http.Response response;
    try {
      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));
      response = await http.Response.fromStream(streamedResponse);
    } on SocketException {
      throw MomApiException(
        'Cannot reach backend. Check MOM_API_BASE_URL and backend server.',
      );
    } on TimeoutException {
      throw MomApiException(
        'Backend request timed out. Check phone network, adb reverse, and MOM_API_BASE_URL.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await login(userId: userId, password: password);
      return data;
    }

    String message = 'Failed to create account';
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final backendMessage = data['detail']?.toString();
      if (backendMessage != null && backendMessage.isNotEmpty) {
        message = backendMessage;
      }
    } catch (_) {
      // Keep fallback message if response body is not JSON.
    }
    throw MomApiException(message, statusCode: response.statusCode);
  }

  Future<void> submitMomOnboarding({
    required String patientId,
    required String fullName,
    int? age,
    double? weightKg,
    String? bloodGroup,
    int? pregnantWeeks,
    DateTime? dueDate,
    String? phone,
    String? address,
    String? emergencyContact,
    String? allergies,
    String? password,
    File? profileImage,
    Uint8List? profileImageBytes,
    String profileImageFilename = 'profile.jpg',
  }) async {
    final uri = Uri.parse('$_baseUrl/mothers/onboarding');
    final request = http.MultipartRequest('POST', uri)
      ..fields['patient_id'] = patientId
      ..fields['full_name'] = fullName;

    if (age != null) {
      request.fields['age'] = age.toString();
    }
    if (weightKg != null) {
      request.fields['weight_kg'] = weightKg.toString();
    }
    if (bloodGroup != null && bloodGroup.isNotEmpty) {
      request.fields['blood_group'] = bloodGroup;
    }
    if (pregnantWeeks != null) {
      request.fields['pregnant_weeks'] = pregnantWeeks.toString();
    }
    if (dueDate != null) {
      request.fields['due_date'] = dueDate.toIso8601String();
    }
    if (phone != null && phone.isNotEmpty) {
      request.fields['phone'] = phone;
    }
    if (address != null && address.isNotEmpty) {
      request.fields['address'] = address;
    }
    if (emergencyContact != null && emergencyContact.isNotEmpty) {
      request.fields['emergency_contact'] = emergencyContact;
    }
    if (allergies != null && allergies.isNotEmpty) {
      request.fields['allergies'] = allergies;
    }
    if (password != null && password.isNotEmpty) {
      request.fields['password'] = password;
    }
    if (profileImageBytes != null && profileImageBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'profile_image',
          profileImageBytes,
          filename: profileImageFilename,
        ),
      );
    } else if (profileImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath('profile_image', profileImage.path),
      );
    }

    late final http.Response response;
    try {
      final streamedResponse = await _client.send(request);
      response = await http.Response.fromStream(streamedResponse);
    } on SocketException {
      throw MomApiException(
        'Cannot reach backend. Check MOM_API_BASE_URL and backend server.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Failed to submit mom profile.';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final backendMessage = data['detail']?.toString();
        if (backendMessage != null && backendMessage.isNotEmpty) {
          message = backendMessage;
        }
      } catch (_) {
        // Keep fallback message if response body is not JSON.
      }
      throw MomApiException(message, statusCode: response.statusCode);
    }
  }

  Future<Map<String, dynamic>> fetchMotherByPatientId(String patientId) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}',
    );
    late final http.Response response;
    try {
      response = await _client.get(uri);
    } on SocketException {
      throw MomApiException(
        'Cannot reach backend at $_baseUrl. Start the server (backend/run.py) '
        'or set MOM_API_BASE_URL.',
      );
    } on http.ClientException catch (e) {
      throw MomApiException('Cannot reach backend: ${e.message}');
    }

    if (response.statusCode == 200) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        throw MomApiException('Invalid mother profile response from server');
      } on FormatException catch (e) {
        throw MomApiException('Invalid JSON from server: ${e.message}');
      }
    }

    if (response.statusCode == 404) {
      throw MomApiException('Mother record not found', statusCode: 404);
    }

    throw MomApiException(
      'Failed to fetch mother profile',
      statusCode: response.statusCode,
    );
  }

  Future<void> updateMotherProfile(
    String patientId,
    Map<String, dynamic> profileData,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}',
    );
    final response = await _client.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(profileData),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MomApiException(
        'Failed to update mother profile',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchPatientsByDoctor(
    String doctorId,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/doctors/${doctorId.trim().toUpperCase()}/patients',
    );
    debugPrint('Fetching patients for doctor: $doctorId');

    try {
      final response = await _client.get(uri);
      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as List<dynamic>;
        debugPrint('Fetched ${decoded.length} patients');
        return decoded.cast<Map<String, dynamic>>();
      } else {
        throw MomApiException(
          'Failed to fetch patients',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error fetching patients: $e');
      rethrow;
    }
  }

  Future<void> assignPatientToDoctor(String doctorId, String patientId) async {
    final uri = Uri.parse(
      '$_baseUrl/doctors/${doctorId.trim().toUpperCase()}/assign-patient/${patientId.trim().toUpperCase()}',
    );
    debugPrint('Assigning patient $patientId to doctor $doctorId');

    try {
      final response = await _client.post(uri);
      debugPrint('Assignment response status: ${response.statusCode}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MomApiException(
          'Failed to assign patient to doctor',
          statusCode: response.statusCode,
        );
      }
      debugPrint('Patient assigned successfully');
    } catch (e) {
      debugPrint('Error assigning patient: $e');
      rethrow;
    }
  }

  Future<void> saveContractionSession({
    required String patientId,
    required DateTime sessionDate,
    required int contractionSeconds,
    required int relaxationSeconds,
    required int lapCount,
    String? timelineData,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/contractions',
    );
    final body = {
      'session_date': sessionDate.toIso8601String(),
      'contraction_seconds': contractionSeconds.toString(),
      'relaxation_seconds': relaxationSeconds.toString(),
      'lap_count': lapCount.toString(),
    };

    if (timelineData != null && timelineData.isNotEmpty) {
      body['timeline_data'] = timelineData;
    }

    late final http.Response response;
    try {
      response = await _client.post(
        uri,
        body: body,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
    } on SocketException {
      throw MomApiException(
        'Cannot reach backend. Check MOM_API_BASE_URL and backend server.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MomApiException(
        'Failed to save contraction session',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchContractionHistory(
    String patientId,
  ) async {
    final normalizedId = patientId.trim().toUpperCase();
    debugPrint('Fetching contraction history for patient: $normalizedId');

    final uri = Uri.parse('$_baseUrl/mothers/$normalizedId/contractions');
    debugPrint('Request URL: $uri');

    try {
      final response = await _client.get(uri);
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as List<dynamic>;
        debugPrint('Decoded ${decoded.length} contraction sessions');
        return decoded.cast<Map<String, dynamic>>();
      } else {
        debugPrint(
          'Failed to fetch contraction history. Status: ${response.statusCode}',
        );
        throw MomApiException(
          'Failed to fetch contraction history',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error fetching contraction history: $e');
      rethrow;
    }
  }

  Future<void> saveSleepSession({
    required String patientId,
    required DateTime sessionDate,
    required double sleepHours,
    required double goalHours,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/sleep',
    );
    final body = {
      'session_date': sessionDate.toIso8601String(),
      'sleep_hours': sleepHours.toString(),
      'goal_hours': goalHours.toString(),
    };

    late final http.Response response;
    try {
      response = await _client.post(uri, body: body);
    } on SocketException {
      throw MomApiException(
        'Cannot reach backend. Check MOM_API_BASE_URL and backend server.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MomApiException(
        'Failed to save sleep session',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchSleepHistory(String patientId) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/sleep',
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }
    throw MomApiException(
      'Failed to fetch sleep history',
      statusCode: response.statusCode,
    );
  }

  Future<void> createPillPrescription({
    required String patientId,
    required String doctorId,
    required String pillName,
    required String dosage,
    required String timing,
    required String mealTime,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
    String? notes,
    String? doseScheduleJson,
    String? trimesterSafety,
    int? refillReminderDays,
    String? interactionWarnings,
    String? allergyConcerns,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/prescriptions',
    );
    final body = {
      'doctor_id': doctorId.trim().toUpperCase(),
      'pill_name': pillName,
      'dosage': dosage,
      'timing': timing,
      'meal_time': mealTime,
      'frequency': frequency,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String() ?? '',
      'notes': notes ?? '',
      'dose_schedule_json': doseScheduleJson ?? '',
      'trimester_safety': trimesterSafety ?? '',
      'refill_reminder_days': (refillReminderDays ?? 0).toString(),
      'interaction_warnings': interactionWarnings ?? '',
      'allergy_concerns': allergyConcerns ?? '',
    };

    late final http.Response response;
    try {
      response = await _client.post(uri, body: body);
    } on SocketException {
      throw MomApiException(
        'Cannot reach backend. Check MOM_API_BASE_URL and backend server.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MomApiException(
        'Failed to create pill prescription',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchPillPrescriptions(
    String patientId,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/prescriptions',
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }
    throw MomApiException(
      'Failed to fetch pill prescriptions',
      statusCode: response.statusCode,
    );
  }

  Future<void> recordPillIntake({
    required String patientId,
    required int prescriptionId,
    required DateTime intakeDate,
    required String mealTime,
    required bool taken,
    String? notes,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/pill-intake',
    );
    final body = {
      'prescription_id': prescriptionId.toString(),
      'intake_date': intakeDate.toIso8601String(),
      'meal_time': mealTime,
      'taken': taken.toString(),
      'notes': notes ?? '',
    };

    late final http.Response response;
    try {
      response = await _client.post(uri, body: body);
    } on SocketException {
      throw MomApiException(
        'Cannot reach backend. Check MOM_API_BASE_URL and backend server.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MomApiException(
        'Failed to record pill intake',
        statusCode: response.statusCode,
      );
    }
  }

  // --------------- Diet ---------------

  Future<Map<String, dynamic>> fetchTodayDietPlan(String patientId) async {
    final uri = Uri.parse(
      '$_baseUrl/diet/plan/today/${patientId.trim().toUpperCase()}',
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw MomApiException(
      'Failed to fetch today\'s diet plan',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> regenerateDietPlan(String patientId) async {
    final uri = Uri.parse('$_baseUrl/diet/plan/regenerate');
    final response = await _client.post(
      uri,
      body: {'patient_id': patientId.trim().toUpperCase()},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw MomApiException(
      'Failed to regenerate diet plan',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> markMealComplete({
    required int planId,
    required String slot,
    bool completed = true,
    int? feedbackRating,
    String? feedbackText,
  }) async {
    final uri = Uri.parse('$_baseUrl/diet/plan/complete-meal');
    final body = <String, String>{
      'plan_id': planId.toString(),
      'slot': slot,
      'completed': completed.toString(),
    };
    if (feedbackRating != null) {
      body['feedback_rating'] = feedbackRating.toString();
    }
    if (feedbackText != null && feedbackText.isNotEmpty) {
      body['feedback_text'] = feedbackText;
    }
    final response = await _client.post(uri, body: body);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw MomApiException(
      'Failed to mark meal complete',
      statusCode: response.statusCode,
    );
  }

  /// Returns null when the mother has not generated an AI plan yet (404).
  Future<Map<String, dynamic>?> fetchLatestAiDietAssistantPlan(String patientId) async {
    final uri = Uri.parse(
      '$_baseUrl/diet/ai-assistant-plan/latest/${patientId.trim().toUpperCase()}',
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 404) {
      return null;
    }
    throw MomApiException(
      _parseApiError(response, 'Failed to fetch AI diet assistant plan'),
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> generateAiDietAssistantPlan(
    String patientId, {
    String? targetDate,
    String? dislikeFeedback,
  }) async {
    final uri = Uri.parse('$_baseUrl/diet/ai-assistant-plan/generate');
    final body = <String, String>{
      'patient_id': patientId.trim().toUpperCase(),
    };
    if (targetDate != null && targetDate.isNotEmpty) {
      body['target_date'] = targetDate;
    }
    if (dislikeFeedback != null && dislikeFeedback.trim().isNotEmpty) {
      body['dislike_feedback'] = dislikeFeedback.trim();
    }
    final response = await _client
        .post(uri, body: body)
        .timeout(const Duration(seconds: 90));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw MomApiException(
      _parseApiError(response, 'Failed to generate AI diet assistant plan'),
      statusCode: response.statusCode,
    );
  }

  String _parseApiError(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return '${first['msg']}';
          }
        }
      }
    } catch (_) {}
    return fallback;
  }

  /// Upload (or replace) the mother's profile image. Returns the stored path.
  Future<String?> uploadMotherProfileImage({
    required String patientId,
    File? imageFile,
    Uint8List? imageBytes,
    String imageFilename = 'profile.jpg',
  }) async {
    if (imageFile == null && (imageBytes == null || imageBytes.isEmpty)) {
      throw ArgumentError('Provide imageFile or imageBytes');
    }
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/profile-image',
    );
    final http.MultipartFile filePart = imageBytes != null && imageBytes.isNotEmpty
        ? http.MultipartFile.fromBytes(
            'profile_image',
            imageBytes,
            filename: imageFilename,
          )
        : await http.MultipartFile.fromPath(
            'profile_image',
            imageFile!.path,
          );
    final request = http.MultipartRequest('POST', uri)..files.add(filePart);
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MomApiException(
        'Failed to upload profile image',
        statusCode: response.statusCode,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['profile_image_path'] as String?;
  }

  /// Per-day pill adherence history for the last [days] days.
  ///
  /// The endpoint returns either an envelope `{ days: [...], window_adherence_pct, ... }`
  /// (current backend) or a bare list of day records (legacy). This helper
  /// normalises both into the same envelope so callers don't care.
  Future<Map<String, dynamic>> fetchPillHistory(
    String patientId, {
    int days = 30,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/pill-history?days=$days',
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw MomApiException(
        'Failed to fetch pill history',
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is List) {
      final dayList = decoded.cast<Map<String, dynamic>>();
      int taken = 0;
      int missed = 0;
      for (final d in dayList) {
        taken += (d['taken'] as int?) ?? 0;
        missed += (d['missed'] as int?) ?? 0;
      }
      final total = taken + missed;
      return {
        'days': dayList,
        'window_days': days,
        'total_taken': taken,
        'total_missed': missed,
        'window_adherence_pct': total == 0
            ? 0
            : ((taken / total) * 100).round(),
        'prescription_count': null,
      };
    }
    throw MomApiException('Unexpected pill-history payload');
  }

  Future<List<Map<String, dynamic>>> fetchPillIntakes(
    String patientId, {
    DateTime? date,
  }) async {
    final query = <String, String>{};
    if (date != null) query['date'] = date.toIso8601String();
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/pill-intake',
    ).replace(queryParameters: query.isEmpty ? null : query);

    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }
    throw MomApiException(
      'Failed to fetch pill intakes',
      statusCode: response.statusCode,
    );
  }

  Future<void> createAppointment({
    required String patientId,
    required String healthWorkerId,
    required DateTime appointmentDate,
    required String appointmentTime,
    int durationMinutes = 30,
    required String appointmentType,
    String? notes,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/appointments',
    );
    final body = {
      'health_worker_id': healthWorkerId.trim().toUpperCase(),
      'appointment_date': appointmentDate.toIso8601String(),
      'appointment_time': appointmentTime,
      'duration_minutes': durationMinutes.toString(),
      'appointment_type': appointmentType,
      'notes': notes ?? '',
    };

    late final http.Response response;
    try {
      response = await _client.post(uri, body: body);
    } on SocketException {
      throw MomApiException(
        'Cannot reach backend. Check MOM_API_BASE_URL and backend server.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MomApiException(
        'Failed to create appointment',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchAppointments(
    String patientId, {
    DateTime? date,
    String? status,
  }) async {
    final params = <String, String>{};
    if (date != null) {
      params['date'] = date.toIso8601String();
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      params['status'] = status;
    }
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/appointments',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }
    throw MomApiException(
      'Failed to fetch appointments',
      statusCode: response.statusCode,
    );
  }

  Future<List<Map<String, dynamic>>> fetchHealthWorkerAppointments(
    String healthWorkerId, {
    DateTime? date,
    String? status,
  }) async {
    final params = <String, String>{};
    if (date != null) {
      params['date'] = date.toIso8601String();
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      params['status'] = status;
    }
    final uri = Uri.parse(
      '$_baseUrl/health-workers/${healthWorkerId.trim().toUpperCase()}/appointments',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }
    throw MomApiException(
      'Failed to fetch health worker appointments',
      statusCode: response.statusCode,
    );
  }

  Future<void> updateAppointmentStatus({
    required int appointmentId,
    required String status,
    String? notes,
  }) async {
    final uri = Uri.parse('$_baseUrl/appointments/$appointmentId');
    final body = {'status': status, 'notes': notes ?? ''};

    late final http.Response response;
    try {
      response = await _client.put(uri, body: body);
    } on SocketException {
      throw MomApiException(
        'Cannot reach backend. Check MOM_API_BASE_URL and backend server.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MomApiException(
        'Failed to update appointment status',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> saveKickSession({
    required String patientId,
    required DateTime sessionDate,
    required int kickCount,
    required double durationMinutes,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/kicks',
    );
    final body = {
      'session_date': sessionDate.toIso8601String(),
      'kick_count': kickCount.toString(),
      'duration_minutes': durationMinutes.toString(),
    };

    late final http.Response response;
    try {
      response = await _client.post(uri, body: body);
    } on SocketException {
      throw MomApiException(
        'Cannot reach backend. Check MOM_API_BASE_URL and backend server.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MomApiException(
        'Failed to save kick session',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchKickHistory(String patientId) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/kicks',
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }
    throw MomApiException(
      'Failed to fetch kick history',
      statusCode: response.statusCode,
    );
  }

  // === TOOLS API METHODS ===

  Future<void> createDietLog({
    required String patientId,
    required String mealType,
    required String foodItems,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    String notes = '',
  }) async {
    final uri = Uri.parse('$_baseUrl/diet/logs');
    final request = http.MultipartRequest('POST', uri);

    request.fields['patient_id'] = patientId.trim().toUpperCase();
    request.fields['meal_type'] = mealType;
    request.fields['food_items'] = foodItems;
    request.fields['calories'] = calories.toString();
    request.fields['protein'] = protein.toString();
    request.fields['carbs'] = carbs.toString();
    request.fields['fat'] = fat.toString();
    request.fields['notes'] = notes;

    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MomApiException(
        'Failed to create diet log',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchDietLogs(String patientId) async {
    final uri = Uri.parse(
      '$_baseUrl/diet/logs/${patientId.trim().toUpperCase()}',
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }
    throw MomApiException(
      'Failed to fetch diet logs',
      statusCode: response.statusCode,
    );
  }

  Future<void> createHydrationLog({
    required String patientId,
    required double waterMl,
    double goalMl = 2500.0,
  }) async {
    final uri = Uri.parse('$_baseUrl/hydration/logs');
    final request = http.MultipartRequest('POST', uri);

    request.fields['patient_id'] = patientId.trim().toUpperCase();
    request.fields['water_ml'] = waterMl.toString();
    request.fields['goal_ml'] = goalMl.toString();

    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MomApiException(
        'Failed to create hydration log',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchHydrationLogs(
    String patientId,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/hydration/logs/${patientId.trim().toUpperCase()}',
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }
    throw MomApiException(
      'Failed to fetch hydration logs',
      statusCode: response.statusCode,
    );
  }

  Future<void> createStepsLog({
    required String patientId,
    required int stepsCount,
    int goalSteps = 10000,
    double? distanceKm,
    int? caloriesBurned,
  }) async {
    final uri = Uri.parse('$_baseUrl/steps/logs');
    final request = http.MultipartRequest('POST', uri);

    request.fields['patient_id'] = patientId.trim().toUpperCase();
    request.fields['steps_count'] = stepsCount.toString();
    request.fields['goal_steps'] = goalSteps.toString();
    if (distanceKm != null) {
      request.fields['distance_km'] = distanceKm.toString();
    }
    if (caloriesBurned != null) {
      request.fields['calories_burned'] = caloriesBurned.toString();
    }

    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MomApiException(
        'Failed to create steps log',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchStepsLogs(String patientId) async {
    final uri = Uri.parse(
      '$_baseUrl/steps/logs/${patientId.trim().toUpperCase()}',
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }
    throw MomApiException(
      'Failed to fetch steps logs',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> fetchPatientDashboardData(
    String patientId,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/dashboard/patient/${patientId.trim().toUpperCase()}',
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw MomApiException(
      'Failed to fetch patient dashboard data',
      statusCode: response.statusCode,
    );
  }

  // === CHAT API METHODS ===

  Future<Map<String, dynamic>> createOrGetChatRoom({
    required String doctorId,
    required String patientId,
  }) async {
    final uri = Uri.parse('$_baseUrl/chat/room');
    final request = http.MultipartRequest('POST', uri);

    request.fields['doctor_id'] = doctorId.trim().toUpperCase();
    request.fields['patient_id'] = patientId.trim().toUpperCase();

    final response = await _client.send(request);
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    }
    throw MomApiException(
      'Failed to create or get chat room',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> sendMessage({
    required String roomId,
    required String senderId,
    required String senderType,
    required String messageText,
    String messageType = 'text',
    String fileUrl = '',
  }) async {
    final uri = Uri.parse('$_baseUrl/chat/message');
    final request = http.MultipartRequest('POST', uri);

    request.fields['room_id'] = roomId;
    request.fields['sender_id'] = senderId.trim().toUpperCase();
    request.fields['sender_type'] = senderType;
    request.fields['message_text'] = messageText;
    request.fields['message_type'] = messageType;
    request.fields['file_url'] = fileUrl;

    final response = await _client.send(request);
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    }
    throw MomApiException(
      'Failed to send message',
      statusCode: response.statusCode,
    );
  }

  Future<List<Map<String, dynamic>>> getChatMessages(
    String roomId, {
    int limit = 50,
  }) async {
    final uri = Uri.parse('$_baseUrl/chat/messages/$roomId?limit=$limit');
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }
    throw MomApiException(
      'Failed to fetch chat messages',
      statusCode: response.statusCode,
    );
  }

  Future<List<Map<String, dynamic>>> getUserChatRooms(
    String userId,
    String userType,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/chat/rooms/${userId.trim().toUpperCase()}/$userType',
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }
    throw MomApiException(
      'Failed to fetch user chat rooms',
      statusCode: response.statusCode,
    );
  }

  Future<void> markMessagesAsRead({
    required String roomId,
    required String userId,
  }) async {
    final uri = Uri.parse('$_baseUrl/chat/read');
    final request = http.MultipartRequest('POST', uri);

    request.fields['room_id'] = roomId;
    request.fields['user_id'] = userId.trim().toUpperCase();

    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MomApiException(
        'Failed to mark messages as read',
        statusCode: response.statusCode,
      );
    }
  }

  // --- Doctor portal --------------------------------------------------------

  Future<Map<String, dynamic>> doctorOverview(String doctorId) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor/${doctorId.trim().toUpperCase()}/overview',
    );
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException('doctor overview failed', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> doctorRiskFeed(
    String doctorId, {
    String level = 'all',
    int limit = 50,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor/${doctorId.trim().toUpperCase()}/risk-feed',
    ).replace(queryParameters: {'level': level, 'limit': '$limit'});
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException('risk feed failed', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> doctorTodayAppointments(String doctorId) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor/${doctorId.trim().toUpperCase()}/today-appointments',
    );
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException(
      'today appointments failed',
      statusCode: res.statusCode,
    );
  }

  Future<Map<String, dynamic>> doctorNearDelivery(
    String doctorId, {
    int days = 30,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor/${doctorId.trim().toUpperCase()}/near-delivery',
    ).replace(queryParameters: {'days': '$days'});
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException('near delivery failed', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> doctorMissedMedications(
    String doctorId, {
    int days = 7,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor/${doctorId.trim().toUpperCase()}/missed-medications',
    ).replace(queryParameters: {'days': '$days'});
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException(
      'missed medications failed',
      statusCode: res.statusCode,
    );
  }

  Future<Map<String, dynamic>> doctorAnalytics(String doctorId) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor/${doctorId.trim().toUpperCase()}/analytics',
    );
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException(
      'doctor analytics failed',
      statusCode: res.statusCode,
    );
  }

  Future<Map<String, dynamic>> motherProfileBundle(String patientId) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/profile-bundle',
    );
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException('profile bundle failed', statusCode: res.statusCode);
  }

  Future<List<Map<String, dynamic>>> motherSymptoms(
    String patientId, {
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/symptoms',
    ).replace(queryParameters: {'limit': '$limit'});
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      final d = jsonDecode(res.body);
      if (d is List) {
        return d.cast<Map<String, dynamic>>();
      }
    }
    throw MomApiException('symptoms failed', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> createMotherSymptom(
    String patientId, {
    required String symptomText,
    required String severity,
    String? notes,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/symptoms',
    );
    final body = <String, String>{
      'symptom_text': symptomText,
      'severity': severity,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MomApiException('symptom log failed', statusCode: res.statusCode);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> logMotherMood(
    String patientId, {
    required String mood,
    String? notes,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/mood-logs',
    );
    final body = <String, String>{
      'mood': mood,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MomApiException('mood log failed', statusCode: res.statusCode);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchMotherMoodLogs(
    String patientId, {
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/mood-logs',
    ).replace(queryParameters: {'limit': '$limit'});
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    }
    throw MomApiException('mood logs failed', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> motherFetalGrowth(String patientId) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/fetal-growth',
    );
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException('fetal growth failed', statusCode: res.statusCode);
  }

  Future<List<Map<String, dynamic>>> listReportsForPatient(
    String patientId,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/reports/${patientId.trim().toUpperCase()}',
    );
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      final d = jsonDecode(res.body);
      if (d is List) {
        return d.cast<Map<String, dynamic>>();
      }
    }
    throw MomApiException('list reports failed', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> uploadReport({
    required String patientId,
    required String reportType,
    File? file,
    List<int>? fileBytes,
    String? fileName,
    String? uploadedBy,
    String uploaderType = 'doctor',
    String? notes,
    bool extract = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/reports/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['patient_id'] = patientId.trim().toUpperCase()
      ..fields['report_type'] = reportType
      ..fields['uploader_type'] = uploaderType
      ..fields['notes'] = notes ?? ''
      ..fields['extract'] = extract.toString();
    if (uploadedBy != null && uploadedBy.isNotEmpty) {
      request.fields['uploaded_by'] = uploadedBy.trim().toUpperCase();
    }
    if (file != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    } else if (fileBytes != null && fileName != null && fileBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );
    } else {
      throw MomApiException('file or fileBytes required');
    }
    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException(
      'upload report failed (${res.statusCode}): ${res.body}',
      statusCode: res.statusCode,
    );
  }

  Future<Map<String, dynamic>> createDelivery({
    required String patientId,
    required String doctorId,
    required DateTime deliveryDate,
    required String deliveryType,
    int babyCount = 1,
    String? complications,
    String? hospital,
    String? notes,
  }) async {
    final uri = Uri.parse('$_baseUrl/deliveries');
    final body = <String, String>{
      'patient_id': patientId.trim().toUpperCase(),
      'doctor_id': doctorId.trim().toUpperCase(),
      'delivery_date': deliveryDate.toIso8601String(),
      'delivery_type': deliveryType,
      'baby_count': '$babyCount',
      'complications': complications ?? '',
      'hospital': hospital ?? '',
      'notes': notes ?? '',
    };
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException('create delivery failed', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> getMotherDelivery(String patientId) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/delivery',
    );
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException('get delivery failed', statusCode: res.statusCode);
  }

  Future<List<Map<String, dynamic>>> doctorDeliveries(String doctorId) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor/${doctorId.trim().toUpperCase()}/deliveries',
    );
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      final d = jsonDecode(res.body);
      if (d is List) {
        return d.cast<Map<String, dynamic>>();
      }
    }
    throw MomApiException(
      'doctor deliveries failed',
      statusCode: res.statusCode,
    );
  }

  Future<Map<String, dynamic>> createNewborn({
    required String motherPatientId,
    String? name,
    String? sex,
    double? birthWeightG,
    double? birthHeightCm,
    int? apgar1,
    int? apgar5,
    double? headCircumferenceCm,
    String? observations,
  }) async {
    final uri = Uri.parse('$_baseUrl/newborns');
    final body = <String, String>{
      'mother_patient_id': motherPatientId.trim().toUpperCase(),
      'name': name ?? '',
      'sex': sex ?? '',
      'birth_weight_g': birthWeightG?.toString() ?? '',
      'birth_height_cm': birthHeightCm?.toString() ?? '',
      'apgar_1min': apgar1?.toString() ?? '',
      'apgar_5min': apgar5?.toString() ?? '',
      'head_circumference_cm': headCircumferenceCm?.toString() ?? '',
      'observations': observations ?? '',
    };
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException('create newborn failed', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> getNewborn(int newbornId) async {
    final uri = Uri.parse('$_baseUrl/newborns/$newbornId');
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException('get newborn failed', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> getMotherNewborn(String patientId) async {
    final uri = Uri.parse(
      '$_baseUrl/mothers/${patientId.trim().toUpperCase()}/newborn',
    );
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException(
      'get mother newborn failed',
      statusCode: res.statusCode,
    );
  }

  Future<Map<String, dynamic>> doctorNewborns(String doctorId) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor/${doctorId.trim().toUpperCase()}/newborns',
    );
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException('doctor newborns failed', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> createNewbornVital({
    required int newbornId,
    required DateTime recordedAt,
    double? weightG,
    double? heightCm,
    double? temperatureC,
    String? jaundiceLevel,
    String? feedingType,
    double? sleepHours,
    String? notes,
  }) async {
    final uri = Uri.parse('$_baseUrl/newborns/$newbornId/vitals');
    final body = <String, String>{
      'recorded_at': recordedAt.toIso8601String(),
      'weight_g': weightG?.toString() ?? '',
      'height_cm': heightCm?.toString() ?? '',
      'temperature_c': temperatureC?.toString() ?? '',
      'jaundice_level': jaundiceLevel ?? '',
      'feeding_type': feedingType ?? '',
      'sleep_hours': sleepHours?.toString() ?? '',
      'notes': notes ?? '',
    };
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException('create vital failed', statusCode: res.statusCode);
  }

  Future<List<Map<String, dynamic>>> listNewbornVitals(int newbornId) async {
    final uri = Uri.parse('$_baseUrl/newborns/$newbornId/vitals');
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      final d = jsonDecode(res.body);
      if (d is List) {
        return d.cast<Map<String, dynamic>>();
      }
    }
    throw MomApiException('list vitals failed', statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> createNewbornVaccination({
    required int newbornId,
    required String vaccineName,
    DateTime? scheduledDate,
    DateTime? givenDate,
    String? batchNo,
    String? notes,
  }) async {
    final uri = Uri.parse('$_baseUrl/newborns/$newbornId/vaccinations');
    final body = <String, String>{
      'vaccine_name': vaccineName,
      'scheduled_date': scheduledDate?.toIso8601String() ?? '',
      'given_date': givenDate?.toIso8601String() ?? '',
      'batch_no': batchNo ?? '',
      'notes': notes ?? '',
    };
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException(
      'create vaccination failed',
      statusCode: res.statusCode,
    );
  }

  Future<List<Map<String, dynamic>>> listNewbornVaccinations(
    int newbornId,
  ) async {
    final uri = Uri.parse('$_baseUrl/newborns/$newbornId/vaccinations');
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      final d = jsonDecode(res.body);
      if (d is List) {
        return d.cast<Map<String, dynamic>>();
      }
    }
    throw MomApiException(
      'list vaccinations failed',
      statusCode: res.statusCode,
    );
  }

  Future<Map<String, dynamic>> createEmergency({
    required String patientId,
    String? doctorId,
    String? raisedBy,
    String level = 'critical',
    String source = 'sos',
    required String summary,
  }) async {
    final uri = Uri.parse('$_baseUrl/emergencies');
    final body = <String, String>{
      'patient_id': patientId.trim().toUpperCase(),
      'doctor_id': doctorId?.trim().toUpperCase() ?? '',
      'raised_by': raisedBy?.trim().toUpperCase() ?? '',
      'level': level,
      'source': source,
      'summary': summary,
    };
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw MomApiException(
      'create emergency failed',
      statusCode: res.statusCode,
    );
  }

  Future<List<Map<String, dynamic>>> doctorEmergencies(
    String doctorId, {
    String status = 'open',
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor/${doctorId.trim().toUpperCase()}/emergencies',
    ).replace(queryParameters: {'status': status});
    final res = await _client.get(uri);
    if (res.statusCode == 200) {
      final d = jsonDecode(res.body);
      if (d is List) {
        return d.cast<Map<String, dynamic>>();
      }
    }
    throw MomApiException(
      'doctor emergencies failed',
      statusCode: res.statusCode,
    );
  }

  Future<void> acknowledgeEmergency(int alertId) async {
    final uri = Uri.parse('$_baseUrl/emergencies/$alertId/acknowledge');
    final res = await _client.post(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MomApiException('ack emergency failed', statusCode: res.statusCode);
    }
  }

  Future<void> resolveEmergency(int alertId) async {
    final uri = Uri.parse('$_baseUrl/emergencies/$alertId/resolve');
    final res = await _client.post(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MomApiException(
        'resolve emergency failed',
        statusCode: res.statusCode,
      );
    }
  }
}
