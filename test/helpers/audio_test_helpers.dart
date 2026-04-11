import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

class FakeAudioSource extends Fake implements AudioSource {}

void registerAudioTestFallbacks() {
  registerFallbackValue(const AudioSessionConfiguration.music());
  registerFallbackValue(FakeAudioSource());
  registerFallbackValue(LoopMode.off);
}
