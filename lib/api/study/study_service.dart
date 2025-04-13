import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:studybeats/api/study/objects.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/log_printer.dart';

class StudySessionService {
  final _authService = AuthService();
  final _logger = getLogger('Study Session Service');

  late final CollectionReference<Map<String, dynamic>> _studySessionCollection;
  late final CollectionReference<Map<String, dynamic>>
      _studyStatisticsCollection;

  bool _initialized = false;

  /// Initializes the service by retrieving the user's email and setting up
  /// the appropriate Firestore collections.
  Future<void> init() async {
    if (_initialized) return;

    final email = await _getUserEmail();
    final userDoc = FirebaseFirestore.instance.collection('users').doc(email);
    _studySessionCollection = userDoc.collection('studySessions');
    _studyStatisticsCollection = userDoc.collection('studyStatistics');
    _initialized = true;
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
          todoIds: session.todoIds,
          sessionRating: session.sessionRating,
          soundFxId: session.soundFxId,
          soundEnabled: session.soundEnabled,
          isLoopSession: session.isLoopSession,
          // Use the actual durations computed from the session model.
          actualStudyDuration: session.actualStudyDuration,
          actualBreakDuration: session.actualBreakDuration,
        );
      }
      await updateSession(session);
      await _updateTotalStatistics(session);
    } catch (e, s) {
      _logger.e('Failed to end study session: $e $s');
      rethrow;
    }
  }

// Locate the _updateTotalStatistics method in study_service.dart and update it as follows:

  Future<void> _updateTotalStatistics(StudySession session) async {
    final statsDocRef = _studyStatisticsCollection.doc('totalStats');
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final statsSnapshot = await transaction.get(statsDocRef);
      if (!statsSnapshot.exists) {
        final newStats = StudyStatistics(
          totalStudyTime: session.actualStudyDuration, // Updated: use seconds.
          totalBreakTime: session.actualBreakDuration, // Updated: use seconds.
          totalSessions: 1,
          totalTodosCompleted: session.todoIds.length,
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
              currentStats.totalTodosCompleted + session.todoIds.length,
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
      totalTodosCompleted += (data['todoIds'] as List).length;
    }

    return StudyStatistics(
      totalStudyTime: Duration(seconds: totalStudyTimeSeconds),
      totalBreakTime: Duration(seconds: totalBreakTimeSeconds),
      totalSessions: totalSessions,
      totalTodosCompleted: totalTodosCompleted,
    );
  }
}
