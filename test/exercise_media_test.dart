import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strive/widgets/exercise_media.dart';

void main() {
  test('exercise animations are slowed down in the asset files (~0.55x)', () async {
    for (final id in ['0025', '0043', '0652', '1760']) {
      final buffer = await ui.ImmutableBuffer.fromUint8List(File('assets/exercises/anim/$id.webp').readAsBytesSync());
      final codec = await ui.instantiateImageCodecFromBuffer(buffer);
      expect(codec.frameCount, greaterThan(1));
      final f = await codec.getNextFrame();
      expect(f.duration.inMilliseconds, inInclusiveRange(170, 200), reason: id);
      // Not a blank frame.
      final px = (await f.image.toByteData())!;
      var dark = 0;
      for (var p = 0; p < px.lengthInBytes; p += 4) {
        if (px.getUint8(p) < 128) dark++;
      }
      expect(dark, greaterThan(500), reason: id);
    }
  });

  testWidgets('animated demo renders as an image', (t) async {
    await t.pumpWidget(const MaterialApp(home: Center(child: ExerciseMedia(exId: '0025', size: 200))));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await t.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center_rounded), findsNothing);
  });

  testWidgets('dark mode paints the demo through the colour filter and pauses off-screen', (t) async {
    Widget app({bool active = true}) => MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: TickerMode(enabled: active, child: const Center(child: ExerciseMedia(exId: '0025', size: 200))),
    );
    await t.pumpWidget(app());
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await t.pump();
    expect(find.byType(FilteredAssetImage), findsOneWidget);
    expect(find.descendant(of: find.byType(FilteredAssetImage), matching: find.byType(CustomPaint)), findsOneWidget);
    expect(find.byType(ColorFiltered), findsNothing);
    await t.pumpWidget(app(active: false));
    await t.pump();
    expect(find.byType(FilteredAssetImage), findsOneWidget);
  });

  testWidgets('missing animation falls back to the icon', (t) async {
    await t.pumpWidget(const MaterialApp(home: Center(child: ExerciseMedia(exId: '9998', size: 120))));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
  });
}
