import 'dart:convert';

import 'package:flourish_web/studyroom/audio/objects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:quiver/async.dart';

import 'volumebar.dart';

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

  final _player = AudioPlayer();
  CountdownTimer? _timer;
  final double _volume = 0.5;
  double _volumeBeforeFade = 0.5;

  BackgroundSound backgroundSound = const BackgroundSound(
    id: 0,
    name: '',
    soundPath: '',
    iconId: 0,
    fontFamily: '',
  );

  Future<void> _loadBackgroundSoundControl() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      print('A stream error occurred: $e');
    });

    String json = await rootBundle.loadString('assets/background/index.json');
    List<dynamic> backgroundSounds = await jsonDecode(json);
    List<BackgroundSound> backgroundSoundList = backgroundSounds
        .map((backgroundSound) => BackgroundSound.fromJson(backgroundSound))
        .toList();

    backgroundSound = backgroundSoundList
        .firstWhere((backgroundSound) => backgroundSound.id == widget.id);

    await _player.setAudioSource(AudioSource.asset(backgroundSound.soundPath));

    // Make the audio player repeat the song when it ends
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _player.seek(Duration.zero);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _offset = widget.initialPosition;
    _loadBackgroundSoundControl().then((_) {
      setState(() {});
    });
    
  }

  @override
  void dispose() {
    _player.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _volumeBeforeFade = _player.volume;
      fadeOutAndStop(startVolume: _volumeBeforeFade);
    } else if (state == AppLifecycleState.resumed) {
      setVolume(_volumeBeforeFade);
    }
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
                Container(
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
                        backgroundSound.iconId,
                        fontFamily: backgroundSound.fontFamily,
                      ),
                      color: Colors.white,
                    ),
                    onPressed: () {
                      _selected ? fadeOutAndStop(startVolume: _volume) : play();
                      setState(() {
                        _selected = !_selected;
                      });
                    },
                    color: Colors.black,
                  ),
                ),
                if (_selected) const SizedBox(height: 5),
                if (_selected) buildControls(),
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
