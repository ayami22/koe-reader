import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koe_reader/providers/library_provider.dart';
import 'package:koe_reader/providers/reader_provider.dart';
import 'package:koe_reader/providers/settings_provider.dart';
import 'package:koe_reader/providers/tts_provider.dart';
import 'package:koe_reader/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home screen shows app bar title', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => settings),
          ChangeNotifierProvider(create: (_) => LibraryProvider()),
          ChangeNotifierProvider(create: (_) => ReaderProvider()),
          ChangeNotifierProvider(create: (_) => TtsProvider()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('KoeReader'), findsOneWidget);
    expect(find.text('本を追加'), findsOneWidget);
  });
}
