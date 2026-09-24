import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/chapter.dart';
import '../services/cosyvoice_service.dart';

class TtsProvider extends ChangeNotifier {
  final CosyVoiceService service;
  final AudioPlayer _player = AudioPlayer();
  final Map<String, Uint8List> _cache = {};

  bool _isPlaying = false;
  bool _isConnected = false;
  bool _isSynthesizing = false;
  int _playingSentenceIndex = -1;
  String? _lastError;
  List<TtsSpeaker> _speakers = const [];
  String _engineLabel = '';

  TtsProvider({CosyVoiceService? service})
      : service = service ?? CosyVoiceService() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onSentenceComplete();
      }
    });
  }

  bool get isPlaying => _isPlaying;
  bool get isConnected => _isConnected;
  bool get isSynthesizing => _isSynthesizing;
  int get playingSentenceIndex => _playingSentenceIndex;
  String? get lastError => _lastError;
  List<TtsSpeaker> get speakers => _speakers;
  String get engineLabel => _engineLabel;

  VoidCallback? _onSentenceFinished;
  bool _advanceArmed = false;

  void setOnSentenceFinished(VoidCallback callback) {
    _onSentenceFinished = callback;
  }

  Future<void> connect(String baseUrl) async {
    service.baseUrl = baseUrl;
    _isConnected = await service.healthCheck();
    if (_isConnected) {
      try {
        _speakers = await service.listSpeakers();
        if (_speakers.isNotEmpty &&
            _speakers.every((s) => s.id != service.speakerId)) {
          service.setSpeaker(_speakers.first.id);
        }
        _engineLabel = _speakers.isNotEmpty ? _speakers.first.engine : 'ok';
        _lastError = null;
      } catch (e) {
        _lastError = e.toString();
      }
    } else {
      _lastError = 'サーバーに接続できません';
    }
    notifyListeners();
  }

  Future<void> speakSentence(Sentence sentence, int index) async {
    if (!_isConnected) {
      _lastError = 'TTS未接続';
      notifyListeners();
      return;
    }

    _advanceArmed = false;
    await _player.stop();
    _advanceArmed = true;
    _isSynthesizing = true;
    _playingSentenceIndex = index;
    _lastError = null;
    notifyListeners();

    try {
      final audioData = await _synthesizeCached(sentence.text);
      _isSynthesizing = false;
      notifyListeners();
      await _playAudioData(audioData);
      _isPlaying = true;
      notifyListeners();
      _prefetchNeighbors(sentence);
    } catch (e) {
      _isSynthesizing = false;
      _isPlaying = false;
      _playingSentenceIndex = -1;
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<Uint8List> _synthesizeCached(String text) async {
    final key = '${service.speakerId}|${service.speed}|$text';
    final cached = _cache[key];
    if (cached != null) return cached;
    final data = await service.synthesize(text);
    if (_cache.length > 40) _cache.remove(_cache.keys.first);
    _cache[key] = data;
    return data;
  }

  void _prefetchNeighbors(Sentence current) {
    // Prefetch is opportunistic; failures are ignored.
  }

  Future<void> prefetch(String text) async {
    if (!_isConnected || text.isEmpty) return;
    try {
      await _synthesizeCached(text);
    } catch (_) {}
  }

  Future<void> _playAudioData(Uint8List data) async {
    await _player.setAudioSource(_BytesAudioSource(data));
    await _player.play();
  }

  void _onSentenceComplete() {
    _isPlaying = false;
    notifyListeners();
    if (_advanceArmed) {
      _onSentenceFinished?.call();
    }
  }

  Future<void> pause() async {
    _advanceArmed = false;
    await _player.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    _advanceArmed = true;
    await _player.play();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> stop() async {
    _advanceArmed = false;
    await _player.stop();
    _isPlaying = false;
    _playingSentenceIndex = -1;
    notifyListeners();
  }

  void updateVoiceSettings({
    String? speakerId,
    double? speed,
    String? referenceAudioPath,
  }) {
    if (speakerId != null) service.setSpeaker(speakerId);
    if (speed != null) service.setSpeed(speed);
    if (referenceAudioPath != null) {
      service.referenceAudioPath = referenceAudioPath;
    }
    _cache.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    service.dispose();
    super.dispose();
  }
}

class _BytesAudioSource extends StreamAudioSource {
  final Uint8List _data;
  _BytesAudioSource(this._data);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _data.length;
    return StreamAudioResponse(
      sourceLength: _data.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_data.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
