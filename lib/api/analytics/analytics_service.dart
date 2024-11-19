import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flourish_web/api/auth/signup_method.dart';
import 'package:flourish_web/log_printer.dart';

enum ContentType {
  aiChat,
  sceneSelect,
  studyTimer,
}

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final _logger = getLogger('AnalyticsService');

  Future<void> logLogin() async {
    try {
      await _analytics.logLogin();
      _logger.i('Login event logged');
    } catch (e, s) {
      _logger.e('Failed to log login event: $e $s');
    }
  }

  Future<void> logSignUp(SignupMethod signupMethod) async {
    try {
      await _analytics.logSignUp(signUpMethod: signupMethod.name);
      _logger.i('Sign-up event logged');
    } catch (e, s) {
      _logger.e('Failed to log sign-up event: $e $s');
    }
  }

  Future<void> logOpenFeature(ContentType contentType, String itemId) async {
    try {
      await _analytics.logSelectContent(
          contentType: contentType.name, itemId: itemId);
      _logger.i('Feature "${contentType.name}" opened');
    } catch (e, s) {
      _logger.e('Failed to log open feature event for "${contentType.name}": $e $s');
    }
  }

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
