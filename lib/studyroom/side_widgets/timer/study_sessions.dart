import 'package:card_swiper/card_swiper.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/api/study/timer_fx/objects.dart';
import 'package:studybeats/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/studyroom/side_widgets/timer/new_session/new_session.dart';

/// Data class to hold Pomodoro durations.
class PomodoroDurations {
  Duration studyTime;
  Duration breakTime;

  PomodoroDurations(this.studyTime, this.breakTime);
}

/// A Pomodoro Timer widget that displays aggregated statistics and opens a
/// page for creating new study sessions when the start button is pressed.
class PomodoroTimer extends StatefulWidget {
  const PomodoroTimer({
    required this.onClose,
    required this.onStartPressed,
    required this.onTimerSoundEnabled,
    required this.onTimerSoundSelected,
    super.key,
  });

  /// Called when a new session is started.
  final ValueChanged<PomodoroDurations> onStartPressed;
  final ValueChanged<bool> onTimerSoundEnabled;
  final ValueChanged<TimerFxData> onTimerSoundSelected;
  final VoidCallback onClose;

  @override
  State<PomodoroTimer> createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer> {
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
    return SizedBox(
      width: 350,
      height: MediaQuery.of(context).size.height - 80,
      child: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
              Color(0xFFE0E7FF),
              Color(0xFFF7F8FC),
            ])),
        child: Column(
          children: [
            buildTopBar(),
            CreateStudySessionPage(
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
  Widget buildTopBar() {
    return Container(
      height: 50,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
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
  Widget buildStartButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: kFlourishCyan,
        foregroundColor: kFlourishBlackish,
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
