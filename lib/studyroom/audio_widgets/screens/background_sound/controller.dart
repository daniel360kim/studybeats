import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/audio/background_sfx/objects.dart';
import 'package:studybeats/api/audio/background_sfx/sfx_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/background_sound/volumebar.dart';

class BackgroundSoundControl extends StatefulWidget {
  const BackgroundSoundControl(
      {required this.backgroundSound,
      required this.onError,
      required this.themeColor,
      super.key});

  final BackgroundSound backgroundSound;
  final Color themeColor;
  final VoidCallback onError;

  @override
  State<BackgroundSoundControl> createState() => _BackgroundSoundControlState();
}

class _BackgroundSoundControlState extends State<BackgroundSoundControl>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _selected = false;
  final _logger = getLogger('Background Sound Control Widget');

  final _player = AudioPlayer();
  final _sfxService = SfxService();

  void _loadSoundControl() async {
    try {
      // Setup the audio controller
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());

      _player.playbackEventStream.listen((event) {},
          onError: (Object e, StackTrace stackTrace) {
        _logger.e('A stream error occurred: $e');
        if (mounted) {
          widget.onError();
        }
      });

      final audioUrl =
          await _sfxService.getBackgroundSoundUrl(widget.backgroundSound);

      final source = ClippingAudioSource(
        child: AudioSource.uri(Uri.parse(audioUrl)),
        // Optionally adjust the start and end times if necessary
        start: const Duration(seconds: 2),
        end: Duration(seconds: widget.backgroundSound.durationMs ~/ 1000 - 2),
      );

      await _player
          .setAudioSource(ConcatenatingAudioSource(children: [source]));

      _player.setLoopMode(LoopMode.all); // Repeat the sources

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      _logger.e('Audio Player initialization failed: $e');
      if (mounted) {
        widget.onError();
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> play() async {
    await _player.setVolume(0.5);
    await _player.play();
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  @override
  void initState() {
    super.initState();
    _loadSoundControl();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildIcon();
  }

  Widget buildIcon() {
    return _loading
        ? Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              height: 50,
              width: 50,
            ),
          )
        : Align(
            child: Row(
              children: [
                BulletCheckbox(
                  activeColor: widget.themeColor,
                  value: _selected,
                  onChanged: (value) {
                    setState(() {
                      _selected = value;
                      if (_selected) {
                        play();
                      } else {
                        _player.pause();
                      }
                    });
                  },
                ),
                VolumeBar(
                  themeColor: widget.themeColor,
                  icon: IconData(
                    widget.backgroundSound.iconId,
                    fontFamily: widget.backgroundSound.fontFamily,
                  ),
                  initialVolume: 50,
                  onChanged: (volume) {
                    setVolume(volume / 100);
                  },
                ),
                Text(
                  widget.backgroundSound.name,
                  style: GoogleFonts.inter(
                    color: kFlourishBlackish,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
  }
}

class BulletCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final Color inactiveColor;

  const BulletCheckbox({
    required this.value,
    required this.onChanged,
    required this.activeColor,
    this.inactiveColor = Colors.grey,
    super.key,
  });

  @override
  _BulletCheckboxState createState() => _BulletCheckboxState();
}

class _BulletCheckboxState extends State<BulletCheckbox> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovering = false;
        });
      },
      child: GestureDetector(
        onTap: () {
          widget.onChanged(!widget.value);
        },
        child: Container(
          height: 20,
          width: 20,
          decoration: BoxDecoration(
            color: widget.value ? widget.activeColor : widget.inactiveColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(
              widget.value ? Icons.check : Icons.circle,
              color: widget.value ? Colors.white : Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}
