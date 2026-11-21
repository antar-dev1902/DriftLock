import 'package:driftlock/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Judge Mode runs the recorded blackout and keeps GPS reference gated',
    (tester) async {
      tester.view.physicalSize = const Size(430, 930);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await rootBundle.loadString('assets/austin_replay_v2.json');
        await rootBundle.loadString('assets/austin_benchmark.json');
      });
      await tester.pumpWidget(const DriftlockApp());
      await tester.pumpAndSettle();

      expect(find.text('Mission Control'), findsOneWidget);
      await tester.ensureVisible(find.text('Start Judge Mode'));
      await tester.tap(find.text('Start Judge Mode'));
      await tester.pumpAndSettle();
      expect(find.text('Austin road drive'), findsOneWidget);
      expect(find.text('GPS locked'), findsOneWidget);
      expect(find.text('Withheld GPS', findRichText: true), findsNothing);

      final outage = find.widgetWithText(OutlinedButton, 'Start outage');
      await tester.ensureVisible(outage);
      await tester.tap(outage);
      await tester.pump();
      expect(find.text('GPS blackout'), findsOneWidget);
      expect(find.text('Withheld GPS', findRichText: true), findsNothing);

      final seek = tester.widget<Slider>(find.byType(Slider)).onChanged!;
      seek(50.5);
      await tester.pump();
      expect(find.text('Reacquiring GPS'), findsOneWidget);

      seek(52);
      await tester.pump();
      expect(find.text('GPS restored'), findsOneWidget);

      final evaluation = find.widgetWithText(FilterChip, 'Evaluation mode');
      await tester.ensureVisible(evaluation);
      await tester.tap(evaluation);
      await tester.pumpAndSettle();
      expect(find.text('Withheld GPS', findRichText: true), findsOneWidget);
      expect(find.text('Position error over time'), findsOneWidget);

      final benchmark = find.widgetWithText(OutlinedButton, 'View benchmark');
      await tester.ensureVisible(benchmark);
      await tester.tap(benchmark);
      await tester.pumpAndSettle();
      expect(find.text('Benchmark Arena'), findsOneWidget);
      expect(find.text('57.9'), findsOneWidget);
      expect(find.text('76.9'), findsOneWidget);
      expect(find.text('181.1'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '90 s'));
      await tester.pumpAndSettle();
      expect(find.text('384.0'), findsOneWidget);
      expect(find.text('240.2'), findsOneWidget);
      expect(find.textContaining('1 of 2 windows scored'), findsOneWidget);
    },
  );
}
