import 'package:flutter/foundation.dart';

import '../models/task.dart';

/// Classifies synced Classroom rows without deleting any data.
///
/// Dashboard screens keep using the full task list. AI features should use
/// [isActionableForAI] or provider-level filtered lists so grade rows,
/// summaries, materials, and completed work never become schedulable tasks.
class ClassroomItemClassifierService {
  static const actionableTask = 'actionable_task';
  static const gradeItem = 'grade_item';
  static const gradeBucket = 'grade_bucket';
  static const completedWork = 'completed_work';
  static const material = 'material';
  static const dashboardOnly = 'dashboard_only';
  static const unknown = 'unknown';

  static Task classifyTask(Task task) {
    final classified = task.source == 'manual' || task.id.startsWith('manual_')
        ? _classifyManualTask(task)
        : _classifyClassroomTask(task);
    return _withNormalizedPriority(classified);
  }

  static List<Task> classifyAll(List<Task> tasks) {
    final classified = tasks.map(classifyTask).toList();
    _logClassificationSummary(classified);
    return classified;
  }

  static bool isActionableForAI(Task task) {
    final classified =
        task.classificationConfidence == 0.0 ? classifyTask(task) : task;
    final activeStatus = classified.status == TaskStatus.pending ||
        classified.status == TaskStatus.inProgress ||
        classified.status == TaskStatus.missed;

    return activeStatus &&
        classified.itemType == actionableTask &&
        classified.isActionableForAI &&
        !classified.isGradeRelated &&
        !classified.isDashboardOnly &&
        classified.assignedGrade == null;
  }

  static bool isGradeRelated(Task task) => task.isGradeRelated;

  static bool isDashboardOnly(Task task) => task.isDashboardOnly;

  static Map<String, dynamic> buildPersonalizationSignals(List<Task> allTasks) {
    final classified = classifyAllIfNeeded(allTasks);
    final actionable = classified.where(isActionableForAI).toList();
    final gradeRelated = classified.where((t) => t.isGradeRelated).length;
    final completed =
        classified.where((t) => t.status == TaskStatus.completed).length;
    final missed =
        classified.where((t) => t.status == TaskStatus.missed).length;
    final pending =
        classified.where((t) => t.status == TaskStatus.pending).length;
    final inProgress =
        classified.where((t) => t.status == TaskStatus.inProgress).length;
    final total = classified.length;
    final now = DateTime.now();
    final overdue = actionable
        .where((t) => t.hasRealDeadline && t.deadline.isBefore(now))
        .length;

    final courseTaskCounts = <String, int>{};
    for (final task in actionable) {
      courseTaskCounts[task.courseName] =
          (courseTaskCounts[task.courseName] ?? 0) + 1;
    }
    final highWorkloadCourses = courseTaskCounts.entries
        .where((entry) => entry.value >= 3)
        .map((entry) => entry.key)
        .toList();

    final workloadLevel = actionable.length >= 10 || overdue >= 3
        ? 'high'
        : actionable.length >= 5 || overdue >= 1
            ? 'medium'
            : 'low';

    return {
      'pendingTasksCount': pending,
      'inProgressTasksCount': inProgress,
      'completedTasksCount': completed,
      'missedTasksCount': missed,
      'completionRate':
          total > 0 ? double.parse((completed / total).toStringAsFixed(2)) : 0,
      'gradeRelatedItemCount': gradeRelated,
      'dashboardOnlyItemCount':
          classified.where((t) => t.isDashboardOnly).length,
      'actionableTaskCount': actionable.length,
      'overdueActionableCount': overdue,
      'workloadLevel': workloadLevel,
      'highWorkloadCourses': highWorkloadCourses,
      'upcomingDeadlinesCount': actionable.where((task) {
        if (!task.hasRealDeadline) return false;
        final days = task.deadline.difference(now).inDays;
        return days >= 0 && days <= 7;
      }).length,
    };
  }

