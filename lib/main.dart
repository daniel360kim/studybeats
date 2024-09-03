import 'package:firebase_core/firebase_core.dart';
import 'package:flourish_web/app.dart';
import 'package:flourish_web/app_state.dart';
import 'package:flourish_web/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_strategy/url_strategy.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  setPathUrlStrategy();

  runApp(ChangeNotifierProvider(
    create: (context) => ApplicationState(),
    builder: ((context, child) => const Flourish()),
  ));
}
