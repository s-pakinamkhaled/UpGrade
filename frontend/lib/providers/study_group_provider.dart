import 'package:flutter/material.dart';

import '../models/study_group.dart';
import '../services/study_group_api_service.dart';

class StudyGroupProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isCreating = false;
  String? _error;
  List<StudyGroup> _groups = [];
  StudyGroupSuggestion? _latestSuggestion;
  List<Map<String, dynamic>> _latestCandidates = [];

  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get error => _error;
  List<StudyGroup> get groups => _groups;
  StudyGroupSuggestion? get latestSuggestion => _latestSuggestion;
  List<Map<String, dynamic>> get latestCandidates => _latestCandidates;

  Future<void> loadMyGroups(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _groups = await StudyGroupApiService.getMyGroups(userId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getSuggestions(
    StudyGroupRequestPayload payload, {
    List<Map<String, dynamic>>? candidateStudents,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _latestCandidates = candidateStudents ?? [];
      _latestSuggestion = await StudyGroupApiService.getSuggestions(
        payload,
        candidateStudents: candidateStudents,
      );
    } catch (e) {
      _error = e.toString();
      _latestSuggestion = null;
      _latestCandidates = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<StudyGroup?> createGroup({
    required StudyGroupRequestPayload payload,
    required List<SuggestedMember> selectedMembers,
    List<Map<String, dynamic>>? candidateStudents,
  }) async {
    _isCreating = true;
    _error = null;
    notifyListeners();
    try {
      final group = await StudyGroupApiService.createGroup(
        payload: payload,
        selectedMembers: selectedMembers,
        candidateStudents: candidateStudents ?? _latestCandidates,
      );
      _groups = [group, ..._groups];
      _latestSuggestion = null;
      _latestCandidates = [];
      return group;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(String groupId, StudyGroupStatus status) async {
    _error = null;
    notifyListeners();
    try {
      final updated = await StudyGroupApiService.updateGroupStatus(
        groupId: groupId,
        status: status,
      );
      _groups = _groups.map((g) => g.groupId == groupId ? updated : g).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      notifyListeners();
    }
  }
}