  static List<Task> classifyAllIfNeeded(List<Task> tasks) {
    if (tasks.isEmpty) return tasks;
    return classifyAll(tasks);
  }

  static Task _classifyManualTask(Task task) {
    final isCompleted = task.status == TaskStatus.completed;
    return task.copyWith(
      source: 'manual',
      itemType: isCompleted ? completedWork : actionableTask,
      isActionableForAI: !isCompleted,
      isGradeRelated: false,
      isDashboardOnly: isCompleted,
      classificationConfidence: 1,
      classificationReason: isCompleted
          ? 'Manual task is completed'
          : 'Manual task is an unfinished user-created deliverable',
      deadlineSource: task.deadlineSource ?? 'user',
    );
  }

  static Task _withNormalizedPriority(Task task) {
    if (task.status == TaskStatus.completed) {
      return task.copyWith(priority: TaskPriority.low);
    }
    if (task.itemType != actionableTask || !task.isActionableForAI) {
      return task;
    }
    if (!task.hasRealDeadline) {
      return task.copyWith(priority: TaskPriority.low);
    }

    final hoursLeft = task.deadline.difference(DateTime.now()).inHours;
    // Missed/overdue actionable work is urgent — the student still owes the
    // submission. Sort logic ranks fresh urgent (close deadline, not yet
    // overdue) ABOVE missed work, so this only affects visual priority tags.
    if (task.status == TaskStatus.missed || hoursLeft < 0) {
      return task.copyWith(priority: TaskPriority.urgent);
    }
    if (hoursLeft <= 24) {
      return task.copyWith(priority: TaskPriority.urgent);
    }
    if (hoursLeft <= 72) {
      return task.copyWith(priority: TaskPriority.high);
    }
    if (hoursLeft <= 7 * 24 && task.priority == TaskPriority.low) {
      return task.copyWith(priority: TaskPriority.medium);
    }
    return task;
  }

  static Task _classifyClassroomTask(Task task) {
    final titleLower = _normalizedTitle(task.title);
    final workType = (task.classroomWorkType ?? '').toUpperCase();
    final submissionState = (task.classroomSubmissionState ?? '').toUpperCase();
    final hasRealDeadline = task.hasRealDeadline;
    final activeStatus = task.status == TaskStatus.pending ||
        task.status == TaskStatus.inProgress ||
        task.status == TaskStatus.missed;

    if (task.assignedGrade != null) {
      return task.copyWith(
        source: 'google_classroom',
        itemType: gradeItem,
        isActionableForAI: false,
        isGradeRelated: true,
        isDashboardOnly: true,
        classificationConfidence: 0.98,
        classificationReason: 'Item has assignedGrade',
      );
    }

    if (task.status == TaskStatus.completed ||
        submissionState == 'TURNED_IN' ||
        submissionState == 'RETURNED' ||
        submissionState == 'RECLAIMED_BY_STUDENT') {
      return task.copyWith(
        source: 'google_classroom',
        itemType: completedWork,
        isActionableForAI: false,
        isGradeRelated: false,
        isDashboardOnly: true,
        classificationConfidence: 0.95,
        classificationReason:
            'Item is completed, submitted, returned, or graded',
      );
    }

    if (workType == 'MATERIAL') {
      return task.copyWith(
        source: 'google_classroom',
        itemType: material,
        isActionableForAI: false,
        isGradeRelated: false,
        isDashboardOnly: true,
        classificationConfidence: 0.95,
        classificationReason: 'Classroom workType is MATERIAL',
      );
    }

    final gradeMatch = _matchesGradePattern(titleLower);
    if (gradeMatch != null) {
      final gradeRelated = gradeMatch.itemType == gradeItem ||
          gradeMatch.itemType == gradeBucket;
      return task.copyWith(
        source: 'google_classroom',
        itemType: gradeMatch.itemType,
        isActionableForAI: false,
        isGradeRelated: gradeRelated,
        isDashboardOnly: true,
        classificationConfidence: gradeMatch.confidence,
        classificationReason: gradeMatch.reason,
      );
    }

    final hasActionableSignal = _hasActionableSignal(titleLower);
    final actionableWorkType = _isActionableWorkType(workType);

    if (activeStatus && hasRealDeadline) {
      if (!(hasActionableSignal || actionableWorkType)) {
        return task.copyWith(
          source: 'google_classroom',
          itemType: dashboardOnly,
          isActionableForAI: false,
          isGradeRelated: false,
          isDashboardOnly: true,
          classificationConfidence: 0.8,
          classificationReason:
              'Classroom row has a due date but no deliverable signals',
        );
      }
      return task.copyWith(
        source: 'google_classroom',
        itemType: actionableTask,
        isActionableForAI: true,
        isGradeRelated: false,
        isDashboardOnly: false,
        classificationConfidence:
            hasActionableSignal || actionableWorkType ? 0.95 : 0.82,
        classificationReason: hasActionableSignal || actionableWorkType
            ? 'Active Classroom deliverable with due date and task signals'
            : 'Active Classroom item with real due date',
      );
    }

    if (activeStatus && hasActionableSignal && actionableWorkType) {
      return task.copyWith(
        source: 'google_classroom',
        itemType: actionableTask,
        isActionableForAI: true,
        isGradeRelated: false,
        isDashboardOnly: false,
        classificationConfidence: 0.68,
        classificationReason:
            'Active Classroom deliverable with task signals but no real due date',
      );
    }

    return task.copyWith(
      source: 'google_classroom',
      itemType: activeStatus ? unknown : dashboardOnly,
      isActionableForAI: false,
      isGradeRelated: false,
      isDashboardOnly: true,
      classificationConfidence: activeStatus ? 0.45 : 0.7,
      classificationReason: activeStatus
          ? 'Ambiguous Classroom item without enough scheduling evidence'
          : 'Inactive Classroom item for dashboard context only',
    );
  }

