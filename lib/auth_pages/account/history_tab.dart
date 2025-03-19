// tabs/history_tab.dart
import 'package:flutter/material.dart';
import 'package:studybeats/colors.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'History Content',
        style: TextStyle(color: kFlourishAliceBlue, fontSize: 16),
      ),
    );
  }
}