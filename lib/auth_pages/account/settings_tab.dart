// tabs/settings_tab.dart
import 'package:flutter/material.dart';
import 'package:studybeats/colors.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Settings Content',
        style: TextStyle(color: kFlourishAliceBlue, fontSize: 16),
      ),
    );
  }
}