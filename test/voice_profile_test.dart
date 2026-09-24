import 'package:flutter_test/flutter_test.dart';
import 'package:koe_reader/models/voice_profile.dart';

void main() {
  group('VoiceProfile', () {
    test('creates from map and converts back', () {
      final profile = VoiceProfile(
        id: 'test-1',
        name: 'テスト音声',
        speakerId: 'speaker_01',
        speed: 1.2,
        engine: VoiceEngine.cosyVoice,
      );

      final map = profile.toMap();
      final restored = VoiceProfile.fromMap(map);

      expect(restored.id, 'test-1');
      expect(restored.name, 'テスト音声');
      expect(restored.speakerId, 'speaker_01');
      expect(restored.speed, 1.2);
      expect(restored.engine, VoiceEngine.cosyVoice);
    });

    test('copyWith overrides specified fields only', () {
      final original = VoiceProfile(
        id: 'v1',
        name: 'Original',
        speed: 1.0,
      );

      final modified = original.copyWith(name: 'Modified', speed: 1.5);

      expect(modified.id, 'v1');
      expect(modified.name, 'Modified');
      expect(modified.speed, 1.5);
      expect(modified.engine, VoiceEngine.cosyVoice);
    });

    test('fromMap uses defaults for missing fields', () {
      final profile = VoiceProfile.fromMap({
        'id': 'v2',
        'name': 'Minimal',
      });

      expect(profile.speakerId, 'default');
      expect(profile.speed, 1.0);
      expect(profile.engine, VoiceEngine.cosyVoice);
    });
  });
}
