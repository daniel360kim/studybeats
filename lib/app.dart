// Studybeats.dart
import 'package:studybeats/router.dart'; // Import the router configuration
import 'package:flutter/material.dart';

class Studybeats extends StatelessWidget {
  const Studybeats({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Study Beats',
      routerConfig: createRouter(context),
    );
  }
}