  /// A title whose LAST word is "grade"/"grades" (optionally followed by a
  /// bracketed weight like "(9)" or "[7.5]") is always a gradebook column —
  /// e.g. "End Term Project Grades", "Assignments Grades (9)" — even if it also
  /// contains deliverable words. This must override every guard below.
  static final RegExp _trailingGradeRe = RegExp(
    r'grades?\s*(\(\s*[\d.%/]+\s*\)|\[\s*[\d.%/]+\s*\])?\s*$',
    caseSensitive: false,
  );

  static _GradeMatchResult? _matchesGradePattern(String titleLower) {
    if (titleLower.isEmpty) return null;

    if (_trailingGradeRe.hasMatch(titleLower)) {
      return _GradeMatchResult(
        itemType: gradeItem,
        confidence: 0.97,
        reason: 'Title ends with grade/grades (gradebook column)',
      );
    }

    for (final title in _exactGradePatterns) {
      if (titleLower == title || titleLower.startsWith('$title ')) {
        return _GradeMatchResult(
          itemType: gradeBucket,
          confidence: 0.95,
          reason: 'Title matches a known grade/category row',
        );
      }
    }

    for (final pattern in _strongGradeSubstrings) {
      if (titleLower.contains(pattern)) {
        return _GradeMatchResult(
          itemType: pattern.contains('total') ? gradeBucket : gradeItem,
          confidence: 0.92,
          reason: 'Title contains grade/category wording',
        );
      }
    }

    for (final entry in _gradeRegexPatterns) {
      if (entry.regex.hasMatch(titleLower)) {
        if (entry.guardAgainst != null &&
            entry.guardAgainst!.hasMatch(titleLower)) {
          continue;
        }
        return _GradeMatchResult(
          itemType: entry.itemType,
          confidence: entry.confidence,
          reason: entry.reason,
        );
      }
    }

    return null;
  }

