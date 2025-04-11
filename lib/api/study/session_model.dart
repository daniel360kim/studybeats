// File: /Users/danielkim/Documents/Documents - DK's MacBook Pro/Projects/Study Beats/app/lib/api/study/session_model.dart

import 'package:flutter/material.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/log_printer.dart';
import 'objects.dart';

/// The [StudySessionModel] manages the lifecycle of a study session,
/// including explicit control over break and study pause periods.
/// 
/// The model tracks:
/// - Break periods: using [startBreak] and [endBreak].
/// - Study pauses: using [pauseStudy] and [resumeStudy].
/// 
/// The actual study time is computed as:
///   total elapsed time - (accumulated break time + accumulated pause time)
/// 
/// Methods are guarded to ensure valid transitions. For instance:
/// - [pauseStudy] cannot be called if no session is active or if already paused.
/// - [pauseStudy] will also refuse to run if a break is in progress.
/// 
/// Usage:
///   - Call [startSession] to begin a session.
///   - Use [startBreak] and [endBreak] for break events.
///   - Use [pauseStudy] and [resumeStudy] to control explicit study pausing.
///   - Access [actualStudyDuration] and [actualBreakDuration] for precise metrics.
///   - Call [endSession] to finalize and record the session.
class StudySessionModel extends ChangeNotifier {
  StudySession? _currentSession;

  // Private fields for break tracking.
  DateTime? _currentBreakStart;
  Duration _accumulatedBreakDuration = Duration.zero;

  // Private fields for study pause tracking.
  bool _isStudyPaused = false;
  DateTime? _currentPauseStart;
  Duration _accumulatedPauseDuration = Duration.zero;

  StudySessionModel();

  /// Returns the currently active session.
  StudySession? get currentSession => _currentSession;

  /// Returns true if a session is active.
  bool get isActive => _currentSession != null;

  /// Returns true if the user is currently on a break.
  bool get isOnBreak => _currentBreakStart != null;

  /// Returns true if the user has paused the study.
  bool get isStudyPaused => _isStudyPaused;

  /// Calculates the total accumulated break duration,
  /// including any in-progress break.
  Duration get actualBreakDuration {
    if (_currentBreakStart != null) {
      return _accumulatedBreakDuration +
          DateTime.now().difference(_currentBreakStart!);
    }
    return _accumulatedBreakDuration;
  }

  /// Calculates the total accumulated pause duration,
  /// including any in-progress pause.
  Duration get actualPauseDuration {
    if (_currentPauseStart != null) {
      return _accumulatedPauseDuration +
          DateTime.now().difference(_currentPauseStart!);
    }
    return _accumulatedPauseDuration;
  }

  /// Computes the actual study duration as the total elapsed time
  /// minus both the actual break duration and the actual pause duration.
  Duration get actualStudyDuration {
    if (_currentSession == null) return Duration.zero;
    final totalElapsed = DateTime.now().difference(_currentSession!.startTime);
    return totalElapsed - actualBreakDuration - actualPauseDuration;
  }

  final _logger = getLogger('Study Session Model');

  /// Starts a new study session.
  /// Resets break and pause tracking.
  /// Throws a warning if a session is already active.
  Future<void> startSession(
      StudySession session, StudySessionService service) async {
    if (_currentSession != null) {
      _logger.w(
          'A session is already active. End the current session before starting a new one.');
      return;
    }
    await service.createSession(session);
    _currentSession = session;
    _currentBreakStart = null;
    _accumulatedBreakDuration = Duration.zero;
    _isStudyPaused = false;
    _currentPauseStart = null;
    _accumulatedPauseDuration = Duration.zero;
    notifyListeners();
  }

  /// Updates the current session.
  Future<void> updateSession(
      StudySession updatedSession, StudySessionService service) async {
    if (_currentSession == null) {
      throw Exception('No active session.');
    }
    _currentSession = updatedSession;
    await service.updateSession(updatedSession);
    notifyListeners();
  }

