import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/study/session_model.dart';
import 'package:studybeats/api/study/timer_fx/objects.dart';
import 'package:studybeats/api/study/timer_fx/timer_fx_service.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/study_tools/study_session/timer_player.dart';

import 'package:studybeats/theme_provider.dart';

class SessionSettings extends StatefulWidget {
  final ValueChanged<bool> onTimerSoundEnabled;
  final ValueChanged<TimerFxData> onTimerSoundSelected;
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
  final bool _loopSession = true;

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

      if (mounted && timerFxList.isNotEmpty) {
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
      } else if (mounted) {
        setState(() {
          _error = true;
          _logger.e('No timer sound fx found');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _logger.e('Error getting timer sound fx: $e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return const SizedBox();
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.outlineEnabled
              ? themeProvider.dividerColor
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        color: themeProvider.mainTextColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message:
                          'Play a sound effect at the end of each study and break interval.',
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: themeProvider.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _enableTimerSound,
                  activeColor: themeProvider.primaryAppColor,
                  inactiveTrackColor: themeProvider.backgroundColor,
                  onChanged: (val) {
                    setState(() {
                      _enableTimerSound = val;
                    });
                    widget.onTimerSoundEnabled(_enableTimerSound);
                  },
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  SizeTransition(sizeFactor: animation, child: child),
              child: _enableTimerSound
                  ? Padding(
                      key: const ValueKey('sound_selection'),
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildSoundFxSelectionUI(themeProvider),
                    )
                  : const SizedBox(key: ValueKey('empty')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundFxSelectionUI(ThemeProvider themeProvider) {
    return _timerFxList.isEmpty
        ? Center(
            child: SizedBox(
              width: double.infinity,
              height: 36,
              child: Shimmer.fromColors(
                baseColor: themeProvider.isDarkMode
                    ? Colors.grey[800]!
                    : Colors.grey[200]!,
                highlightColor: themeProvider.isDarkMode
                    ? Colors.grey[700]!
                    : Colors.grey[300]!,
                child: Container(
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? Colors.grey[800]!
                        : Colors.grey[200]!,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          )
        : Theme(
            data: Theme.of(context).copyWith(
              canvasColor: themeProvider.popupBackgroundColor,
            ),
            child: Container(
              height: 36,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: themeProvider.inputBorderColor),
              ),
              child: DropdownButton<TimerFxData>(
                value: _selectedTimerFx,
                isExpanded: true,
                icon:
                    Icon(Icons.arrow_drop_down, color: themeProvider.iconColor),
                iconSize: 24,
                elevation: 16,
                underline: Container(),
                items: _timerFxList.map((TimerFxData timerFxData) {
                  return DropdownMenuItem<TimerFxData>(
                    value: timerFxData,
                    child: Text(
                      timerFxData.name,
                      style: GoogleFonts.inter(
                        color: themeProvider.mainTextColor,
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
