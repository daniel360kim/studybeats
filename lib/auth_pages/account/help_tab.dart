// tabs/help_tab.dart
import 'package:flutter/material.dart';
import 'package:studybeats/colors.dart';

class HelpTab extends StatelessWidget {
  const HelpTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Help Content',
        style: TextStyle(color: kFlourishAliceBlue, fontSize: 16),
      ),
    );
  }
}