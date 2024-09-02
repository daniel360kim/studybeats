import 'package:flourish_web/mobile_landing_page.dart';
import 'package:flourish_web/studyroom/study_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/simple/get_responsive.dart';
import 'package:get/get_state_manager/src/simple/get_view.dart';
import 'package:get/utils.dart';

class Flourish extends StatelessWidget {
  const Flourish({super.key});

  @override
  Widget build(BuildContext context) {
    bool isTablet = context.isTablet;
    bool isPhone = context.isPhone;

    bool isMobile = GetPlatform.isMobile;

    bool isPortrait = context.isPortrait;

    Widget initialPage;

    if (isPhone || isMobile || isPortrait) {
      initialPage = const MobileLandingPage();
    } else {
      initialPage = const StudyRoom();
    }
    return MaterialApp(
      title: 'Flourish',
      home: initialPage, //TODO check if signed in
    );
  }
}
