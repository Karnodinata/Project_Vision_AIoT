import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vision/main.dart';

class MockLocalStorage extends LocalStorage {
  const MockLocalStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<bool> hasAccessToken() async => false;

  @override
  Future<void> persistSession(String session) async {}

  @override
  Future<void> removeSession() async {}

  @override
  Future<void> removePersistedSession() async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Mock shared_preferences channel for Supabase initialization
    const MethodChannel('plugins.flutter.io/shared_preferences')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, Object>{};
      }
      return null;
    });

    // Inisialisasi Supabase dengan JWT tiruan yang valid untuk testing widget
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtlZ2lubWRra2d0dmF4Y2h0anVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODkwOTEsImV4cCI6MjA4NzE2NTA5MX0.KGiNU8S1oLpJ1fep8p9uqVTFg0OwPRvxduGqzHLz3BU',
      authOptions: const FlutterAuthClientOptions(
        localStorage: MockLocalStorage(),
      ),
    );
  });

  testWidgets('Login Screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Verifikasi bahwa title V.I.S.I.O.N dirender
    expect(find.text('V.I.S.I.O.N'), findsOneWidget);
  });
}
