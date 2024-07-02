import 'package:flourish_web/studyroom/study_page.dart';
import 'package:flutter/material.dart';

class Flourish extends StatelessWidget {
  const Flourish({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flourish',
      home: StudyRoom(), //TODO check if signed in
    );
  }
}
