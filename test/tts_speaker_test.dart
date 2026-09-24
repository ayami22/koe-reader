import 'package:flutter_test/flutter_test.dart';
import 'package:koe_reader/services/cosyvoice_service.dart';

void main() {
  test('TtsSpeaker.fromMap fills defaults', () {
    final speaker = TtsSpeaker.fromMap({'id': 'ja-JP-NanamiNeural'});
    expect(speaker.id, 'ja-JP-NanamiNeural');
    expect(speaker.name, 'Default');
    expect(speaker.engine, 'edge');
    expect(speaker.locale, 'ja-JP');
  });

  test('TtsSpeaker.fromMap reads all fields', () {
    final speaker = TtsSpeaker.fromMap({
      'id': 'clone:hero',
      'name': 'Hero',
      'engine': 'cosyvoice',
      'locale': 'ja-JP',
    });
    expect(speaker.id, 'clone:hero');
    expect(speaker.name, 'Hero');
    expect(speaker.engine, 'cosyvoice');
  });
}
