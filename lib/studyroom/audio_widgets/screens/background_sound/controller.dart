import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:studybeats/api/audio/background_sfx/objects.dart';
import 'package:studybeats/api/audio/background_sfx/sfx_service.dart';
import 'package:studybeats/colors.dart';
import 'package:studybeats/log_printer.dart';
import 'package:studybeats/studyroom/audio/audio_state.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/background_sound/switch.dart';
import 'package:studybeats/studyroom/audio_widgets/screens/background_sound/volumebar.dart';
import 'package:studybeats/theme_provider.dart';

class BackgroundSoundControl extends StatefulWidget {
  const BackgroundSoundControl({
    required this.backgroundSound,
    required this.onError,
    required this.themeColor,
    this.isGloballyMuted = false, // *** NEW: Add isGloballyMuted parameter ***
    super.key,
  });

  final BackgroundSound backgroundSound;
  final Color themeColor;
  final VoidCallback onError;
  final bool isGloballyMuted; // *** NEW ***

  @override
  State<BackgroundSoundControl> createState() => _BackgroundSoundControlState();
}

class _BackgroundSoundControlState extends State<BackgroundSoundControl>
    with WidgetsBindingObserver {
  // ... (most of the state class remains the same)
  late final AudioSourceSelectionProvider _audioSourceProvider;
  bool _loading = true;
  bool _selected = false;
  final _logger = getLogger('Background Sound Control Widget');

  final _player = AudioPlayer();
  final _sfxService = SfxService();
  final ValueNotifier<double> _volumeNotifier = ValueNotifier<double>(50.0);

  @override
  void didUpdateWidget(covariant BackgroundSoundControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the global mute was just activated AND this sound is currently selected (playing)
    if (widget.isGloballyMuted && !oldWidget.isGloballyMuted && _selected) {
      // De-select the switch and pause the audio
      _toggleSound(false);
    }
  }

  // initState, _loadSoundControl, dispose, etc. remain the same
  @override
  void initState() {
    super.initState();
    _audioSourceProvider =
        Provider.of<AudioSourceSelectionProvider>(context, listen: false);
    _audioSourceProvider.addListener(_handleAudioSourceChanged);
    _loadSoundControl();
  }

  void _loadSoundControl() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      _player.playbackEventStream.listen((event) {},
          onError: (Object e, StackTrace stackTrace) {
        _logger.e('A stream error occurred: $e');
        if (mounted) widget.onError();
      });

      final audioUrl =
          await _sfxService.getBackgroundSoundUrl(widget.backgroundSound);
      await _player.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)),
          initialPosition: Duration.zero, preload: true);
      await _player.setLoopMode(LoopMode.one);
      await _player.setVolume(_volumeNotifier.value / 100);

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      _logger.e('Audio Player initialization failed: $e');
      if (mounted) {
        widget.onError();
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _audioSourceProvider.removeListener(_handleAudioSourceChanged);
    _player.dispose();
    _volumeNotifier.dispose();
    super.dispose();
  }

  void _handleAudioSourceChanged() {
    if (_audioSourceProvider.currentSource == AudioSourceType.spotify &&
        _selected) {
      _toggleSound(false);
    }
  }

  void _toggleSound(bool value) {
    // Don't allow turning sound on if global mute is active
    if (widget.isGloballyMuted && value) return;

    setState(() => _selected = value);
    if (_selected) {
      _player.play();
    } else {
      _player.pause();
    }
  }

  Future<void> _setVolume(double volume) async {
    _volumeNotifier.value = volume;
    await _player.setVolume(volume / 100);
  }

  // The build method is unchanged, but is included for completeness.
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _LoadingShimmer();
    }

    final themeProvider = Provider.of<ThemeProvider>(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            _selected ? widget.themeColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CustomSwitch(
            value: _selected,
            activeColor: widget.themeColor,
            onChanged: _toggleSound,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ValueListenableBuilder<double>(
              valueListenable: _volumeNotifier,
              builder: (context, volume, child) {
                return VolumeBar(
                  themeColor: widget.themeColor,
                  icon: IconData(
                    widget.backgroundSound.iconId,
                    fontFamily: widget.backgroundSound.fontFamily,
                  ),
                  initialVolume: volume,
                  onChanged: _selected ? _setVolume : null,
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: Text(
              widget.backgroundSound.name,
              style: GoogleFonts.inter(
                color: themeProvider.textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12.0),
        child: Row(
          children: [
            Container(
                width: 48,
                height: 28,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24))),
            const SizedBox(width: 16),
            Expanded(
                child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4)))),
            const SizedBox(width: 16),
            Container(
                width: 80,
                height: 16,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    );
  }
}
