import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vision/widgets/ph_realtime_card.dart';

void main() {
  testWidgets('PhRealtimeCard displays realtimePh when provided', (WidgetTester tester) async {
    // Stream controller that does not emit immediately
    final controller = StreamController<List<Map<String, dynamic>>>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhRealtimeCard(
            phStream: controller.stream,
            realtimePh: 7.2,
            onTap: () {},
          ),
        ),
      ),
    );

    // Let the stream builder evaluate
    await tester.pump();

    // Verify that the realtimePh (7.2) is rendered as "7.2"
    expect(find.text('7.2'), findsOneWidget);
    // Verify badge status is OPTIMAL
    expect(find.text('OPTIMAL'), findsOneWidget);

    controller.close();
  });

  testWidgets('PhRealtimeCard displays anomaly status when realtimePh is out of range', (WidgetTester tester) async {
    final controller = StreamController<List<Map<String, dynamic>>>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhRealtimeCard(
            phStream: controller.stream,
            realtimePh: 5.5,
            onTap: () {},
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('5.5'), findsOneWidget);
    expect(find.text('PERINGATAN ANOMALI'), findsOneWidget);

    controller.close();
  });

  testWidgets('PhRealtimeCard falls back to stream value if realtimePh is null', (WidgetTester tester) async {
    final controller = StreamController<List<Map<String, dynamic>>>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhRealtimeCard(
            phStream: controller.stream,
            realtimePh: null,
            onTap: () {},
          ),
        ),
      ),
    );

    // Stream has not emitted yet, so it should display loading status
    await tester.pump();
    expect(find.text('METRIK pH REAL-TIME'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Emit data through stream
    controller.add([
      {'ph_level': 8.1, 'waktu_rekam': '2026-05-21T12:00:00Z'}
    ]);

    await tester.pumpAndSettle();

    expect(find.text('8.1'), findsOneWidget);
    expect(find.text('OPTIMAL'), findsOneWidget);

    controller.close();
  });

  testWidgets('PhRealtimeCard displays OFFLINE and hides chart when isIotAktif is false', (WidgetTester tester) async {
    final controller = StreamController<List<Map<String, dynamic>>>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhRealtimeCard(
            phStream: controller.stream,
            realtimePh: null,
            isIotAktif: false,
            onTap: () {},
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify offline labels
    expect(find.text('--'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('Sensor IoT sedang tidak aktif / mati.'), findsOneWidget);

    // Verify no graph or progress indicator is shown
    expect(find.byType(LineChart), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    controller.close();
  });
}
