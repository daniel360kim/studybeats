import 'package:just_audio/just_audio.dart';

class ServerAudioSource extends StreamAudioSource {
  final List<int> audioData;
  ServerAudioSource(this.audioData);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= audioData.length;

    return StreamAudioResponse(
      sourceLength: audioData.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(audioData.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
