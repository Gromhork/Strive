import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/widgets/exercise_media.dart';

void main() {
  testWidgets('exercise animation plays slowed down and pauses with TickerMode', (t) async {
    await t.pumpWidget(const MaterialApp(home: Center(child: ExerciseMedia(exId: '0025', size: 200))));
    // Asset loading and decoding run outside the fake clock.
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await t.pump();
    expect(find.byType(RawImage), findsOneWidget);
    // Advance the (fake) frame timer, then let the codec decode the next frame.
    Future<bool> advanced(Duration d) async {
      final before = t.widget<RawImage>(find.byType(RawImage)).image!;
      await t.pump(d);
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await t.pump();
      return !t.widget<RawImage>(find.byType(RawImage)).image!.isCloneOf(before);
    }

    expect(await advanced(const Duration(milliseconds: 400)), isTrue);
    // Paused while tickers are disabled (e.g. route in the background).
    await t.pumpWidget(const MaterialApp(home: TickerMode(enabled: false, child: Center(child: ExerciseMedia(exId: '0025', size: 200)))));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await t.pump();
    expect(await advanced(const Duration(seconds: 2)), isFalse);
    expect(SlowAnimatedAsset.defaultSpeed, inInclusiveRange(0.5, 0.6));
  });

  testWidgets('missing animation falls back to the icon', (t) async {
    await t.pumpWidget(const MaterialApp(home: Center(child: ExerciseMedia(exId: '9998', size: 120))));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
  });
}
