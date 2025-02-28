// Studybeats.dart
import 'package:flutter_quill/flutter_quill.dart';
import 'package:studybeats/router.dart'; // Import the router configuration
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class Studybeats extends StatelessWidget {
  const Studybeats({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Studybeats',
      routerConfig: createRouter(context),
    );
  }
}
