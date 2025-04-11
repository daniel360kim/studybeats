import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:studybeats/api/study/objects.dart';
import 'package:studybeats/api/auth/auth_service.dart';
import 'package:studybeats/log_printer.dart';

class StudySessionService {
  final _authService = AuthService();
  final _logger = getLogger('Study Session Service');

  late final CollectionReference<Map<String, dynamic>> _studySessionCollection;
  late final CollectionReference<Map<String, dynamic>> _studyStatisticsCollection;

  /// Initializes the service by retrieving the user's email and setting up
  /// the appropriate Firestore collections.
  Future<void> init() async {
    try {
      final email = await _getUserEmail();
      final userDoc = FirebaseFirestore.instance.collection('users').doc(email);
      _studySessionCollection = userDoc.collection('studySessions');
      _studyStatisticsCollection = userDoc.collection('studyStatistics');
    } catch (e, s) {
      _logger.e('Failed to initialize study session service: $e $s');
      rethrow;
    }
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

  /// Updates the overall statistics document in Firestore with the session information.
  /// This uses the actual durations instead of the planned ones.
  Future<void> _updateTotalStatistics(StudySession session) async {
    final statsDocRef = _studyStatisticsCollection.doc('totalStats');
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final statsSnapshot = await transaction.get(statsDocRef);
      if (!statsSnapshot.exists) {
        final newStats = StudyStatistics(
          totalStudyTime: session.actualStudyDuration.inMinutes,
          totalBreakTime: session.actualBreakDuration.inMinutes,
          totalSessions: 1,
          totalTodosCompleted: session.todoIds.length,
        );
        transaction.set(statsDocRef, newStats.toJson());
      } else {
        final currentData = statsSnapshot.data()!;
        final currentStats = StudyStatistics.fromJson(currentData);
        final updatedStats = StudyStatistics(
          totalStudyTime: currentStats.totalStudyTime + session.actualStudyDuration.inMinutes,
          totalBreakTime: currentStats.totalBreakTime + session.actualBreakDuration.inMinutes,
          totalSessions: currentStats.totalSessions + 1,
          totalTodosCompleted: currentStats.totalTodosCompleted + session.todoIds.length,
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

  /// Helper method that aggregates statistics for sessions within a given date range.
  Future<StudyStatistics> _getAggregatedStatistics(DateTime start, DateTime end) async {
    QuerySnapshot<Map<String, dynamic>> snapshot = await _studySessionCollection
        .where('startTime', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('startTime', isLessThan: end.toIso8601String())
        .get();

    int totalStudyTime = 0;
    int totalBreakTime = 0;
    int totalSessions = snapshot.docs.length;
    int totalTodosCompleted = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      // Here we assume the stored values for studyDuration and breakDuration now represent
      // the actual durations, otherwise adjust accordingly.
      totalStudyTime += data['actualStudyDuration'] as int;
      totalBreakTime += data['actualBreakDuration'] as int;
      totalTodosCompleted += (data['todoIds'] as List).length;
    }

    return StudyStatistics(
      totalStudyTime: totalStudyTime,
      totalBreakTime: totalBreakTime,
      totalSessions: totalSessions,
      totalTodosCompleted: totalTodosCompleted,
    );
  }
}