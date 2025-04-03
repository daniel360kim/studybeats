import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybeats/api/study/timer_fx/objects.dart';
import 'package:studybeats/api/study/timer_fx/timer_fx_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/side_widgets/timer/timer_player.dart';

class SoundFxSelector extends StatefulWidget {
  final ValueChanged<bool> onTimerSoundEnabled;
  final ValueChanged<TimerFxData> onTimerSoundSelected;

  const SoundFxSelector({
    required this.onTimerSoundEnabled,
    required this.onTimerSoundSelected,
    super.key,
  });

  @override
  State<SoundFxSelector> createState() => _SoundFxSelectorState();
}

class _SoundFxSelectorState extends State<SoundFxSelector> {
  List<TimerFxData> _timerFxList = [];
  TimerFxData? _selectedTimerFx;
  bool _enableTimerSound = true;

  bool _error = false;

  final TimerFxService _timerFxService = TimerFxService();
  final TimerPlayer _timerPlayer = TimerPlayer();

  final _logger = getLogger('_SoundFxSelectorState');

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
      final timerFxList = await _timerFxService.getTimerFxData();
      if (timerFxList.isNotEmpty) {
        setState(() {
          _timerFxList = timerFxList;
          _selectedTimerFx = timerFxList.first;

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
    if (_error) {
      return const SizedBox();
    }
    if (_enableTimerSound) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _enableTimerSound = !_enableTimerSound;
              });
              widget.onTimerSoundEnabled(_enableTimerSound);
            },
            icon: Icon(
              _enableTimerSound
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: kFlourishBlackish,
            ),
          ),
          const SizedBox(width: 10),
          _timerFxList.isEmpty
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: kFlourishBlackish,
                  ),
                )
              : Container(
                  height: 30,
                  width: 170,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: kFlourishLightBlackish,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: kFlourishBlackish.withOpacity(0.1),
                        spreadRadius: 5,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(
                      color: kFlourishBlackish.withOpacity(0.1),
                    ),
                  ),
                  child: DropdownButton<TimerFxData>(
                    value: _selectedTimerFx,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    iconSize: 24,
                    elevation: 16,
                    underline: Container(
                      height: 0,
                      color: Colors.transparent,
                    ),
                    items: _timerFxList
                        .map((TimerFxData timerFxData) =>
                            DropdownMenuItem<TimerFxData>(
                              value: timerFxData,
                              child: Row(
                                children: [
                                  Text(
                                    timerFxData.name,
                                    style: GoogleFonts.inter(
                                      color: kFlourishBlackish,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
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
        ],
      );
    } else {
      return IconButton(
        onPressed: () {
          setState(() {
            _enableTimerSound = !_enableTimerSound;
          });
          widget.onTimerSoundEnabled(_enableTimerSound);
        },
        icon: const Icon(
          Icons.notifications_off,
          color: kFlourishBlackish,
        ),
      );
    }
  }
}