  /// Marks the start of a break.
  /// Does nothing if there's no active session or if already on break.
  void startBreak() {
    if (_currentSession == null) {
      _logger.w('No active session to start a break.');
      return;
    }
    if (!isOnBreak) {
      _currentBreakStart = DateTime.now();
      _logger.i('Break started at $_currentBreakStart');
      notifyListeners();
    }
  }

  /// Ends the current break, accumulating its duration.
  /// Does nothing if no break is active.
  void endBreak() {
    if (isOnBreak) {
      final breakInterval = DateTime.now().difference(_currentBreakStart!);
      _accumulatedBreakDuration += breakInterval;
      _logger.i('Break ended; interval: $breakInterval, total accumulated: $_accumulatedBreakDuration');
      _currentBreakStart = null;
      notifyListeners();
    }
  }

  /// Convenience method to toggle between break and study state.
  void toggleBreak() {
    if (isOnBreak) {
      endBreak();
    } else {
      startBreak();
    }
  }

  /// Pauses the study session.
  /// Cannot be called if no session is active or if already paused or if a break is ongoing.
  void pauseStudy() {
    if (_currentSession == null) {
      _logger.w("No active session to pause study.");
      return;
    }
    if (_isStudyPaused) {
      _logger.w("Study is already paused.");
      return;
    }
    if (isOnBreak) {
      _logger.w("Cannot pause study while on a break.");
      return;
    }
    _isStudyPaused = true;
    _currentPauseStart = DateTime.now();
    _logger.i("Study paused at $_currentPauseStart");
    notifyListeners();
  }

  /// Resumes the study session from a paused state.
  /// Adds the pause interval to the accumulated pause duration.
  void resumeStudy() {
    if (_currentSession == null) {
      _logger.w("No active session to resume study.");
      return;
    }
    if (!_isStudyPaused) {
      _logger.w("Study is not paused.");
      return;
    }
    final pauseInterval = DateTime.now().difference(_currentPauseStart!);
    _accumulatedPauseDuration += pauseInterval;
    _logger.i("Study resumed; interval: $pauseInterval, total pause: $_accumulatedPauseDuration");
    _currentPauseStart = null;
    _isStudyPaused = false;
    notifyListeners();
  }

  /// Ends the current session.
  /// If a break or pause is active, ends them first.
  /// Computes actual study duration as total elapsed time minus actual break and pause durations.
  /// Updates the session document via [service] and resets internal state.
  Future<void> endSession(StudySessionService service) async {
    if (_currentSession == null) {
      throw Exception('No active session to end.');
    }

    // If a break is active, end it.
    if (isOnBreak) {
      endBreak();
    }
    // If the study is paused, resume it (to include paused time).
    if (_isStudyPaused) {
      resumeStudy();
    }
    final totalElapsed = DateTime.now().difference(_currentSession!.startTime);
    final actualStudy = totalElapsed - _accumulatedBreakDuration - _accumulatedPauseDuration;

    // Create an updated session with actual durations.
    _currentSession = StudySession(
      id: _currentSession!.id,
      title: _currentSession!.title,
      startTime: _currentSession!.startTime,
      updatedTime: DateTime.now(),
      endTime: DateTime.now(),
      studyDuration: _currentSession!.studyDuration,
      breakDuration: _currentSession!.breakDuration,
      todoIds: _currentSession!.todoIds,
      sessionRating: _currentSession!.sessionRating,
      soundFxId: _currentSession!.soundFxId,
      soundEnabled: _currentSession!.soundEnabled,
      isLoopSession: _currentSession!.isLoopSession,
      actualStudyDuration: actualStudy,
      actualBreakDuration: _accumulatedBreakDuration,
    );
    await service.endSession(_currentSession!);
    _logger.i(
        'Session ended. Total elapsed: $totalElapsed, Actual Study: $actualStudy, Actual Break: $_accumulatedBreakDuration, Actual Pause: $_accumulatedPauseDuration');
    _currentSession = null;
    // Reset break and pause tracking.
    _currentBreakStart = null;
    _accumulatedBreakDuration = Duration.zero;
    _currentPauseStart = null;
    _accumulatedPauseDuration = Duration.zero;
    _isStudyPaused = false;
    notifyListeners();
  }
}