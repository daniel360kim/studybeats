import 'package:audio_session/audio_session.dart';
import 'package:flourish_web/api/timer_fx/objects.dart';
import 'package:flourish_web/api/timer_fx/timer_fx_service.dart';
import 'package:flourish_web/log_printer.dart';
import 'package:just_audio/just_audio.dart';

class TimerPlayer {
  final _player = AudioPlayer();

  final _logger = getLogger('Timer Audio Player');

  final _timerFxService = TimerFxService();

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      _logger.e('A stream error occurred: $e');
        });
    
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _player.seek(Duration.zero);
      }
    });

  }

  void dispose() {
    _player.dispose();
  }

  void playTimerSound(TimerFxData timerFxData) async {
    try {
      final audioSource = await _timerFxService.getAudioSource(timerFxData);
      await _player.setAudioSource(audioSource);
      await _player.play();
    } catch (e) {
      _logger.e('Unexpected error while playing timer sound. $e');
    }
  }

}