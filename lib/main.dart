import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:studybeats/api/spotify/spotify_auth_service.dart';
import 'package:studybeats/api/study/session_model.dart';
import 'package:studybeats/app.dart';
import 'package:studybeats/app_state.dart';
import 'package:studybeats/firebase_options.dart';
import 'package:studybeats/secrets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:studybeats/studyroom/audio/audio_state.dart';
import 'package:studybeats/studyroom/audio/display_track_notifier.dart';
import 'package:studybeats/studyroom/playlist_notifier.dart';
import 'package:studybeats/studyroom/side_tiles/tile_screen_controller.dart';
import 'package:studybeats/studyroom/study_tools/study_toolbar_controller.dart';
import 'package:url_strategy/url_strategy.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    FlutterNativeSplash.remove();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    setPathUrlStrategy();
    await SentryFlutter.init((options) {
      options.dsn = SENTRY_DSN;
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      options.profilesSampleRate = 1.0;
    });
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => ApplicationState()),
          ChangeNotifierProvider(create: (context) => PlaylistNotifier()),
          ChangeNotifierProvider(create: (context) => StudySessionModel()),
          ChangeNotifierProvider(create: (_) => SpotifyAuthService()),
          ChangeNotifierProvider(create: (_) => AudioSourceSelectionProvider()),
          ChangeNotifierProvider(create: (_) => SidePanelController()),
          ChangeNotifierProvider(create: (_) => DisplayTrackNotifier()),
          ChangeNotifierProvider(create: (_) => StudyToolbarController()),
        ],
        child: const Studybeats(),
      ),
    );
  }, (Object exception, StackTrace stackTrace) async {
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
}
