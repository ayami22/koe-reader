import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class CosyVoiceService {
  final Dio _dio;
  String _baseUrl;
  String _speakerId;
  double _speed;
  String? _referenceAudioPath;

  CosyVoiceService({
    String baseUrl = 'http://localhost:50000',
    String speakerId = 'default',
    double speed = 1.0,
    String? referenceAudioPath,
  })  : _baseUrl = baseUrl,
        _speakerId = speakerId,
        _speed = speed,
        _referenceAudioPath = referenceAudioPath,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));

  set baseUrl(String url) => _baseUrl = url;
  set speakerId(String id) => _speakerId = id;
  set speed(double s) => _speed = s;
  set referenceAudioPath(String? path) => _referenceAudioPath = path;

  Future<Uint8List> synthesize(String text) async {
    final response = await _dio.post<List<int>>(
      '$_baseUrl/api/tts',
      data: {
        'text': text,
        'speaker_id': _speakerId,
        'speed': _speed,
        'mode': _referenceAudioPath != null ? 'zero_shot' : 'sft',
        if (_referenceAudioPath != null)
          'reference_audio': _referenceAudioPath,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  Stream<Uint8List> synthesizeStream(String text) async* {
    final response = await _dio.post<ResponseBody>(
      '$_baseUrl/api/tts/stream',
      data: {
        'text': text,
        'speaker_id': _speakerId,
        'speed': _speed,
        'mode': _referenceAudioPath != null ? 'zero_shot' : 'sft',
        if (_referenceAudioPath != null)
          'reference_audio': _referenceAudioPath,
      },
      options: Options(responseType: ResponseType.stream),
    );
    await for (final chunk in response.data!.stream) {
      yield Uint8List.fromList(chunk);
    }
  }

  Future<List<Map<String, dynamic>>> listSpeakers() async {
    final response = await _dio.get<List<dynamic>>(
      '$_baseUrl/api/speakers',
    );
    return response.data!.cast<Map<String, dynamic>>();
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get<dynamic>('$_baseUrl/api/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _dio.close();
  }
}
