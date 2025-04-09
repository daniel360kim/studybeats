import 'package:flutter/material.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/log_printer.dart';
import 'objects.dart';

class StudySessionModel extends ChangeNotifier {
  StudySession? _currentSession;

  StudySessionModel();

  StudySession? get currentSession => _currentSession;
  bool get isActive => _currentSession != null;

  final _logger = getLogger('Study Session Model');

  // Start a new session, ensuring only one session is active.
  Future<void> startSession(
      StudySession session, StudySessionService service) async {
    if (_currentSession != null) {
      _logger.w(
          'A session is already active. End the current session before starting a new one.');
      return;
    }
    await service.createSession(session);
    _currentSession = session;
    notifyListeners();
  }

  // Update the current session.
  Future<void> updateSession(
      StudySession updatedSession, StudySessionService service) async {
    if (_currentSession == null) {
      throw Exception('No active session.');
    }
    _currentSession = updatedSession;
    await service.updateSession(updatedSession);
    notifyListeners();
  }

  // End the current session.
  Future<void> endSession(StudySessionService service) async {
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
    await service.endSession(_currentSession!);
    _currentSession = null;
    notifyListeners();
  }

  // Optionally, you could include a method to load a session from Firestore if needed.
}
