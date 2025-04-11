import 'dart:async';
import 'dart:ui';
import 'package:studybeats/api/analytics/analytics_service.dart';
import 'package:studybeats/api/study/timer_fx/objects.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/studyroom/side_widgets/timer/timer_player.dart';
import 'package:flutter/material.dart';
import 'side_widgets/timer/study_sessions.dart';

class TabDescriptionReporter {
  bool isFocus;
  Duration duration;

  TabDescriptionReporter({required this.isFocus, required this.duration});
}

class TimerDialog extends StatefulWidget {
  const TimerDialog({
    required this.focusTimerDuration,
    required this.breakTimerDuration,
    required this.onExit,
    required this.timerSoundEnabled,
    required this.timerFxData,
    required this.onTimerDurationChanged,
    super.key,
  });

  final Duration focusTimerDuration;
  final Duration breakTimerDuration;
  final ValueChanged<PomodoroDurations> onExit;
  final bool timerSoundEnabled;
  final ValueChanged<TabDescriptionReporter> onTimerDurationChanged;
  final TimerFxData timerFxData;

  @override
  State<TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<TimerDialog> {
  late Timer _timer;
  late DateTime _startTime;
  late Duration _totalDuration;

  Duration _remainingTime = Duration.zero;
  bool _isOnFocus = true;
  bool _isPaused = false;

  final _soundPlayer = TimerPlayer();
  final _analyticsService = AnalyticsService();

  // Draggable state.
  Offset _offset = Offset.zero;
  // Theme color state.
  Color _themeColor = Colors.black.withOpacity(0.8);
  final List<Color> _themeColors = [
    Colors.black.withOpacity(0.8),
    Colors.blue.withOpacity(0.8),
    Colors.red.withOpacity(0.8),
    Colors.green.withOpacity(0.8),
    Colors.purple.withOpacity(0.8),
  ];

  @override
  void initState() {
    super.initState();
    _sendAnalytics();
    _soundPlayer.init();
    _startFocusTimer();
  }

  void _sendAnalytics() async {
    await _analyticsService.logOpenFeature(
        ContentType.studyTimer, 'Study Timer');
  }

  void _startFocusTimer() {
    setState(() {
      _remainingTime = widget.focusTimerDuration;
      _isOnFocus = true;
    });
    _startTimer();
  }

  void _startBreakTimer() {
    setState(() {
      _remainingTime = widget.breakTimerDuration;
      _isOnFocus = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _totalDuration = _remainingTime;
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
  }

  void _pauseTimer() {
    _timer.cancel();
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeTimer() {
    setState(() {
      _isPaused = false;
      _startTime = DateTime.now();
      _totalDuration = _remainingTime;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
  }

  @override
  void dispose() {
    _timer.cancel();
    _soundPlayer.dispose();
    super.dispose();
  }

  void _updateTimer(Timer timer) {
    final elapsed = DateTime.now().difference(_startTime);
    final remaining = _totalDuration - elapsed;
    final report =
        TabDescriptionReporter(isFocus: _isOnFocus, duration: remaining);
    widget.onTimerDurationChanged(report);

    if (remaining.inSeconds <= 0) {
      _timer.cancel();
      if (widget.timerSoundEnabled) {
        _soundPlayer.playTimerSound(widget.timerFxData);
      }
      if (_isOnFocus) {
        _startBreakTimer();
      } else {
        _startFocusTimer();
      }
    } else {
      setState(() {
        _remainingTime = remaining;
      });
    }
  }

  String _formattedTime(Duration duration) {
    final hours = duration.inHours > 0
        ? '${duration.inHours.toString().padLeft(2, '0')}:'
        : '';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final double progressValue = _totalDuration.inSeconds > 0
        ? _remainingTime.inSeconds / _totalDuration.inSeconds
        : 0;

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _offset += details.delta;
        });
      },
      child: Transform.translate(
        offset: _offset,
        child: Center(
          child: Container(
            height: 300,
            width: _remainingTime.inHours > 0 ? 300 : 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: _themeColor,
            ),
            child: Stack(
              children: [
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Top row: Close button and mode title.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 25),
                          IconButton(
                            onPressed: () {
                              PomodoroDurations resetDurations =
                                  PomodoroDurations(
                                      Duration.zero, Duration.zero);
                              widget.onExit(resetDurations);
                              _timer.cancel();
                            },
                            padding: EdgeInsets.zero,
                            color: kFlourishAliceBlue,
                            icon: const Icon(Icons.close),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                _isOnFocus ? 'Focus' : 'Break',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: kFlourishAliceBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 60),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Timer with progress indicator.
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: progressValue,
                              strokeWidth: 8,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                              backgroundColor: Colors.white.withOpacity(0.35),
                            ),
                          ),
                          Text(
                            _formattedTime(_remainingTime),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Pause/Resume button.
                      IconButton(
                        onPressed: () {
                          if (_isPaused) {
                            _resumeTimer();
                          } else {
                            _pauseTimer();
                          }
                        },
                        icon: Icon(
                          _isPaused ? Icons.play_arrow : Icons.pause,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Theme Color Palette.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _themeColors.map((color) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _themeColor = color;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                                border: _themeColor == color
                                    ? Border.all(width: 2, color: Colors.white)
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
