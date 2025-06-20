// File: study_session_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/api/study/session_model.dart';
import 'package:studybeats/api/study/study_service.dart';
import 'package:studybeats/api/study/timer_fx/objects.dart';
import 'package:studybeats/api/study/timer_fx/timer_fx_service.dart';
import 'package:studybeats/api/todo/todo_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/study_tools/study_session/timer_player.dart';

/// A dialog overlay that displays the countdown timer for the current phase (study or break)
/// and provides pause/resume and skip controls.
///
/// This dialog is minimizable. When minimized (via the button in the upper left),
/// it displays a compact view showing only the remaining time as text and a linear progress indicator.
/// Tapping the expand button returns to the full view.
class StudySessionDialog extends StatefulWidget {
  const StudySessionDialog({super.key});

  @override
  _StudySessionDialogState createState() => _StudySessionDialogState();
}

class _StudySessionDialogState extends State<StudySessionDialog> {
  final _soundPlayer = TimerPlayer();
  final _studySessionService = StudySessionService();
  bool _isPaused = false;
  bool _isMinimized = false; // New state for minimize/expand
  bool _isEditingTitle = false;
  late TextEditingController _titleController;

  final _logger = getLogger('Focus Session Dialog');
  Offset _offset = Offset.zero;

  // Timer for updating the dialog's countdown.
  Timer? _timer;

  final _todoService = TodoService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();

    _initStudySessionService();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _soundPlayer.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndEndSession(
      BuildContext context, StudySessionModel sessionModel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              'End Session?',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end this study session? Your progress will be saved.',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: Colors.grey.shade200,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(context).pop(true);
              final sessionService = StudySessionService();
              await sessionService.init();
              await sessionModel.endSession(sessionService);
              if (mounted) setState(() {});
            },
            child: Text(
              'End Session',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (mounted) {
          await _studySessionService.init();
          await sessionModel.endSession(_studySessionService);
        } else {
          _logger.e('Session model is not mounted.');
        }
      } catch (e) {
        _logger.e('Error ending session: ${e.toString()}');
      }
    }
  }

  void _initStudySessionService() async {
    try {
      await _studySessionService.init();
      await _todoService.init();
    } catch (e) {
      // Handle any errors that occur during initialization.
      _logger.e('Error initializing study session service: ${e.toString()}');
    }
  }

  /// Formats a Duration into mm:ss.
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final sessionModel = Provider.of<StudySessionModel>(context);
    if (sessionModel.currentSession == null) return const SizedBox();

    // Setup a callback to play sound on phase transition.
    sessionModel.onPhaseTransition = (newPhase) async {
      if (sessionModel.currentSession!.soundEnabled) {
        final TimerFxService timerFxService = TimerFxService();
        final fxDataList = await timerFxService.getTimerFxData();
        int? currentSessionFxId = sessionModel.currentSession!.soundFxId;
        TimerFxData? currentFxData = fxDataList
            .firstWhere((fx) => fx.id == currentSessionFxId, orElse: () {
          throw Exception(
              "No sound effect found for current session ID: $currentSessionFxId");
        });
        _soundPlayer.playTimerSound(currentFxData);
      }
    };

    // Phase label based on current phase.
    String phaseLabel;
    if (sessionModel.currentPhase == SessionPhase.studyTime) {
      phaseLabel =
          "Focus (${_formatDuration(sessionModel.currentSession!.studyDuration)})";
    } else {
      phaseLabel =
          "Break (${_formatDuration(sessionModel.currentSession!.breakDuration)})";
    }

    // Tab description label based on current phase.
    String tabDescriptionLabel;
    if (sessionModel.currentPhase == SessionPhase.studyTime) {
      tabDescriptionLabel =
          "Focus: ${formatDurationForTab(sessionModel.remainingTime)} left";
    } else {
      tabDescriptionLabel =
          "Break: ${formatDurationForTab(sessionModel.remainingTime)} left";
    }

    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: tabDescriptionLabel,
      ),
    );

    // Build the content for the full (expanded) dialog.
    Widget expandedContent = Column(
      key: const ValueKey('expanded'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Close button in the upper right remains.
        Row(
          children: [
            IconButton(
              tooltip: _isMinimized ? 'Expand' : 'Minimize',
              icon: Icon(
                _isMinimized ? Icons.open_in_full : Icons.remove,
                color: kFlourishBlackish,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _isMinimized = !_isMinimized;
                });
              },
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'End Session',
              onPressed: () => _confirmAndEndSession(context, sessionModel),
            ),
          ],
        ),
        // Locate the code that shows the session title in the expandedContent widget in study_session_dialog.dart.
// Replace that section with the following code:

