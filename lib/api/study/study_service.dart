import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:studybeats/api/study/objects.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/log_printer.dart';

class StudySessionService {
  final _authService = AuthService();
  final _logger = getLogger('Focus Session Service');

  late final CollectionReference<Map<String, dynamic>> _studySessionCollection;
  late final CollectionReference<Map<String, dynamic>>
      _studyStatisticsCollection;

  late final Future<void> _initialization = _initialize();

  /// Public API: callers await this, but assignment happens only once.
  Future<void> init() => _initialization;

  /// The real init logic; runs exactly once.
  Future<void> _initialize() async {
    final email = await _getUserEmail();
    final userDoc = FirebaseFirestore.instance.collection('users').doc(email);
    _studySessionCollection = userDoc.collection('studySessions');
    _studyStatisticsCollection = userDoc.collection('studyStatistics');
    // no boolean needed, no second assignment possible
  }

  /// Retrieves the current user's email.
  Future<String> _getUserEmail() async {
    try {
      final email = await _authService.getCurrentUserEmail();
      if (email != null) {
        return email;
      } else {
        _logger.e('User email is null');
        throw Exception('User email is null');
      }
    } catch (e, s) {
      _logger.e('Failed to get user email: $e $s');
      rethrow;
    }
  }

  /// Creates a new study session document in Firestore.
  Future<void> createSession(StudySession session) async {
    try {
      _logger.i('Creating study session');
      await _studySessionCollection.doc(session.id).set(session.toJson());
    } catch (e, s) {
      _logger.e('Failed to create study session: $e $s');
      rethrow;
    }
  }

  /// Updates an existing study session document in Firestore.
  Future<void> updateSession(StudySession session) async {
    try {
      _logger.i('Updating study session');
      await _studySessionCollection.doc(session.id).update(session.toJson());
    } catch (e, s) {
      _logger.e('Failed to update study session: $e $s');
      rethrow;
    }
  }

  /// Ends a study session by ensuring the [endTime] is set and statistics are updated.
  /// If [session.endTime] is null, it uses the [updatedTime] as the end time.
  Future<void> endSession(StudySession session) async {
    try {
      _logger.i('Ending study session');
      if (session.endTime == null) {
        session = StudySession(
          id: session.id,
          title: session.title,
          startTime: session.startTime,
          updatedTime: session.updatedTime,
          endTime: session.updatedTime,
          studyDuration: session.studyDuration,
          breakDuration: session.breakDuration,
          todos: session.todos,
          sessionRating: session.sessionRating,
          soundFxId: session.soundFxId,
          soundEnabled: session.soundEnabled,
          // Use the actual durations computed from the session model.
          actualStudyDuration: session.actualStudyDuration,
          actualBreakDuration: session.actualBreakDuration,
        );
      }
      await updateSession(session);
      await _updateTotalStatistics(session, session.numCompletedTasks);
    } catch (e, s) {
      _logger.e('Failed to end study session: $e $s');
      rethrow;
    }
  }

// Locate the _updateTotalStatistics method in study_service.dart and update it as follows:

