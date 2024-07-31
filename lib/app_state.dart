import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, PhoneAuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';

const List<String> scopes = [
  'email',
  'profile',
];

GoogleSignIn googleSignIn = GoogleSignIn(
  clientId: '400502053062-c2rpvv7lsi64l22pa5tm9i8u5gmmgeo2.apps.googleusercontent.com',
  scopes: scopes,
);

class ApplicationState extends ChangeNotifier {
  ApplicationState() {
    
    init();
  }

  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;

  Future<void> init() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    FirebaseUIAuth.configureProviders([
      EmailAuthProvider(),
      GoogleProvider(
          clientId:
              dotenv.env['GOOGLE_SIGNIN_CLIENT_ID']!,),
    ]);

    FirebaseAuth.instance.userChanges().listen((user) {
      if (user != null) {
        _loggedIn = true;
      } else {
        _loggedIn = false;
      }
      notifyListeners();
    });
  }
}