// Replace the existing title Text widget with:
        _isEditingTitle
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: _titleController
                    ..text = sessionModel.currentSession!.title,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kFlourishBlackish,
                  ),
                  onSubmitted: (newTitle) async {
                    final trimmedTitle = newTitle.trim();
                    // Optimistically update the title in the session model.
                    if (trimmedTitle.isNotEmpty &&
                        sessionModel.currentSession!.title != trimmedTitle) {
                      final oldTitle = sessionModel.currentSession!.title;
                      // Create an updated session object with the new title.
                      final updatedSession = sessionModel.currentSession!
                          .copyWith(title: trimmedTitle);
                      // Update the UI immediately.
                      setState(() {/* _titleController.text is already set */});
                      try {
                        await sessionModel.updateSession(
                            updatedSession, _studySessionService);
                      } catch (e) {
                        _logger.e('Error updating session title');
                        // Optionally, revert to the old title if backend update fails.
                        final revertedSession = sessionModel.currentSession!
                            .copyWith(title: oldTitle);
                        sessionModel.updateSession(
                            revertedSession, _studySessionService);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Unable to update title. Please try again.'),
                          ),
                        );
                      }
                    }
                    setState(() => _isEditingTitle = false);
                  },
                ),
              )
            : InkWell(
                onDoubleTap: () {
                  setState(() {
                    _isEditingTitle = true;
                  });
                },
                child: Text(
                  sessionModel.currentSession!.title.length > 20
                      ? '${sessionModel.currentSession!.title.substring(0, 20)}...'
                      : sessionModel.currentSession!.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kFlourishBlackish,
                  ),
                ),
              ),
        const SizedBox(height: 16),
        Text(
          phaseLabel,
          style: GoogleFonts.inter(
            fontSize: 20,
            color: kFlourishLightBlackish,
          ),
        ),
        const SizedBox(height: 16),
        buildTimeElement(sessionModel),
        const SizedBox(height: 16),
        buildControlButtons(sessionModel),
        const SizedBox(height: 16),
      ],
    );

    // Build the minimized content: a compact view with time and a linear progress indicator.
    Widget minimizedContent = Column(
      key: const ValueKey('minimized'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // In the minimized view, we'll display just the remaining time and a linear progress bar.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: _isMinimized ? 'Expand' : 'Minimize',
                icon: Icon(
                  _isMinimized ? Icons.open_in_full : Icons.remove,
                  color: kFlourishBlackish,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isMinimized = !_isMinimized;
                  });
                },
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  _formatDuration(sessionModel.remainingTime),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kFlourishBlackish,
                  ),
                ),
              ),
            ),
            IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'End Session',
                onPressed: () => _confirmAndEndSession(context, sessionModel)),
          ],
        ),

        const SizedBox(height: 8),
        SizedBox(
          width: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4), // Rounded corners
            child: LinearProgressIndicator(
              value: sessionModel.getProgress(),
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                  sessionModel.currentSession!.themeColor),
            ),
          ),
        ),
      ],
    );

    // Use AnimatedSwitcher to toggle between minimized and expanded content.
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
            padding: const EdgeInsets.all(16),
            width: _isMinimized ? 250 : 300,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                sessionModel.currentSession!.themeColor.withOpacity(0.15),
                Colors.white,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                _isMinimized ? minimizedContent : expandedContent,
                // Minimize/Expand button positioned in the upper left.
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Builds a circular time element with a progress indicator.
  Widget buildTimeElement(StudySessionModel sessionModel) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CircularProgressIndicator(
            value: sessionModel.getProgress(),
            strokeWidth: 8,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              sessionModel.currentSession!.themeColor,
            ),
          ),
        ),
        Text(
          _formatDuration(sessionModel.remainingTime),
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // Builds control buttons for pause/resume and skipping the current phase.
  Row buildControlButtons(StudySessionModel sessionModel) {
    String nextSessionLabel;
    if (sessionModel.currentPhase == SessionPhase.studyTime) {
      nextSessionLabel = 'break';
    } else {
      nextSessionLabel = 'study';
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Pause timer',
          onPressed: () {
            setState(() {
              _isPaused = !_isPaused;
              if (_isPaused) {
                sessionModel.pauseTimer();
              } else {
                sessionModel.resumeTimer();
              }
            });
          },
          icon: _isPaused
              ? const Icon(Icons.play_arrow)
              : const Icon(Icons.pause),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Skip to $nextSessionLabel',
          onPressed: () {
            sessionModel.skipCurrentPhase();
          },
          icon: const Icon(Icons.skip_next),
        ),
      ],
    );
  }

  /// Formats a Duration into a string for the tab description.
  String formatDurationForTab(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }
}
