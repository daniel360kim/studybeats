import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flourish_web/api/auth/signup_method.dart';
import 'package:flourish_web/log_printer.dart';
import 'package:flourish_web/router.dart';

/// Content type of the event that was logged
/// Signifies the event type that the user has selected
enum ContentType {
  aiChat,
  sceneSelect,
  studyTimer,
}

/// Analytics service class
/// Communicates events in the web app to Firebase Analytics
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final _logger = getLogger('AnalyticsService');

  /// Log a user login event
  Future<void> logLogin() async {
    try {
      await _analytics.logLogin();
      _logger.i('Login event logged');
    } catch (e, s) {
      _logger.e('Failed to log login event: $e $s');
    }
  }

  /// Log a signup event
  Future<void> logSignUp(SignupMethod signupMethod) async {
    try {
      await _analytics.logSignUp(signUpMethod: signupMethod.name);
      _logger.i('Sign-up event logged');
    } catch (e, s) {
      _logger.e('Failed to log sign-up event: $e $s');
    }
  }

  /// Logs an event that is popular or tracked to the analytics. The type is logged with [ContentType]
  Future<void> logOpenFeature(ContentType contentType, String itemId) async {
    try {
      await _analytics.logSelectContent(
          contentType: contentType.name, itemId: itemId);
      _logger.i('Feature "${contentType.name}" opened');
    } catch (e, s) {
      _logger.e(
          'Failed to log open feature event for "${contentType.name}": $e $s');
    }
  }

  /// Logs a new screen view when the web page changes
  /// Used in conjunction with a [ScreenViewObserver]. Whenever a screen view is popped,
  /// [ScreenViewObserver.didPop] is called and automatically calls this function
  ///
  /// TODO screen name and screen class send duplicate information. Differentiate these
  Future<void> logScreenView(
      {required String screenName, required String screenClass}) async {
    try {
      await _analytics.logScreenView(
          screenName: screenName, screenClass: screenClass);
      _logger.i('Screen view logged for "$screenName" in class "$screenClass"');
    } catch (e, s) {
      _logger.e(
          'Failed to log screen view for "$screenName" in class "$screenClass": $e $s');
    }
  }
}
