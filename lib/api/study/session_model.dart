import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/api/todo/todo_item.dart';
import 'package:studybeats/api/todo/todo_service.dart';
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

  Duration get accumulatedStudyDuration => _accumulatedStudyDuration;
  Duration get accumulatedBreakDuration => _accumulatedBreakDuration;

  DateTime get startTime => _startTime;

  StudySession? _endedSession;
  StudySession? get endedSession => _endedSession;

  final _logger = getLogger('Focus Session Model');
  final List<Future<void> Function()> _onSessionEndCallbacks = [];

  void addOnSessionEndCallback(Future<void> Function() callback) {
    _onSessionEndCallbacks.add(callback);
  }

  void removeOnSessionEndCallback(Future<void> Function() callback) {
    _onSessionEndCallbacks.remove(callback);
  }

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
    _endedSession = null;
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
    notifyListeners();
    await service.updateSession(updatedSession);
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
    _timer = Timer.periodic(const Duration(milliseconds: 500), _updateTimer);
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
    _timer = Timer.periodic(const Duration(milliseconds: 500), _updateTimer);
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
        notifyListeners();
        _logger.i(
            'Focus phase completed. Accumulated study duration: $_accumulatedStudyDuration');
        _startBreakTimer();
        if (onPhaseTransition != null) {
          onPhaseTransition!(SessionPhase.breakTime);
        }
      } else {
        _accumulatedBreakDuration += phaseElapsed;
        notifyListeners();
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
      _logger.i('Skipping study phase. Focus time added: $elapsed');
      _startBreakTimer();
      if (onPhaseTransition != null) onPhaseTransition!(SessionPhase.breakTime);
    } else {
      _accumulatedBreakDuration += elapsed;
      _logger.i('Skipping break phase. Focus time added: $elapsed');
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
  Future<void> endSession(StudySessionService sessionService) async {
    if (_currentSession == null) {
      throw Exception('No active session to end.');
    }
    await SystemChrome.setApplicationSwitcherDescription(
      const ApplicationSwitcherDescription(
        label: 'Studybeats',
      ),
    );

    for (var callback in _onSessionEndCallbacks) {
      await callback();
    }
    try {
      int numCompletedTodos = 0;
      final todoService = TodoService();
      await todoService.init();
      for (var todoReference in _currentSession!.todos) {
        try {
          TodoItem todoItem = await todoService.getTodoItem(
              todoReference.todoListId, todoReference.todoId);
          if (todoItem.isDone) {
            await todoService.markTodoItemAsDone(
                listId: todoReference.todoListId,
                todoItemId: todoReference.todoId);
            numCompletedTodos++;
          }
        } catch (e) {
          _logger.w('Skipping todo due to error: $e');
          continue;
        }
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
          todos: _currentSession!.todos,
          sessionRating: _currentSession!.sessionRating,
          soundFxId: _currentSession!.soundFxId,
          soundEnabled: _currentSession!.soundEnabled,
          actualStudyDuration: _accumulatedStudyDuration,
          actualBreakDuration: _accumulatedBreakDuration,
          numCompletedTasks: numCompletedTodos);
      await sessionService.endSession(updatedSession);
      _logger.i(
          'Session ended. Total accumulated study: $_accumulatedStudyDuration, break: $_accumulatedBreakDuration');

      _currentSession = null;
      _endedSession = updatedSession;
    } catch (e) {
      _logger.e('Error ending session: $e');
    }
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

  void addTodoItemToSession(SessionTodoReference todo) {
    if (_currentSession == null) {
      throw Exception('No active session to add todo item.');
    }
    if (_currentSession!.todos.any((item) => item.todoId == todo.todoId)) {
      return;
    }
    _currentSession!.todos.add(todo);
    notifyListeners();
  }

  void removeTodoItemFromSession(SessionTodoReference todo) {
    if (_currentSession == null) {
      throw Exception('No active session to remove todo item.');
    }
    if (!_currentSession!.todos.any((item) => item.todoId == todo.todoId)) {
      return;
    }
    _currentSession!.todos.removeWhere((item) => item.todoId == todo.todoId);
    notifyListeners();
  }

  void setSelectedTodos(Set<SessionTodoReference> selectedTodos) {
    if (_currentSession == null) {
      throw Exception('No active session to set selected todos.');
    }
    _currentSession!.todos = selectedTodos;
    notifyListeners();
  }
}
