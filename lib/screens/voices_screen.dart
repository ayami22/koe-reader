import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tts_provider.dart';
import '../services/cosyvoice_service.dart';

class VoicesScreen extends StatefulWidget {
  const VoicesScreen({super.key});

  @override
  State<VoicesScreen> createState() => _VoicesScreenState();
}

class _VoicesScreenState extends State<VoicesScreen> {
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      context.read<TtsProvider>().connect(settings.cosyVoiceUrl);
    });
  }

  Future<void> _clone() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final nameController = TextEditingController(text: 'カスタム音声');
    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('音声名'),
        content: TextField(controller: nameController),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text),
            child: const Text('登録'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!mounted) return;

    final tts = context.read<TtsProvider>();
    final settings = context.read<SettingsProvider>();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final speaker = await tts.service.cloneVoice(name, path);
      if (!mounted) return;
      await tts.connect(settings.cosyVoiceUrl);
      if (speaker != null) {
        await settings.setActiveVoiceId(speaker.id);
        tts.updateVoiceSettings(speakerId: speaker.id);
      }
      setState(() => _message = speaker == null ? '登録に失敗しました' : '登録しました');
    } catch (e) {
      setState(() => _message = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tts = context.watch<TtsProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('音声')),
      body: ListView(
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_message!),
            ),
          if (!tts.isConnected)
            const ListTile(
              leading: Icon(Icons.warning_amber),
              title: Text('サーバー未接続'),
              subtitle: Text('設定で TTS サーバーを起動・接続してください'),
            ),
          ...tts.speakers.map((TtsSpeaker s) {
            final selected = s.id == settings.activeVoiceId;
            return RadioListTile<String>(
              value: s.id,
              groupValue: settings.activeVoiceId,
              title: Text(s.name),
              subtitle: Text('${s.engine} / ${s.locale}'),
              selected: selected,
              onChanged: (id) {
                if (id == null) return;
                settings.setActiveVoiceId(id);
                tts.updateVoiceSettings(speakerId: id);
              },
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: tts.isConnected ? _clone : null,
        icon: const Icon(Icons.upload_file),
        label: const Text('音声を追加'),
      ),
    );
  }
}
