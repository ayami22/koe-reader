import 'dart:typed_data';
import 'package:dio/dio.dart';

class TtsSpeaker {
  final String id;
  final String name;
  final String engine;
  final String locale;

  const TtsSpeaker({
    required this.id,
    required this.name,
    this.engine = 'edge',
    this.locale = 'ja-JP',
  });

  factory TtsSpeaker.fromMap(Map<String, dynamic> map) => TtsSpeaker(
        id: map['id'] as String? ?? 'default',
        name: map['name'] as String? ?? 'Default',
        engine: map['engine'] as String? ?? 'edge',
        locale: map['locale'] as String? ?? 'ja-JP',
      );
}

class CosyVoiceService {
  final Dio _dio;
  String _baseUrl;
  String _speakerId;
  double _speed;
  String? _referenceAudioPath;

  CosyVoiceService({
    String baseUrl = 'http://127.0.0.1:50000',
    String speakerId = 'ja-JP-NanamiNeural',
    double speed = 1.0,
    String? referenceAudioPath,
  })  : _baseUrl = baseUrl,
        _speakerId = speakerId,
        _speed = speed,
        _referenceAudioPath = referenceAudioPath,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 60),
        ));

  String get baseUrl => _baseUrl;
  String get speakerId => _speakerId;
  double get speed => _speed;

  set baseUrl(String url) => _baseUrl = url.replaceAll(RegExp(r'/$'), '');
  void setSpeaker(String id) => _speakerId = id;
  void setSpeed(double s) => _speed = s;
  set referenceAudioPath(String? path) => _referenceAudioPath = path;

  Future<Uint8List> synthesize(String text) async {
    final response = await _dio.post<List<int>>(
      '$_baseUrl/api/tts',
      data: {
        'text': text,
        'speaker_id': _speakerId,
        'speed': _speed,
        if (_referenceAudioPath != null) 'reference_audio': _referenceAudioPath,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  Future<List<TtsSpeaker>> listSpeakers() async {
    final response = await _dio.get<dynamic>('$_baseUrl/api/speakers');
    final data = response.data;
    final list = data is Map ? data['speakers'] : data;
    if (list is! List) return const [];
    return list
        .map((e) => TtsSpeaker.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get<dynamic>('$_baseUrl/api/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<TtsSpeaker?> cloneVoice(String name, String wavPath) async {
    final filename = wavPath.replaceAll('\\', '/').split('/').last;
    final form = FormData.fromMap({
      'name': name,
      'file': await MultipartFile.fromFile(wavPath, filename: filename),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/api/clone',
      data: form,
    );
    final data = response.data;
    if (data == null) return null;
    return TtsSpeaker.fromMap(data);
  }

  void dispose() {
    _dio.close();
  }
}