  Future<void> _updateTotalStatistics(
      StudySession session, int numCompletedTodos) async {
    final statsDocRef = _studyStatisticsCollection.doc('totalStats');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final statsSnapshot = await transaction.get(statsDocRef);
      if (!statsSnapshot.exists) {
        final newStats = StudyStatistics(
          totalStudyTime: session.actualStudyDuration, // Updated: use seconds.
          totalBreakTime: session.actualBreakDuration, // Updated: use seconds.
          totalSessions: 1,
          totalTodosCompleted: numCompletedTodos,
        );
        transaction.set(statsDocRef, newStats.toJson());
      } else {
        final currentData = statsSnapshot.data()!;
        final currentStats = StudyStatistics.fromJson(currentData);
        final updatedStats = StudyStatistics(
          totalStudyTime: currentStats.totalStudyTime +
              session.actualStudyDuration, // Updated
          totalBreakTime: currentStats.totalBreakTime +
              session.actualBreakDuration, // Updated
          totalSessions: currentStats.totalSessions + 1,
          totalTodosCompleted:
              currentStats.totalTodosCompleted + numCompletedTodos,
        );
        transaction.update(statsDocRef, updatedStats.toJson());
      }
    });
  }

  /// Retrieves aggregated study statistics for a given day.
  Future<StudyStatistics> getDailyStatistics(DateTime date) async {
    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = startOfDay.add(Duration(days: 1));
    return _getAggregatedStatistics(startOfDay, endOfDay);
  }

  /// Retrieves aggregated study statistics for a given week.
  Future<StudyStatistics> getWeeklyStatistics(DateTime date) async {
    DateTime startOfWeek = date.subtract(Duration(days: date.weekday));
    DateTime endOfWeek = startOfWeek.add(Duration(days: 7));
    return _getAggregatedStatistics(startOfWeek, endOfWeek);
  }

  /// Retrieves aggregated study statistics for a given month.
  Future<StudyStatistics> getMonthlyStatistics(DateTime date) async {
    DateTime startOfMonth = DateTime(date.year, date.month);
    DateTime endOfMonth = DateTime(date.year, date.month + 1);
    return _getAggregatedStatistics(startOfMonth, endOfMonth);
  }

  Future<StudyStatistics> getAllTimeStatistics() async {
    DateTime startOfTime = DateTime(2024, 12, 12);
    DateTime endOfTime = DateTime.now();
    return _getAggregatedStatistics(startOfTime, endOfTime);
  }

  /// Retrieves all study sessions sorted by startTime.
  Future<List<StudySession>> getAllSessions() async {
    await init();
    final snapshot = await _studySessionCollection.orderBy('startTime').get();
    return snapshot.docs
        .map((doc) => StudySession.fromJson(doc.data()))
        .toList();
  }

  Future<StudyStatistics> _getAggregatedStatistics(
      DateTime start, DateTime end) async {
    QuerySnapshot<Map<String, dynamic>> snapshot = await _studySessionCollection
        .where('startTime', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('startTime', isLessThan: end.toIso8601String())
        .get();

    int totalStudyTimeSeconds = 0;
    int totalBreakTimeSeconds = 0;
    int totalSessions = snapshot.docs.length;
    int totalTodosCompleted = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      // The stored values are in seconds.
      totalStudyTimeSeconds += data['actualStudyDuration'] as int;
      totalBreakTimeSeconds += data['actualBreakDuration'] as int;
      // Support both old 'todoIds' and new 'todos' fields, defaulting to empty list
      final todoList = (data['todos'] as List<dynamic>?) ??
          (data['todoIds'] as List<dynamic>?) ??
          [];
      totalTodosCompleted += todoList.length;
    }

    return StudyStatistics(
      totalStudyTime: Duration(seconds: totalStudyTimeSeconds),
      totalBreakTime: Duration(seconds: totalBreakTimeSeconds),
      totalSessions: totalSessions,
      totalTodosCompleted: totalTodosCompleted,
    );
  }

  /// Retrieves daily StudyStatistics for each day of a specified week offset.
  /// Each day's statistics include total study time, break time, session count, and todos completed.
  Future<Map<DateTime, StudyStatistics>> getWeeklyDailyStatistics({
    int weeksBack = 0,
  }) async {
    await init();
    _logger.i('Retrieving weekly daily statistics with weeksBack: $weeksBack');
    // Determine week boundaries
    final now = DateTime.now();
    final reference = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: weeksBack * 7));
    final daysToSubtract = reference.weekday % 7;
    final startOfWeek = DateTime(reference.year, reference.month, reference.day)
        .subtract(Duration(days: daysToSubtract));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    // Query sessions for the week
    final snapshot = await _studySessionCollection
        .where('startTime',
            isGreaterThanOrEqualTo: startOfWeek.toIso8601String())
        .where('startTime', isLessThan: endOfWeek.toIso8601String())
        .get();

    // Initialize map with empty stats
    final dailyStats = <DateTime, StudyStatistics>{};
    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final key = DateTime(day.year, day.month, day.day);
      dailyStats[key] = StudyStatistics(
        totalStudyTime: Duration.zero,
        totalBreakTime: Duration.zero,
        totalSessions: 0,
        totalTodosCompleted: 0,
      );
    }

    // Accumulate per-day statistics
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final dt = DateTime.parse(data['startTime'] as String);
      final key = DateTime(dt.year, dt.month, dt.day);

      final actualStudy = Duration(seconds: data['actualStudyDuration'] as int);
      final actualBreak = Duration(seconds: data['actualBreakDuration'] as int);
      final todoList = (data['todos'] as List<dynamic>?) ??
          (data['todoIds'] as List<dynamic>?) ??
          [];
      final sessionCount = 1;
      final todosCompleted = todoList.length;

      final existing = dailyStats[key]!;
      dailyStats[key] = StudyStatistics(
        totalStudyTime: existing.totalStudyTime + actualStudy,
        totalBreakTime: existing.totalBreakTime + actualBreak,
        totalSessions: existing.totalSessions + sessionCount,
        totalTodosCompleted: existing.totalTodosCompleted + todosCompleted,
      );
    }

    return dailyStats;
  }

  /// Returns the number of consecutive days up to today
  /// where the user has studied (totalStudyTime > 0).
  Future<int> getCurrentStreak() async {
    await init();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Define a lookback window (e.g., last 365 days)
    final maxLookback = 365;
    final startDate = today.subtract(Duration(days: maxLookback));
    // Query all sessions in that window in one call
    final snapshot = await _studySessionCollection
        .where('startTime', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('startTime',
            isLessThanOrEqualTo:
                today.add(const Duration(days: 1)).toIso8601String())
        .get();

    // Aggregate total study seconds per day
    final Map<DateTime, int> dailyStudySeconds = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final dt = DateTime.parse(data['startTime'] as String);
      final key = DateTime(dt.year, dt.month, dt.day);
      final seconds = data['actualStudyDuration'] as int? ?? 0;
      dailyStudySeconds.update(key, (prev) => prev + seconds,
          ifAbsent: () => seconds);
    }

    // Count consecutive days from today backwards
    int streak = 0;
    for (int offset = 0; offset < maxLookback; offset++) {
      final day = today.subtract(Duration(days: offset));
      final seconds = dailyStudySeconds[day] ?? 0;
      if (seconds > 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}

class TestDataInjector {
  final StudySessionService service;
  final Random _random = Random();

  TestDataInjector(this.service);

  final _logger = getLogger('Test Data Injector');

  /// Injects 28 days (4 weeks) of test StudySession data into Firestore.
  Future<void> injectTestData() async {
    await service.init();
    final now = DateTime.now();

    Duration totalStudyDurationInjected = Duration.zero;
    Duration totalBreakDurationInjected = Duration.zero;
    for (int i = 0; i < 28; i++) {
      final day = now.subtract(Duration(days: i));
      final studyMinutes = _random.nextInt(121); // 0–120 mins
      final breakMinutes = _random.nextInt(61); // 0–60 mins

      // Randomized start time between 8:00 and 16:59
      final startHour = 8 + _random.nextInt(9);
      final startMinute = _random.nextInt(60);
      final startTime = DateTime(
        day.year,
        day.month,
        day.day,
        startHour,
        startMinute,
      );

      final actualStudyDuration = Duration(minutes: studyMinutes);
      final actualBreakDuration = Duration(minutes: breakMinutes);
      final updatedTime =
          startTime.add(actualStudyDuration + actualBreakDuration);

      totalStudyDurationInjected += actualStudyDuration;
      totalBreakDurationInjected += actualBreakDuration;

      // Occasionally leave endTime null
      final endTime = i % 5 == 0 ? null : updatedTime;

      // Generate a few dummy tasks
      final taskCount = 1 + _random.nextInt(5);
      final todos = List<SessionTodoReference>.generate(taskCount, (idx) {
        return SessionTodoReference(
          todoId: 'todo_${i}_$idx',
          todoListId: 'list_${_random.nextInt(3)}',
        );
      });

      final session = StudySession(
        id: 'test_${day.toIso8601String()}',
        title: 'Test Session ${i + 1}',
        startTime: startTime,
        updatedTime: updatedTime,
        endTime: endTime,
        studyDuration: const Duration(minutes: 25), // or zero if not used
        breakDuration: const Duration(minutes: 5),
        todos: todos.toSet(),
        sessionRating: null,
        soundFxId: i % 4 == 0 ? null : _random.nextInt(10),
        soundEnabled: _random.nextBool(),
        actualStudyDuration: actualStudyDuration,
        actualBreakDuration: actualBreakDuration,
        themeColor: Colors.blue,
        numCompletedTasks: todos.where((t) => _random.nextBool()).length,
      );

      await service.createSession(session);
    }

    _logger.d('Injected test data for 28 days');
    _logger.d('Total Focus Duration Injected: $totalStudyDurationInjected');
    _logger.d('Total Break Duration Injected: $totalBreakDurationInjected');
  }
}
