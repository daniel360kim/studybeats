import 'package:card_swiper/card_swiper.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/studyroom/control_bar.dart';
import 'package:studybeats/studyroom/study_tools/study_session/page_controller.dart';
import 'package:studybeats/theme_provider.dart';

/// A Pomodoro Timer widget that displays aggregated statistics and opens a
/// page for creating new study sessions when the start button is pressed.
class StudySessionSideWidget extends StatefulWidget {
  const StudySessionSideWidget({
    required this.onClose,
    super.key,
  });

  final VoidCallback onClose;

  @override
  State<StudySessionSideWidget> createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<StudySessionSideWidget> {
  final SwiperController _swiperController = SwiperController();

  Duration studyTime = const Duration(minutes: 25);
  Duration breakTime = const Duration(minutes: 5);

  // We'll use these to fetch aggregate statistics.
  final StudySessionService _studySessionService = StudySessionService();

  final bool _error = false;

  @override
  void initState() {
    super.initState();
    // Initialize the service.
    _studySessionService.init();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return SizedBox(
      width: 450,
      height: MediaQuery.of(context).size.height - kControlBarHeight,
      child: Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
              themeProvider.appBackgroundGradientStart,
              themeProvider.appBackgroundGradientEnd,
            ])),
        child: Column(
          children: [
            buildTopBar(themeProvider),
            SessionPageController(
                onSessionCreated: (_) {},
                onCancel: () {
                  _swiperController.previous();
                })
          ],
        ),
      ),
    );
  }

  /// Builds the top bar with add and close buttons.
  Widget buildTopBar(ThemeProvider themeProvider) {
    return Container(
      height: 50,
      color: themeProvider.appContentBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: Icon(Icons.close, color: themeProvider.iconColor),
          ),
        ],
      ),
    );
  }

  /// Builds the home page that displays aggregated statistics.
  Widget buildHomePage() {
    return Placeholder();
  }

  /// Builds a start button that navigates to the new session creation page.
  Widget buildStartButton(ThemeProvider themeProvider) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: themeProvider.primaryAppColor,
        foregroundColor: Colors.white,
        maximumSize: const Size(130, 120),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: () {
        _swiperController.next();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_arrow, size: 20),
          const SizedBox(width: 10),
          Text(
            'Start',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
