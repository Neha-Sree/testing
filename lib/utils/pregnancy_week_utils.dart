/// Gestational week advances from due date or weeks-at-signup + elapsed time.
class PregnancyWeekUtils {
  static const int fullTermDays = 280;

  static int? computeFromMother(Map<String, dynamic> data) {
    return compute(
      storedWeeks: (data['pregnant_weeks'] as num?)?.toInt(),
      dueDateIso: data['due_date'] as String?,
      createdAtIso: data['created_at'] as String?,
    );
  }

  static int? compute({
    int? storedWeeks,
    String? dueDateIso,
    String? createdAtIso,
  }) {
    final today = _dateOnly(DateTime.now());

    if (dueDateIso != null && dueDateIso.isNotEmpty) {
      final due = _dateOnly(DateTime.parse(dueDateIso));
      final daysPregnant = fullTermDays - due.difference(today).inDays;
      final weeks = daysPregnant ~/ 7;
      return weeks.clamp(1, 42);
    }

    if (storedWeeks != null && createdAtIso != null && createdAtIso.isNotEmpty) {
      final anchor = _dateOnly(DateTime.parse(createdAtIso));
      final elapsedWeeks = today.difference(anchor).inDays ~/ 7;
      return (storedWeeks + elapsedWeeks).clamp(1, 42);
    }

    return storedWeeks;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
