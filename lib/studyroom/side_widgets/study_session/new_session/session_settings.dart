// Replace the top of the file with the following (adding an internal state for loop sessions)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/study/session_model.dart';
import 'package:studybeats/api/study/timer_fx/objects.dart';
import 'package:studybeats/api/study/timer_fx/timer_fx_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/side_widgets/study_session/timer_player.dart';

class SessionSettings extends StatefulWidget {
  final ValueChanged<bool> onTimerSoundEnabled;
  final ValueChanged<TimerFxData> onTimerSoundSelected;
  // Optionally add a callback for loop session changes:
  final ValueChanged<bool>? onLoopSessionChanged;
  final bool outlineEnabled;

  const SessionSettings({
    required this.onTimerSoundEnabled,
    required this.onTimerSoundSelected,
    this.onLoopSessionChanged,
    this.outlineEnabled = true,
    super.key,
  });

  @override
  State<SessionSettings> createState() => _SessionSettingsState();
}

class _SessionSettingsState extends State<SessionSettings> {
  List<TimerFxData> _timerFxList = [];
  TimerFxData? _selectedTimerFx;
  bool _enableTimerSound = true;
  final bool _loopSession = true; // New state variable for looping sessions

  bool _error = false;

  final TimerFxService _timerFxService = TimerFxService();
  final TimerPlayer _timerPlayer = TimerPlayer();

  final _logger = getLogger('_SessionSettingsState');

  @override
  void initState() {
    super.initState();
    getTimerSoundFx();
    _timerPlayer.init();
  }

  @override
  void dispose() {
    _timerPlayer.dispose();
    super.dispose();
  }

  void getTimerSoundFx() async {
    try {
      final sessionModel =
          Provider.of<StudySessionModel>(context, listen: false);
      final timerFxList = await _timerFxService.getTimerFxData();

      if (timerFxList.isNotEmpty) {
        setState(() {
          _timerFxList = timerFxList;

          if (sessionModel.currentSession == null ||
              sessionModel.currentSession!.soundFxId == null) {
            _selectedTimerFx = timerFxList.first;
            _enableTimerSound = true;
          } else {
            _selectedTimerFx = timerFxList.firstWhere(
              (fx) => fx.id == sessionModel.currentSession!.soundFxId,
              orElse: () => timerFxList.first,
            );
            _enableTimerSound = sessionModel.currentSession!.soundEnabled;
          }

          widget.onTimerSoundEnabled(_enableTimerSound);
          widget.onTimerSoundSelected(_selectedTimerFx!);
        });
      } else {
        setState(() {
          _error = true;
          _logger.e('No timer sound fx found');
        });
      }
    } catch (e) {
      setState(() {
        _error = true;
        _logger.e('Error getting timer sound fx: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.outlineEnabled
              ? kFlourishBlackish.withOpacity(0.1)
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FIRST SETTING: Sound Effects Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Sound Effects',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kFlourishBlackish,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message:
                          'Play a sound effect at the end of each study and break interval.',
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: kFlourishBlackish,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _enableTimerSound,
                  activeColor: kFlourishAdobe,
                  onChanged: (val) {
                    setState(() {
                      _enableTimerSound = val;
                    });
                    widget.onTimerSoundEnabled(_enableTimerSound);
                  },
                ),
              ],
            ),
            // Animated dropdown for sound effect selection when enabled
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  SizeTransition(sizeFactor: animation, child: child),
              child: _enableTimerSound
                  ? Padding(
                      key: const ValueKey('sound_selection'),
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildSoundFxSelectionUI(),
                    )
                  : const SizedBox(key: ValueKey('empty')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundFxSelectionUI() {
    return _timerFxList.isEmpty
        ? Center(
            child: SizedBox(
              width: double.infinity,
              height: 36,
              child: Shimmer.fromColors(
                baseColor: kFlourishBlackish.withOpacity(0.1),
                highlightColor: kFlourishBlackish.withOpacity(0.2),
                child: Container(
                  decoration: BoxDecoration(
                    color: kFlourishBlackish.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          )
        : Theme(
            // Override the splash and highlight colors so nothing “fills in” on tap.
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
            ),
            child: Container(
              height: 36,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kFlourishBlackish.withOpacity(0.1)),
              ),
              child: DropdownButton<TimerFxData>(
                value: _selectedTimerFx,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                iconSize: 24,
                elevation: 16,
                underline: Container(),
                items: _timerFxList.map((TimerFxData timerFxData) {
                  return DropdownMenuItem<TimerFxData>(
                    value: timerFxData,
                    child: Text(
                      timerFxData.name,
                      style: GoogleFonts.inter(
                        color: kFlourishBlackish,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (TimerFxData? timerFxData) {
                  if (timerFxData == null) return;
                  setState(() {
                    _selectedTimerFx = timerFxData;
                  });
                  _timerPlayer.playTimerSound(timerFxData);
                  widget.onTimerSoundSelected(timerFxData);
                },
              ),
            ),
          );
  }
}
