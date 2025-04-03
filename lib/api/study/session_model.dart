import 'package:flutter/material.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'objects.dart';


class StudySessionModel extends ChangeNotifier {
  final StudySessionService _service;
  StudySession? _currentSession;

  StudySessionModel(this._service);

  StudySession? get currentSession => _currentSession;
  bool get isActive => _currentSession != null;

  // Start a new session, ensuring only one session is active.
  Future<void> startSession(StudySession session) async {
    if (_currentSession != null) {
      throw Exception('A session is already active.');
    }
    await _service.createSession(session);
    _currentSession = session;
    notifyListeners();
  }

  // Update the current session.
  Future<void> updateSession(StudySession updatedSession) async {
    if (_currentSession == null) {
      throw Exception('No active session.');
    }
    _currentSession = updatedSession;
    await _service.updateSession(updatedSession);
    notifyListeners();
  }

  // End the current session.
  Future<void> endSession() async {
    if (_currentSession == null) {
      throw Exception('No active session to end.');
    }

    // If the session has no endTime, use the updatedTime as a fallback.
    if (_currentSession!.endTime == null) {
      _currentSession = StudySession(
        id: _currentSession!.id,
        title: _currentSession!.title,
        startTime: _currentSession!.startTime,
        updatedTime: _currentSession!.updatedTime,
        endTime: _currentSession!.updatedTime,
        studyDuration: _currentSession!.studyDuration,
        breakDuration: _currentSession!.breakDuration,
        todoIds: _currentSession!.todoIds,
      );
    }
    await _service.endSession(_currentSession!);
    _currentSession = null;
    notifyListeners();
  }

  // Optionally, you could include a method to load a session from Firestore if needed.
}