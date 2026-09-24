import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/chapter.dart';
import '../services/cosyvoice_service.dart';

class TtsProvider extends ChangeNotifier {
  final CosyVoiceService _cosyVoice = CosyVoiceService();
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool _isConnected = false;
  bool _isSynthesizing = false;
  int _playingSentenceIndex = -1;

  bool get isPlaying => _isPlaying;
  bool get isConnected => _isConnected;
  bool get isSynthesizing => _isSynthesizing;
  int get playingSentenceIndex => _playingSentenceIndex;
  CosyVoiceService get service => _cosyVoice;

  TtsProvider() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onSentenceComplete();
      }
    });
  }

  VoidCallback? _onSentenceFinished;

  void setOnSentenceFinished(VoidCallback callback) {
    _onSentenceFinished = callback;
  }

  Future<void> connect(String baseUrl) async {
    _cosyVoice.baseUrl = baseUrl;
    _isConnected = await _cosyVoice.healthCheck();
    notifyListeners();
  }

  Future<void> speakSentence(Sentence sentence, int index) async {
    if (!_isConnected) return;

    _isSynthesizing = true;
    _playingSentenceIndex = index;
    notifyListeners();

    try {
      final audioData = await _cosyVoice.synthesize(sentence.text);
      _isSynthesizing = false;
      notifyListeners();

      await _playAudioData(audioData);
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      _isSynthesizing = false;
      _isPlaying = false;
      _playingSentenceIndex = -1;
      notifyListeners();
    }
  }

  Future<void> _playAudioData(Uint8List data) async {
    final source = _WavAudioSource(data);
    await _player.setAudioSource(source);
    await _player.play();
  }

  void _onSentenceComplete() {
    _isPlaying = false;
    _playingSentenceIndex = -1;
    notifyListeners();
    _onSentenceFinished?.call();
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    await _player.play();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> stop() async {
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
    if (speakerId != null) _cosyVoice.speakerId = speakerId;
    if (speed != null) _cosyVoice.speed = speed;
    if (referenceAudioPath != null) {
      _cosyVoice.referenceAudioPath = referenceAudioPath;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    _cosyVoice.dispose();
    super.dispose();
  }
}

class _WavAudioSource extends StreamAudioSource {
  final Uint8List _data;
  _WavAudioSource(this._data);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _data.length;
    return StreamAudioResponse(
      sourceLength: _data.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_data.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
