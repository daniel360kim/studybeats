import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/api/study/timer_fx/objects.dart';
import 'package:studybeats/studyroom/study_tools/study_session/new_session/timer_swiper.dart';
import 'package:studybeats/studyroom/study_tools/study_session/new_session/session_settings.dart';
import 'package:studybeats/theme_provider.dart';

class SessionInputs extends StatefulWidget {
  const SessionInputs({
    required this.onSessionNameChangeed,
    required this.showTimerEditor,
    required this.onContinuePressed,
    required this.onTimerSoundSelected,
    required this.onTimerSoundEnabled,
    required this.onLoopSessionChanged,
    required this.onStudyTimeChanged,
    required this.onBreakTimeChanged,
    super.key,
  });
  final ValueChanged<String> onSessionNameChangeed;
  final ValueChanged<bool> showTimerEditor;
  final ValueChanged<TimerFxData> onTimerSoundSelected;
  final ValueChanged<bool> onTimerSoundEnabled;
  final VoidCallback onContinuePressed;
  final ValueChanged<bool> onLoopSessionChanged;
  final ValueChanged<Duration> onStudyTimeChanged;
  final ValueChanged<Duration> onBreakTimeChanged;

  @override
  State<SessionInputs> createState() => _SessionInputsState();
}

class _SessionInputsState extends State<SessionInputs>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Duration studyTime = const Duration(minutes: 25);
  Duration breakTime = const Duration(minutes: 5);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Name',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: themeProvider.mainTextColor,
            ),
          ),
          const SizedBox(height: 10),
          _buildTextField(themeProvider),
          const SizedBox(height: 20),
          _buildTimerSetters(themeProvider),
          const SizedBox(height: 50),
          Divider(
            color: themeProvider.dividerColor,
            height: 1,
          ),
          const SizedBox(height: 30),
          SessionSettings(
            onTimerSoundEnabled: widget.onTimerSoundEnabled,
            onTimerSoundSelected: widget.onTimerSoundSelected,
            onLoopSessionChanged: widget.onLoopSessionChanged,
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () {
                  widget.onContinuePressed();
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: themeProvider.primaryAppColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextField _buildTextField(ThemeProvider themeProvider) {
    return TextField(
      style: TextStyle(color: themeProvider.mainTextColor),
      decoration: InputDecoration(
        hintText: 'Enter a name for your session',
        hintStyle: GoogleFonts.inter(
            color: themeProvider.secondaryTextColor, fontSize: 14),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: themeProvider.inputBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: themeProvider.primaryAppColor),
        ),
      ),
      cursorColor: themeProvider.primaryAppColor,
      onChanged: (value) {
        widget.onSessionNameChangeed(value);
      },
    );
  }

  Widget _buildTimerSetters(ThemeProvider themeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeItem(
          title: 'Focus',
          initialTimeMinutes: studyTime.inMinutes,
          onTimeChanged: (newTime) {
            widget.onStudyTimeChanged(newTime);
            setState(() {
              studyTime = newTime;
            });
          },
          themeProvider: themeProvider,
        ),
        const SizedBox(width: 20),
        _buildTimeItem(
          title: 'Break',
          initialTimeMinutes: breakTime.inMinutes,
          onTimeChanged: (newTime) {
            widget.onBreakTimeChanged(newTime);
            setState(() {
              breakTime = newTime;
            });
          },
          themeProvider: themeProvider,
        ),
      ],
    );
  }

  Widget _buildTimeItem({
    required String title,
    required int initialTimeMinutes,
    required ValueChanged<Duration> onTimeChanged,
    required ThemeProvider themeProvider,
  }) {
    final GlobalKey timeKey = GlobalKey();

    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
              fontSize: 16, color: themeProvider.secondaryTextColor),
        ),
        const SizedBox(height: 6),
        Container(
          width: 50,
          height: 2,
          color: themeProvider.secondaryTextColor,
        ),
        const SizedBox(height: 10),
        Container(
          key: timeKey,
          child: _TimeDropdownButton(
            minutes: initialTimeMinutes,
            themeProvider: themeProvider,
            onTap: () {
              _showTimerPickerMenu(
                  key: timeKey,
                  pickerTitle: title,
                  initialTime: initialTimeMinutes,
                  onTimeChanged: (newTime) {
                    Duration duration;
                    if (newTime == 0) {
                      duration = const Duration(milliseconds: 1);
                    } else {
                      duration = Duration(minutes: newTime);
                    }
                    onTimeChanged(
                      duration,
                    );
                  },
                  themeProvider: themeProvider);
            },
          ),
        ),
      ],
    );
  }

  void _showTimerPickerMenu({
    required GlobalKey key,
    required String pickerTitle,
    required int initialTime,
    required ValueChanged<int> onTimeChanged,
    required ThemeProvider themeProvider,
  }) async {
    final RenderBox renderBox =
        key.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    final RelativeRect position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + size.height,
      offset.dx + size.width,
      offset.dy,
    );

    int temporaryMinutes = initialTime;

    final int? result = await showMenu<int>(
      context: context,
      position: position,
      color: themeProvider.popupBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<int>(
          enabled: false,
          child: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 450,
                height: 380,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Adjust $pickerTitle Timer',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.mainTextColor,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close,
                                color: themeProvider.iconColor),
                            onPressed: () {
                              Navigator.of(context).pop(null);
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(
                        height: 1,
                        thickness: 1,
                        color: themeProvider.dividerColor),
                    Expanded(
                      child: TimerSwiperItem(
                        hourLowerValue: 0,
                        hourUpperValue: 23,
                        minuteLowerValue: 0,
                        minuteUpperValue: 59,
                        initialHourValue: temporaryMinutes ~/ 60,
                        initialMinuteValue: temporaryMinutes % 60,
                        onDurationSelected: (duration) {
                          setState(() {
                            temporaryMinutes = duration.inMinutes;
                          });
                        },
                        child: Container(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(null);
                            },
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: themeProvider.secondaryTextColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop(temporaryMinutes);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              backgroundColor: themeProvider.primaryAppColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'OK',
                              style: GoogleFonts.inter(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );

    if (result != null) {
      onTimeChanged(result);
    }
  }
}

class _TimeDropdownButton extends StatelessWidget {
  final int minutes;
  final VoidCallback onTap;
  final ThemeProvider themeProvider;

  const _TimeDropdownButton(
      {required this.minutes,
      required this.onTap,
      required this.themeProvider});

  String _formatDuration(int totalMinutes) {
    final duration = Duration(minutes: totalMinutes);
    final hours = duration.inHours;
    final mins = duration.inMinutes.remainder(60);
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}'
        : '${mins.toString().padLeft(2, '0')}:00';
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: ButtonStyle(
        overlayColor: WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return themeProvider.primaryAppColor.withOpacity(0.1);
            }
            return null;
          },
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDuration(minutes),
            style: GoogleFonts.inter(
                fontSize: 28, color: themeProvider.secondaryTextColor),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            color: themeProvider.secondaryTextColor,
            size: 28,
          ),
        ],
      ),
    );
  }
}
