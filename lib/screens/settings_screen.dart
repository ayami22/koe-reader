import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tts_provider.dart';
import 'voices_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const _SectionHeader(title: '表示設定'),
          _ThemeTile(settings: settings),
          _SliderTile(
            title: 'フォントサイズ',
            value: settings.fontSize,
            min: 12,
            max: 32,
            divisions: 20,
            label: '${settings.fontSize.round()}px',
            onChanged: settings.setFontSize,
          ),
          _SliderTile(
            title: '行間',
            value: settings.lineHeight,
            min: 1.2,
            max: 3.0,
            divisions: 18,
            label: settings.lineHeight.toStringAsFixed(1),
            onChanged: settings.setLineHeight,
          ),
          SwitchListTile(
            title: const Text('ふりがな表示'),
            subtitle: const Text('漢字にふりがなを表示します'),
            value: settings.showFurigana,
            onChanged: settings.setShowFurigana,
          ),
          SwitchListTile(
            title: const Text('画面をスリープしない'),
            subtitle: const Text('読書中は画面を点灯したままにします'),
            value: settings.keepScreenOn,
            onChanged: settings.setKeepScreenOn,
          ),
          _SliderTile(
            title: '明るさ',
            value: settings.brightness,
            min: 0.35,
            max: 1.0,
            divisions: 13,
            label: '${(settings.brightness * 100).round()}%',
            onChanged: settings.setBrightness,
          ),
          const Divider(),
          const _SectionHeader(title: '音声設定'),
          ListTile(
            title: const Text('TTS サーバー'),
            subtitle: Text(settings.cosyVoiceUrl),
            trailing: const Icon(Icons.edit),
            onTap: () => _editServerUrl(context, settings),
          ),
          _SliderTile(
            title: '読み上げ速度',
            value: settings.ttsSpeed,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: '${settings.ttsSpeed.toStringAsFixed(1)}x',
            onChanged: (v) {
              settings.setTtsSpeed(v);
              context.read<TtsProvider>().updateVoiceSettings(speed: v);
            },
          ),
          ListTile(
            title: const Text('接続テスト'),
            trailing: const _ConnectionStatus(),
            onTap: () => _testConnection(context),
          ),
          const Divider(),
          const _SectionHeader(title: '音声プロファイル'),
          ListTile(
            leading: const Icon(Icons.record_voice_over),
            title: const Text('音声を管理'),
            subtitle: const Text('話者の切替とカスタム音声'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VoicesScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editServerUrl(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final controller = TextEditingController(text: settings.cosyVoiceUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('サーバーURL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'http://127.0.0.1:50000',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await settings.setCosyVoiceUrl(result);
    }
  }

  Future<void> _testConnection(BuildContext context) async {
    final tts = context.read<TtsProvider>();
    final settings = context.read<SettingsProvider>();
    await tts.connect(settings.cosyVoiceUrl);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tts.isConnected ? '接続成功' : '接続失敗：サーバーに接続できません'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final SettingsProvider settings;
  const _ThemeTile({required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('テーマ'),
      trailing: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.auto_mode)),
          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode)),
          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode)),
        ],
        selected: {settings.themeMode},
        onSelectionChanged: (v) => settings.setThemeMode(v.first),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
      ),
      trailing: SizedBox(width: 48, child: Text(label, textAlign: TextAlign.end)),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus();

  @override
  Widget build(BuildContext context) {
    final tts = context.watch<TtsProvider>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tts.isConnected ? Colors.green : Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Text(tts.isConnected ? '接続済み' : '未接続'),
      ],
    );
  }
}
