import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/audio/background_sfx/objects.dart';
import 'package:studybeats/api/audio/background_sfx/sfx_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/background_sound/switch.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/background_sound/volumebar.dart';
import 'package:provider/provider.dart';
import 'package:studybeats/studyroom/audio/audio_state.dart';

class BackgroundSoundControl extends StatefulWidget {
  const BackgroundSoundControl({
    required this.backgroundSound,
    required this.onError,
    required this.themeColor,
    super.key,
  });

  final BackgroundSound backgroundSound;
  final Color themeColor;
  final VoidCallback onError;

  @override
  State<BackgroundSoundControl> createState() => _BackgroundSoundControlState();
}

class _BackgroundSoundControlState extends State<BackgroundSoundControl>
    with WidgetsBindingObserver {
  late final AudioSourceSelectionProvider _audioSourceProvider;
  bool _loading = true;
  bool _selected = false;
  final _logger = getLogger('Background Sound Control Widget');

  final _player = AudioPlayer();
  final _sfxService = SfxService();

  // Use a ValueNotifier to track the current volume (range: 0.0 - 1.0)
  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(0.5);

  void _loadSoundControl() async {
    try {
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
      );

      await _player.setAudioSource(
        ConcatenatingAudioSource(children: [source]),
      );

      _player.setLoopMode(LoopMode.all);

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
    volumeNotifier.value = 0.5;
    await _player.setVolume(0.5);
    await _player.play();
  }

  Future<void> setVolume(double volume) async {
    volumeNotifier.value = volume;
    await _player.setVolume(volume);
  }

  @override
  void initState() {
    super.initState();
    _loadSoundControl();
    _audioSourceProvider =
        Provider.of<AudioSourceSelectionProvider>(context, listen: false);
    _audioSourceProvider.addListener(_handleAudioSourceChanged);
  }

  @override
  void dispose() {
    _audioSourceProvider.removeListener(_handleAudioSourceChanged);
    _player.dispose();
    volumeNotifier.dispose();
    super.dispose();
  }

  void _handleAudioSourceChanged() {
    if (_audioSourceProvider.currentSource == AudioSourceType.spotify &&
        _selected) {
      setState(() {
        _selected = false;
      });
      _player.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                // Use the custom switch widget instead of the default Switch.
                CustomSwitch(
                  value: _selected,
                  activeColor: widget.themeColor,
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
                const SizedBox(width: 8),
                // Wrap VolumeBar in a ValueListenableBuilder to update UI when volume changes.
                ValueListenableBuilder<double>(
                  valueListenable: volumeNotifier,
                  builder: (context, volume, child) {
                    return VolumeBar(
                      themeColor: widget.themeColor,
                      icon: IconData(
                        widget.backgroundSound.iconId,
                        fontFamily: widget.backgroundSound.fontFamily,
                      ),
                      initialVolume: (volume * 100).roundToDouble(),
                      onChanged: _selected
                          ? (vol) {
                              setVolume(vol / 100);
                            }
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.backgroundSound.name,
                    style: GoogleFonts.inter(
                      color: kFlourishBlackish,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}
