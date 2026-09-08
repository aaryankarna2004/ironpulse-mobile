import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironpulse/screens/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return true;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    await Supabase.initialize(
      url: 'https://qtwacvzlaprhtuuehfsu.supabase.co',
      publishableKey: 'sb_publishable_bCjvGYMc7wYq1gK2Y03-Dg_o5c_csXE',
    );
  });

  testWidgets('LoginScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.textContaining('IRON'), findsWidgets);
    expect(find.textContaining('AUTHORIZE'), findsOneWidget);
    expect(find.textContaining('STAFF'), findsWidgets);
  });
}
