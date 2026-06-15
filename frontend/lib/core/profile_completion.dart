import 'profile_display_name.dart';

class ProfileCompletionResult {
  final int percent;
  final List<String> missingFieldLabels;

  const ProfileCompletionResult({
    required this.percent,
    required this.missingFieldLabels,
  });
}

/// Completion is based on user-entered profile fields only (no placeholders).
ProfileCompletionResult calculateProfileCompletion({
  required String? profileFullName,
  required String? profileStudentId,
  required String? profileEmail,
  required String? firebaseEmail,
  required String? major,
  required String? academicYear,
  required String? gpa,
}) {
  final fields = <String, bool Function()>{
    'Full name': () {
      final name = profileFullName?.trim() ?? '';
      return name.isNotEmpty && !isPlaceholderProfileName(name);
    },
    'Student ID': () => (profileStudentId?.trim() ?? '').isNotEmpty,
    'Email': () {
      final email = profileEmail?.trim() ?? '';
      if (email.isNotEmpty && !isPlaceholderProfileEmail(email)) {
        return true;
      }
      final fb = firebaseEmail?.trim() ?? '';
      return fb.isNotEmpty;
    },
    'Major': () => (major?.trim() ?? '').isNotEmpty,
    'Academic level': () => (academicYear?.trim() ?? '').isNotEmpty,
    'GPA': () => (gpa?.trim() ?? '').isNotEmpty,
  };

  final filled = fields.values.where((check) => check()).length;
  final missing = <String>[];
  for (final entry in fields.entries) {
    if (!entry.value()) {
      missing.add(entry.key);
    }
  }

  final percent = ((filled / fields.length) * 100).round();
  return ProfileCompletionResult(
    percent: percent,
    missingFieldLabels: missing,
  );
}
