import 'package:firebase_core/firebase_core.dart';
import 'package:flourish_web/app.dart';
import 'package:flourish_web/app_state.dart';
import 'package:flourish_web/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';

void main() async {
  await dotenv.load(fileName: ".env"); //load environmental variables

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  runApp(ChangeNotifierProvider(
    create: (context) => ApplicationState(),
    builder: ((context, child) => const Flourish()),
  ));
}
