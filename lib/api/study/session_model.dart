// File: /Users/danielkim/Documents/Documents - DK's MacBook Pro/Projects/Study Beats/app/lib/api/study/session_model.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/log_printer.dart';
import 'objects.dart';

enum SessionPhase {
  studyTime,
  breakTime,
}

/// The [StudySessionModel] manages the lifecycle of a study session, including basic countdown
/// functionality and phase transitions (study & break). It now also accumulates the total
/// study duration and break duration over the entire session. When a phase completes (or when
/// the session ends), the elapsed time for that phase is added to the respective accumulator.
///
/// Example Usage:
///   studySessionModel.startSession(session, studySessionService);
///   // As time passes, transitions occur automatically.
///   // When ending the session, call:
///   studySessionModel.endSession(studySessionService);
///   // The updated StudySession will include actualStudyDuration and actualBreakDuration.
class StudySessionModel extends ChangeNotifier {
  StudySession? _currentSession; // The currently active study session.
  SessionPhase _currentPhase = SessionPhase.studyTime;
  SessionPhase get currentPhase => _currentPhase;

  // Async callbacks for external listeners.
  Future<void> Function(SessionPhase newPhase)? onPhaseTransition;
  Future<void> Function()? onSessionEnd;
  Future<void> Function()? onTimerTick;

  late Timer _timer;
  late DateTime _startTime;
  late Duration _totalDuration;

  // This variable holds the current remaining time of the active phase.
  Duration _remainingTime = const Duration();
  Duration get remainingTime => _remainingTime;

  // New fields to accumulate the actual time spent in study and break phases.
  Duration _accumulatedStudyDuration = Duration.zero;
  Duration _accumulatedBreakDuration = Duration.zero;

  final _logger = getLogger('Study Session Model');

  StudySessionModel();

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Returns the currently active study session.
  StudySession? get currentSession => _currentSession;

  /// Returns true if a study session is currently active.
  bool get isActive => _currentSession != null;

  /// Starts a new study session.
  ///
  /// Resets all phase tracking and accumulators.
  Future<void> startSession(
      StudySession session, StudySessionService service) async {
    if (_currentSession != null) {
      _logger.w(
          'A session is already active. End the current session before starting a new one.');
      return;
    }
    await service.createSession(session);
    _currentSession = session;
    _currentPhase = SessionPhase.studyTime;
    _remainingTime = session.studyDuration;
    _startTime = DateTime.now();

    // Reset accumulators.
    _accumulatedStudyDuration = Duration.zero;
    _accumulatedBreakDuration = Duration.zero;

    _logger.i('Session started: ${session.title}');
    _startFocusTimer();
    notifyListeners();
  }

  /// Updates the current session document.
  Future<void> updateSession(
      StudySession updatedSession, StudySessionService service) async {
    if (_currentSession == null) {
      throw Exception('No active session.');
    }
    _currentSession = updatedSession;
    await service.updateSession(updatedSession);
    notifyListeners();
  }

  /// Starts the timer for the study phase.
  void _startFocusTimer() {
    _remainingTime = _currentSession!.studyDuration;
    _currentPhase = SessionPhase.studyTime;
    _startTimer();
  }

  /// Starts the timer for the break phase.
  void _startBreakTimer() {
    _remainingTime = _currentSession!.breakDuration;
    _currentPhase = SessionPhase.breakTime;
    _startTimer();
  }

  /// Common helper to start the periodic timer.
  void _startTimer() {
    _totalDuration = _remainingTime;
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
  }

  /// Pauses the countdown timer.
  void pauseTimer() {
    _timer.cancel();
    notifyListeners();
  }

  /// Resumes the countdown timer using the current remaining time.
  /// (Resets the _startTime to now so that the timer continues from the paused remainder.)
  void resumeTimer() {
    _startTime = DateTime.now();
    _totalDuration = _remainingTime;
    _timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
    notifyListeners();
  }

  /// Updates the timer on each tick.
  /// If the remaining time reaches zero, cancels the timer,
  /// updates the accumulated time for the current phase,
  /// switches to the next phase, and starts the timer for that phase.
  void _updateTimer(Timer timer) {
    final elapsed = DateTime.now().difference(_startTime);
    final remaining = _totalDuration - elapsed;

    if (remaining.inSeconds <= 0) {
      // Phase is complete.
      _timer.cancel();
      final phaseElapsed = DateTime.now().difference(_startTime);

      if (_currentPhase == SessionPhase.studyTime) {
        _accumulatedStudyDuration += phaseElapsed;
        _logger.i(
            'Study phase completed. Accumulated study duration: $_accumulatedStudyDuration');
        _startBreakTimer();
        if (onPhaseTransition != null) {
          onPhaseTransition!(SessionPhase.breakTime);
        }
      } else {
        _accumulatedBreakDuration += phaseElapsed;
        _logger.i(
            'Break phase completed. Accumulated break duration: $_accumulatedBreakDuration');
        _startFocusTimer();
        if (onPhaseTransition != null) {
          onPhaseTransition!(SessionPhase.studyTime);
        }
      }
    } else {
      _remainingTime = remaining;
    }
    notifyListeners();
  }

  /// Skips the current phase (study or break) and immediately transitions to the next phase.
  ///
  /// If in study mode, skips to break.
  /// If in break mode, skips to study.
  void skipCurrentPhase() {
    _timer.cancel();
    final now = DateTime.now();
    final elapsed = now.difference(_startTime);
    if (_currentPhase == SessionPhase.studyTime) {
      _accumulatedStudyDuration += elapsed;
      _logger.i('Skipping study phase. Study time added: $elapsed');
      _startBreakTimer();
      if (onPhaseTransition != null) onPhaseTransition!(SessionPhase.breakTime);
    } else {
      _accumulatedBreakDuration += elapsed;
      _logger.i('Skipping break phase. Break time added: $elapsed');
      _startFocusTimer();
      if (onPhaseTransition != null) onPhaseTransition!(SessionPhase.studyTime);
    }
    notifyListeners();
  }

  /// Ends the current session.
  ///
  /// If a timer is still running, cancels it and adds the current phase’s elapsed time
  /// to the corresponding accumulator.
  /// Then creates an updated StudySession with the total accumulated study
  /// and break durations, calls the service to save the session,
  /// and resets the model’s state.
  Future<void> endSession(StudySessionService service) async {
    if (_currentSession == null) {
      throw Exception('No active session to end.');
    }

    if (onSessionEnd != null) {
      await onSessionEnd!();
    }
    _timer.cancel();
    final phaseElapsed = DateTime.now().difference(_startTime);
    if (_currentPhase == SessionPhase.studyTime) {
      _accumulatedStudyDuration += phaseElapsed;
    } else {
      _accumulatedBreakDuration += phaseElapsed;
    }
    final updatedSession = StudySession(
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
      actualStudyDuration: _accumulatedStudyDuration,
      actualBreakDuration: _accumulatedBreakDuration,
    );
    await service.endSession(updatedSession);
    _logger.i(
        'Session ended. Total accumulated study: $_accumulatedStudyDuration, break: $_accumulatedBreakDuration');
    _currentSession = null;
    notifyListeners();
  }

  /// Returns the progress of the current phase as a value between 0.0 and 1.0.
  double getProgress() {
    if (_currentSession == null) return 0.0;
    int plannedSeconds = _currentPhase == SessionPhase.studyTime
        ? _currentSession!.studyDuration.inSeconds
        : _currentSession!.breakDuration.inSeconds;
    if (plannedSeconds == 0) {
      return 0.0;
    }
    return _remainingTime.inSeconds / plannedSeconds;
  }
}
