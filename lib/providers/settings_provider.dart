import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  double _fontSize = 18.0;
  double _lineHeight = 1.8;
  bool _showFurigana = true;
  String _cosyVoiceUrl = 'http://127.0.0.1:50000';
  double _ttsSpeed = 1.0;
  String _activeVoiceId = 'ja-JP-NanamiNeural';

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  bool get showFurigana => _showFurigana;
  String get cosyVoiceUrl => _cosyVoiceUrl;
  double get ttsSpeed => _ttsSpeed;
  String get activeVoiceId => _activeVoiceId;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[_prefs.getInt('themeMode') ?? 0];
    _fontSize = _prefs.getDouble('fontSize') ?? 18.0;
    _lineHeight = _prefs.getDouble('lineHeight') ?? 1.8;
    _showFurigana = _prefs.getBool('showFurigana') ?? true;
    _cosyVoiceUrl =
        _prefs.getString('cosyVoiceUrl') ?? 'http://127.0.0.1:50000';
    _ttsSpeed = _prefs.getDouble('ttsSpeed') ?? 1.0;
    final storedVoice = _prefs.getString('activeVoiceId');
    _activeVoiceId = (storedVoice == null || storedVoice == 'default')
        ? 'ja-JP-NanamiNeural'
        : storedVoice;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(12.0, 32.0);
    await _prefs.setDouble('fontSize', _fontSize);
    notifyListeners();
  }

  Future<void> setLineHeight(double height) async {
    _lineHeight = height.clamp(1.2, 3.0);
    await _prefs.setDouble('lineHeight', _lineHeight);
    notifyListeners();
  }

  Future<void> setShowFurigana(bool show) async {
    _showFurigana = show;
    await _prefs.setBool('showFurigana', show);
    notifyListeners();
  }

  Future<void> setCosyVoiceUrl(String url) async {
    _cosyVoiceUrl = url;
    await _prefs.setString('cosyVoiceUrl', url);
    notifyListeners();
  }

  Future<void> setTtsSpeed(double speed) async {
    _ttsSpeed = speed.clamp(0.5, 2.0);
    await _prefs.setDouble('ttsSpeed', _ttsSpeed);
    notifyListeners();
  }

  Future<void> setActiveVoiceId(String id) async {
    _activeVoiceId = id;
    await _prefs.setString('activeVoiceId', id);
    notifyListeners();
  }
}