  static String _normalizedTitle(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _isActionableWorkType(String workType) {
    return workType == 'ASSIGNMENT' ||
        workType == 'SHORT_ANSWER_QUESTION' ||
        workType == 'MULTIPLE_CHOICE_QUESTION';
  }

  static final List<String> _exactGradePatterns = [
    'grades',
    'grade',
    'score',
    'scores',
    'marks',
    'result',
    'results',
    'total',
    'total course work',
    'course work',
    'coursework',
    'total assignments',
    'total labs grades',
    'total labs',
    'overall grade',
    'course grade',
  ];

  static final List<String> _strongGradeSubstrings = [
    'lecture participation',
    '(grades)',
    'labs grades',
    'labs grade',
    'lab grades',
    'lab grade',
    'quiz grades',
    'quiz grade',
    'quizzes grade',
    'quizzes grades',
    'lecture quizzes',
    'lecture quiz grades',
    'lecture quiz grade',
    'midterm grades',
    'midterm grade',
    'final grade',
    'final lab grade',
    'final lab exam grade',
    'attendance grades',
    'attendance grade',
    'term work grades',
    'term work grade',
    'lab assignments grades',
    'lab quiz grades',
    'mini project grades',
    'sample essay marking',
    'essay marking',
    'marking',
    'instructions and rubric',
    'total course work',
    'total assignments',
  ];

  static final List<_GradeRegexEntry> _gradeRegexPatterns = [
    _GradeRegexEntry(
      regex: RegExp(r'\(\s*grades?\s*\)'),
      itemType: gradeItem,
      confidence: 0.94,
      reason: 'Title contains a (Grades) category marker',
    ),
    _GradeRegexEntry(
      regex: RegExp(r'^assignment\s*#\s*\d+\s*$'),
      itemType: gradeItem,
      confidence: 0.97,
      reason: 'Title is only an Assignment#N gradebook column',
    ),
    _GradeRegexEntry(
      regex: RegExp(r'^project\s+phase\s*#\s*\d+\s*$'),
      itemType: gradeItem,
      confidence: 0.97,
      reason: 'Title is only a Project Phase#N gradebook column',
    ),
    _GradeRegexEntry(
      regex: RegExp(r'\bproject\s+total\b'),
      itemType: gradeBucket,
      confidence: 0.96,
      reason: 'Project total grade bucket',
    ),
    _GradeRegexEntry(
      regex: RegExp(r'\bparticipation\b'),
      itemType: gradeBucket,
      confidence: 0.9,
      reason: 'Participation rows are grade categories, not deliverables',
      guardAgainst: RegExp(
        r'\b(assignment|homework|delivery|submission|project\s*#)\b',
      ),
    ),
    _GradeRegexEntry(
      regex: RegExp(r'\bassignment\s+\d+\s+grades?\b'),
      itemType: gradeItem,
      confidence: 0.96,
      reason: 'Title matches "Assignment N Grade"',
    ),
    _GradeRegexEntry(
      regex: RegExp(r'\bgrades?\s*(\[[\d.%]+\]|\([\d.%]+\))?\s*$'),
      itemType: gradeItem,
      confidence: 0.88,
      reason: 'Title ends with grade/grades',
      guardAgainst: RegExp(
        r'\b(project|report|homework|delivery|submission|practical|task|exercise)\b',
      ),
    ),
    _GradeRegexEntry(
      regex: RegExp(r'^total\s+'),
      itemType: gradeBucket,
      confidence: 0.93,
      reason: 'Title starts with Total',
      guardAgainst: RegExp(r'\b(project|report|task)\b'),
    ),
    _GradeRegexEntry(
      regex: RegExp(r'^midterm\s*(\(\d+[%]?\)|\d+\s*%)'),
      itemType: gradeBucket,
      confidence: 0.86,
      reason: 'Title looks like a midterm grade bucket',
    ),
    _GradeRegexEntry(
      regex: RegExp(r'^\s*(lab|lap)\s*\d+\b'),
      itemType: dashboardOnly,
      confidence: 0.62,
      reason: 'Title is a lab session row, not a deliverable',
      guardAgainst: RegExp(
        r'\b(delivery|practice|report|submission|homework|assignment|project)\b',
      ),
    ),
    _GradeRegexEntry(
      regex: RegExp(r'\(\s*\d+(\.\d+)?\s*\)\s*$'),
      itemType: gradeBucket,
      confidence: 0.84,
      reason: 'Title ends with a point-weight bucket like (20)',
      guardAgainst: RegExp(
        r'\b(assignment|homework|delivery|submission|#)\b',
      ),
    ),
    _GradeRegexEntry(
      regex: RegExp(r'\[[\d.]+\]\s*$'),
      itemType: gradeItem,
      confidence: 0.72,
      reason: 'Title ends with bracketed score/bucket value',
      guardAgainst: RegExp(
        r'\b(assignment|project|homework|report|task|delivery|submission)\b',
      ),
    ),
    _GradeRegexEntry(
      regex: RegExp(r'\(\s*\d+(\.\d+)?\s*%\s*\)\s*$'),
      itemType: gradeItem,
      confidence: 0.78,
      reason: 'Title ends with a percentage weight',
      guardAgainst: RegExp(
        r'\b(assignment|project|homework|report|task|delivery|submission)\b',
      ),
    ),
    _GradeRegexEntry(
      regex: RegExp(r'\b\d+(\.\d+)?\s*%\s*$'),
      itemType: gradeItem,
      confidence: 0.82,
      reason: 'Title ends with a percentage weight',
      guardAgainst: RegExp(
        r'\b(assignment|project|homework|report|task|delivery|submission)\b',
      ),
    ),
    _GradeRegexEntry(
      regex: RegExp(r'\b(assessment|rubric)\b'),
      itemType: dashboardOnly,
      confidence: 0.76,
      reason: 'Title is an assessment/rubric context row',
      guardAgainst: RegExp(
        r'\b(assignment|homework|submission|delivery|project|report|essay|outline)\b',
      ),
    ),
    _GradeRegexEntry(
      regex: RegExp(r'\bquiz(zes)?\b'),
      itemType: dashboardOnly,
      confidence: 0.72,
      reason: 'Title is a quiz/assessment row without deliverable wording',
      guardAgainst: RegExp(
        r'\b(assignment|homework|submission|delivery|project|report|prep|prepare|study|review|practice)\b',
      ),
    ),
    _GradeRegexEntry(
      regex: RegExp(r'\bmarking\b'),
      itemType: gradeItem,
      confidence: 0.88,
      reason: 'Title contains marking/assessment wording',
    ),
  ];

  static bool _hasActionableSignal(String titleLower) {
    return _actionableSignalRegex.hasMatch(titleLower) ||
        RegExp(r'phase\s*#\s*\d+\s*:').hasMatch(titleLower);
  }

  static final RegExp _actionableSignalRegex = RegExp(
    r'\b(assignment|project|task|homework|report|delivery|submissions?|'
    r'practical|exercise|case\s+study|mini\s*project|presentation|'
    r'proposal|paper|essay|worksheet|lab\s*report)\b',
  );

  static void _logClassificationSummary(List<Task> tasks) {
    final counts = <String, int>{};
    for (final task in tasks) {
      counts[task.itemType] = (counts[task.itemType] ?? 0) + 1;
    }
    final actionableCount = tasks.where(isActionableForAI).length;

    debugPrint(
      '[Classifier] Classified ${tasks.length} items: '
      '${counts.entries.map((e) => '${e.key}: ${e.value}').join(', ')} '
      '| actionable for AI: $actionableCount',
    );
  }
}

class _GradeMatchResult {
  final String itemType;
  final double confidence;
  final String reason;

  const _GradeMatchResult({
    required this.itemType,
    required this.confidence,
    required this.reason,
  });
}

class _GradeRegexEntry {
  final RegExp regex;
  final String itemType;
  final double confidence;
  final String reason;
  final RegExp? guardAgainst;

  const _GradeRegexEntry({
    required this.regex,
    required this.itemType,
    required this.confidence,
    required this.reason,
    this.guardAgainst,
  });
}
