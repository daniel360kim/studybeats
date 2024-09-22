import 'package:flourish_web/api/audio/objects.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:quiver/async.dart';

import 'volumebar.dart';
import 'package:flourish_web/api/audio/sfx_service.dart';

class BackgroundSoundControl extends StatefulWidget {
  const BackgroundSoundControl(
      {required this.id, required this.initialPosition, super.key});

  final int id;
  final Offset initialPosition;

  @override
  State<BackgroundSoundControl> createState() => _BackgroundSoundControlState();
}

class _BackgroundSoundControlState extends State<BackgroundSoundControl>
    with WidgetsBindingObserver {
  late Offset _offset;
  bool _selected = false;
  bool _loading = true;

  final _player = AudioPlayer();
  CountdownTimer? _timer;
  final double _volume = 0.5;

  final _sfxService = SfxService();

  BackgroundSound? backgroundSound;

  Future<void> _loadBackgroundSoundControl() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      print('A stream error occurred: $e');
    });

    backgroundSound = await _sfxService.getBackgroundSoundInfo(widget.id);
    final audioUrl = await _sfxService.getBackgroundSoundUrl(backgroundSound!);
    await _player.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));

    // Make the audio player repeat the song when it ends
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _player.seek(Duration.zero);
      }
    });

    // Mark loading as complete
    setState(() {
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _offset = widget.initialPosition;
    _loadBackgroundSoundControl();
  }

  @override
  void dispose() {
    _player.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: _offset.dx,
          top: _offset.dy,
          child: Draggable(
            feedback: Container(),
            onDragUpdate: (details) {
              setState(() {
                _offset = Offset(
                  _offset.dx + details.delta.dx,
                  _offset.dy + details.delta.dy,
                );
              });
            },
            onDraggableCanceled: (velocity, offset) {
              setState(() {
                _offset = offset;
              });
            },
            child: Column(
              children: [
                _loading
                    ? const ShimmerLoadingWidget() // Replace this with your shimmer or loading widget
                    : Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: _selected
                              ? Colors.white.withOpacity(0.5)
                              : Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            IconData(
                              backgroundSound!.iconId,
                              fontFamily: backgroundSound!.fontFamily,
                            ),
                            color: Colors.white,
                          ),
                          onPressed: () {
                            _selected
                                ? fadeOutAndStop(startVolume: _volume)
                                : play();
                            setState(() {
                              _selected = !_selected;
                            });
                          },
                        ),
                      ),
                if (_selected && !_loading) const SizedBox(height: 5),
                if (_selected && !_loading) buildControls(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildControls() {
    return Container(
      height: 150,
      width: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          VolumeBar(
              initialVolume: 50,
              onChanged: (volume) {
                setVolume(volume / 100);
              })
        ],
      ),
    );
  }

  Future<void> play() async {
    await _player.setVolume(0.5);
    await _player.play();
  }

  Future<void> fadeOutAndStop({required double startVolume}) async {
    /// Will fade out over 3 seconds
    Duration duration = const Duration(milliseconds: 300);

    /// Using a [CountdownTimer] to decrement the volume every 50 milliseconds, then stop [AudioPlayer] when done.
    _timer = CountdownTimer(duration, const Duration(milliseconds: 5))
      ..listen((event) {
        final percent =
            event.remaining.inMilliseconds / duration.inMilliseconds;
        setVolume(percent * startVolume);
      }).onDone(() async {
        await _player.pause();
      });
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }
}

class ShimmerLoadingWidget extends StatelessWidget {
  const ShimmerLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
    );
  }
}
