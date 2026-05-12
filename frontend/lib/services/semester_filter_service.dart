class SemesterOption {
  final String id;
  final String label;
  final bool isUnknown;
  final int sortScore;

  const SemesterOption({
    required this.id,
    required this.label,
    this.isUnknown = false,
    this.sortScore = -1,
  });
}

class SemesterFilterService {
  static const String unknownSemesterId = 'unknown_semester';
  static const String unknownSemesterLabel = 'Unknown Semester';

  static final RegExp _termYearPattern = RegExp(
    r'\b(Spring|Summer|Fall|Autumn|Winter)\s*[-_/]?\s*(20\d{2})\b',
    caseSensitive: false,
  );
  static final RegExp _yearTermPattern = RegExp(
    r'\b(20\d{2})\s*[-_/]?\s*(Spring|Summer|Fall|Autumn|Winter)\b',
    caseSensitive: false,
  );
  static final RegExp _semesterNumPattern = RegExp(
    r'\b(20\d{2})\s*[-_/]?\s*(S(?:em(?:ester)?)?\s*[12])\b',
    caseSensitive: false,
  );
  static final RegExp _yearRangePattern = RegExp(r'\b(20\d{2})\s*[-/]\s*(\d{2,4})\b');

  static List<SemesterOption> extractSemesters(List<Map<String, dynamic>> courses) {
    final Map<String, SemesterOption> byId = {};
    bool hasUnknown = false;

    for (final course in courses) {
      final detected = detectFromCourse(course);
      if (detected == null) {
        hasUnknown = true;
        continue;
      }
      byId[detected.id] = detected;
    }

    final semesters = byId.values.toList()
      ..sort((a, b) => b.sortScore.compareTo(a.sortScore));

    if (hasUnknown) {
      semesters.add(
        const SemesterOption(
          id: unknownSemesterId,
          label: unknownSemesterLabel,
          isUnknown: true,
          sortScore: -1,
        ),
      );
    }

    return semesters;
  }

  /// Same as [extractSemesters], but guarantees at least one entry so the UI and
  /// sync flow can proceed (e.g. API returned zero courses, or nothing matched).
  static List<SemesterOption> extractSemestersOrFallback(
    List<Map<String, dynamic>> courses,
  ) {
    final list = extractSemesters(courses);
    if (list.isNotEmpty) return list;
    return const [
      SemesterOption(
        id: unknownSemesterId,
        label: unknownSemesterLabel,
        isUnknown: true,
        sortScore: -1,
      ),
    ];
  }

  static SemesterOption? detectFromCourse(Map<String, dynamic> course) {
    final fields = <String>[
      (course['name'] as String?) ?? '',
      (course['section'] as String?) ?? '',
      (course['description'] as String?) ?? '',
      (course['descriptionHeading'] as String?) ?? '',
      (course['room'] as String?) ?? '',
    ];
    final text = fields.where((s) => s.trim().isNotEmpty).join(' | ');
    if (text.isEmpty) return null;

    final termYear = _termYearPattern.firstMatch(text);
    if (termYear != null) {
      final term = _normalizeTerm(termYear.group(1)!);
      final year = int.tryParse(termYear.group(2)!);
      if (year != null) return _buildOption(term: term, year: year);
    }

    final yearTerm = _yearTermPattern.firstMatch(text);
    if (yearTerm != null) {
      final year = int.tryParse(yearTerm.group(1)!);
      final term = _normalizeTerm(yearTerm.group(2)!);
      if (year != null) return _buildOption(term: term, year: year);
    }

    final semesterNum = _semesterNumPattern.firstMatch(text);
    if (semesterNum != null) {
      final year = int.tryParse(semesterNum.group(1)!);
      final raw = semesterNum.group(2)!.toLowerCase();
      final term = raw.contains('2') ? 'Semester 2' : 'Semester 1';
      if (year != null) return _buildOption(term: term, year: year);
    }

    final yearRange = _yearRangePattern.firstMatch(text);
    if (yearRange != null) {
      final start = int.tryParse(yearRange.group(1)!);
      var endText = yearRange.group(2)!;
      if (start != null) {
        if (endText.length == 2) {
          endText = '${start ~/ 100}$endText';
        }
        final end = int.tryParse(endText);
        final label = end != null ? '$start-$end' : '$start';
        return SemesterOption(
          id: _slug(label),
          label: label,
          sortScore: start * 10,
        );
      }
    }

    return null;
  }

  static String selectDefaultSemesterId(
    List<SemesterOption> semesters, {
    String? savedSemesterId,
  }) {
    if (savedSemesterId != null &&
        semesters.any((s) => s.id == savedSemesterId)) {
      return savedSemesterId;
    }

    final known = semesters.where((s) => !s.isUnknown).toList();
    if (known.isNotEmpty) return known.first.id;

    if (semesters.isNotEmpty) return semesters.first.id;
    return unknownSemesterId;
  }

  static bool matchesSemester({
    required Map<String, dynamic> course,
    required String semesterId,
  }) {
    final detected = detectFromCourse(course);
    if (detected == null) return semesterId == unknownSemesterId;
    return detected.id == semesterId;
  }

  static SemesterOption _buildOption({
    required String term,
    required int year,
  }) {
    final normalizedTerm = term.trim();
    final label = '$normalizedTerm $year';
    final score = year * 10 + _termRank(normalizedTerm);
    return SemesterOption(
      id: _slug(label),
      label: label,
      sortScore: score,
    );
  }

  static int _termRank(String term) {
    switch (term.toLowerCase()) {
      case 'spring':
      case 'semester 1':
        return 1;
      case 'summer':
        return 2;
      case 'fall':
      case 'autumn':
      case 'semester 2':
        return 3;
      case 'winter':
        return 4;
      default:
        return 0;
    }
  }

  static String _normalizeTerm(String raw) {
    final lower = raw.toLowerCase();
    if (lower == 'autumn') return 'Fall';
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

  static String _slug(String text) {
    final slug = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? unknownSemesterId : slug;
  }
}
