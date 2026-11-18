import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/exercise_db.dart';
import 'package:strive/data/exercise_measure.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/session/exercise_focus_page.dart';
import 'package:strive/features/session/gym_session_page.dart';
import 'package:strive/features/stats/session_detail_page.dart';
import 'package:strive/features/train/gym_exercise_editor.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/active_workout.dart';
import 'package:strive/services/compliance.dart';
import 'package:strive/services/gym_tools.dart' show ProgressionKind;
import 'package:strive/services/insights.dart';
import 'package:strive/services/load_prescription.dart';
import 'package:strive/services/plan_fill.dart';
import 'package:strive/services/smart_progression.dart' show ProgressReason;
import 'package:strive/widgets/prescription.dart';

final now = DateTime(2026, 11, 9, 18);
const male80 = UserProfile(weightKg: 80, gender: 'm', level: 'intermediate', birthYear: 1996);
const kg = Units(false);

LoadPrescriber lp(List<Session> h) => LoadPrescriber(history: h, profile: male80, now: now);

Session gym(int daysAgo, List<GymExercise> ex, {String id = 'h', double? bodyWeight, bool fromPlan = false}) => Session(
  id: id,
  sport: Sport.gym,
  title: 'Gym',
  start: now.subtract(Duration(days: daysAgo)),
  durationSec: 3600,
  exercises: ex,
  bodyWeightKg: bodyWeight,
  fromPlan: fromPlan,
);

GymExercise reps(String id, String name, List<(double, int)> sets, {bool done = true, bool? bw, double bodyKg = 0}) =>
    GymExercise(exId: id, name: name, bw: bw, bodyKg: bodyKg, sets: [for (final (w, r) in sets) GymSet(weight: w, reps: r, done: done)]);

/// A plank-type exercise with (added kg, held s, target s) sets.
GymExercise hold(String id, String name, List<(double, int, int?)> sets, {bool done = true}) =>
    GymExercise(exId: id, name: name, bw: true, sets: [for (final (w, s, t) in sets) GymSet(weight: w, sec: s, targetSec: t, done: done)]);

class _PresetGym extends ActiveGymNotifier {
  _PresetGym(this.init);
  final ActiveGym init;
  @override
  ActiveGym? build() => init;
}

void main() {
  final de = lookupAppLocalizations(const Locale('de'));

  group('timed exercises are recognised', () {
    test('holds by id and name; dynamic variants stay reps', () {
      for (final (id, name) in const [
        ('2135', 'weighted front plank'),
        ('0705', 'side bridge v. 2'),
        ('3544', 'bodyweight incline side plank'),
        ('3419', 'l-sit on floor'),
        ('2133', 'farmers walk'),
        ('x1', 'front plank'),
        ('x2', 'wall sit'),
        ('x3', 'hollow body hold'),
        ('x4', 'dead hang'),
        ('x5', 'hamstring stretch'),
        ('x6', 'superman hold'),
        ('manual-de', 'Unterarmstütz'),
        ('manual-de2', 'Wandsitzen'),
      ]) {
        expect(isTimedExercise(id, name), isTrue, reason: name);
      }
      for (final (id, name) in const [
        ('0464', 'front plank with twist'),
        ('0664', 'push-up to side plank'),
        ('0472', 'hanging leg raise'),
        ('1604', 'world greatest stretch'),
        ('0662', 'push-up'),
        ('0025', 'barbell bench press'),
        ('3295', 'front lever reps'),
        ('x7', 'handstand push-up'),
        ('x8', 'plank jack'),
        ('manual', 'Unterarmstütz'),
      ]) {
        expect(isTimedExercise(id, name), isFalse, reason: name);
      }
    });

    test('the per-exercise override wins over the automatic type', () {
      final plank = GymExercise(exId: '2135', name: 'weighted front plank');
      expect(plank.isTimed, isTrue);
      plank.timed = false;
      expect(plank.isTimed, isFalse);
      final row = GymExercise(exId: 'x', name: 'dumbbell row')..timed = true;
      expect(row.isTimed, isTrue);
    });

    test('hold ranges and the hold label', () {
      expect(defaultHoldRange('front plank'), (30, 60));
      expect(defaultHoldRange('side bridge v. 2'), (20, 45));
      expect(defaultHoldRange('wall sit'), (30, 90));
      expect(defaultHoldRange('l-sit on floor'), (10, 30));
      expect(defaultHoldRange('hamstring stretch'), (30, 60));
      expect(formatHold(45), '45 s');
      expect(formatHold(90), '1:30 min');
      expect(formatHold(120), '2 min');
      expect(holdTakesLoad('weighted front plank'), isTrue);
      expect(holdTakesLoad('hamstring stretch'), isFalse);
      expect(holdTakesLoad('l-sit on floor'), isFalse);
    });
  });

  group('stored data', () {
    test('hold time, override, range and body weight round-trip; old documents load', () {
      final e = GymExercise(
        exId: '2135',
        name: 'weighted front plank',
        timed: true,
        holdMin: 20,
        holdMax: 50,
        sets: [GymSet(weight: 5, sec: 42, targetSec: 45, done: true)],
      );
      final back = GymExercise.fromMap(e.toMap());
      expect(back.timed, isTrue);
      expect(back.holdRange, (20, 50));
      expect(back.sets.single.sec, 42);
      expect(back.sets.single.targetSec, 45);
      final s = gym(1, [e], bodyWeight: 78.5);
      expect(Session.fromMap('a', s.toMap()).bodyWeightKg, 78.5);
      // A document from before: no hold fields, no body weight.
      final old = GymExercise.fromMap({
        'exId': '2135',
        'name': 'weighted front plank',
        'sets': [
          {'w': 0, 'r': 60, 'd': true},
        ],
      });
      expect(old.timed, isNull);
      expect(old.sets.single.sec, 0);
      expect(old.sets.single.legacyReps, isTrue);
      expect(Session.fromMap('b', {'sport': 'gym', 'start': now, 'title': '', 'durationSec': 1}).bodyWeightKg, isNull);
      // No hold fields are written for rep exercises.
      expect(GymSet(weight: 60, reps: 8).toMap().keys, isNot(contains('s')));
    });

    test('body weight of a day: last entry before, else the first after, else the profile', () {
      final entries = [
        BodyEntry(id: 'a', date: DateTime(2026, 10, 1), weightKg: 82),
        BodyEntry(id: 'b', date: DateTime(2026, 11, 1), weightKg: 80),
      ];
      expect(bodyWeightOn(DateTime(2026, 10, 20), entries, 75), 82);
      expect(bodyWeightOn(DateTime(2026, 11, 5), entries, 75), 80);
      expect(bodyWeightOn(DateTime(2026, 9, 1), entries, 75), 82);
      expect(bodyWeightOn(DateTime(2026, 9, 1), const [], 75), 75);
    });
  });

  group('body share of bodyweight exercises', () {
    test('literature-based approximations', () {
      double share(String n) => bodyShareOf('x', n);
      expect(share('push-up'), 0.64);
      expect(share('push-up (on knees)'), 0.49);
      expect(share('incline push-up'), 0.41);
      expect(share('decline push-up'), 0.7);
      expect(share('pull-up'), 1);
      expect(share('chin-up'), 1);
      expect(share('chest dip'), 1);
      expect(share('bench dip (knees bent)'), 0.5);
      expect(share('inverted row'), 0.6);
      expect(share('bodyweight squat'), 0.7);
      expect(share('walking lunge'), 0.7);
      expect(share('pistol squat'), 0.9);
      expect(share('glute bridge march'), 0.5);
      expect(share('sit-up'), 0.3);
      expect(share('crunch floor'), 0.3);
      expect(share('burpee'), 0.5);
      expect(share('lever assisted pull-up'), 1); // weights are assistance (negative)
      // Loaded and timed exercises: no body share.
      expect(share('barbell full squat'), 0);
      expect(share('dumbbell lunge'), 0);
      expect(share('cable pull-up'), 0);
      expect(share('weighted front plank'), 0);
      expect(bodyShareOf('manual', 'Gesamtvolumen'), 0);
    });
  });

  group('volume', () {
    test('bodyweight exercises count body weight × share + added weight', () {
      // Stored body load of the workout (new sessions).
      final pu = reps('0652', 'pull-up', [(0, 8), (10, 6)], bw: true, bodyKg: 80);
      expect(pu.volume, 80 * 8 + 90 * 6);
      // Older session: no mode / body load stored → body weight of the session × share.
      final push = reps('0662', 'push-up', [(0, 10), (0, 10), (0, 10)]);
      expect(push.volume, 0, reason: 'without a body weight nothing can be derived');
      expect(push.volumeAt(80), closeTo(51.2 * 30, 1e-6));
      final s = gym(1, [push], bodyWeight: 80);
      expect(s.volume, closeTo(1536, 1e-6));
      expect(s.volumeCountsBody, isTrue);
      // Pull-ups logged with the body weight as weight before bodyweight mode: the total load.
      final legacyTotal = reps('0652', 'pull-up', [(80, 8)]);
      expect(legacyTotal.volumeAt(80), 640);
      // Assisted machine logged as a positive weight: the assistance.
      final assisted = reps('0017', 'lever assisted pull-up', [(30, 10)]);
      expect(assisted.volumeAt(80), 500);
      // Bodyweight mode switched off: the weight only.
      final off = reps('0652', 'pull-up', [(20, 10)], bw: false);
      expect(off.volumeAt(80), 200);
      // Stored body load wins over the session's body weight.
      final stored = reps('0652', 'pull-up', [(0, 10)], bw: true, bodyKg: 75);
      expect(stored.volumeAt(90), 750);
      // Loaded lifts and the manual summary "exercise" unchanged.
      expect(reps('0025', 'barbell bench press', [(60, 10)]).volumeAt(80), 600);
      expect(reps('manual', 'Gesamtvolumen', [(5000, 1)]).volumeAt(80), 5000);
    });

    test('timed holds: no kg volume, hold time instead', () {
      final p = hold('2135', 'weighted front plank', [(10, 45, 45), (10, 40, 45), (0, 30, null)]);
      expect(p.volumeAt(80), 0);
      expect(p.holdSec, 115);
      expect(p.longestHold, 45);
      expect(p.bestE1rm, 0);
      final s = gym(1, [
        p,
        reps('0025', 'barbell bench press', [(60, 10)]),
      ], bodyWeight: 80);
      expect(s.volume, 600);
      expect(s.holdSec, 115);
      expect(s.volumeCountsBody, isFalse);
    });

    test('older sessions get the body weight of their day for display only', () {
      final s = gym(1, [
        reps('0662', 'push-up', [(0, 10)]),
      ]);
      final filled = s.withBodyWeight(70);
      expect(filled.bodyWeightKg, 70);
      expect(filled.volume, closeTo(0.64 * 70 * 10, 1e-6));
      expect(identical(filled.withBodyWeight(90), filled), isTrue, reason: 'a stored body weight is kept');
    });

    test('the session list derives the body weight of older sessions from the body entries', () async {
      final old = gym(10, [
        reps('0662', 'push-up', [(0, 10)]),
      ], id: 'old');
      final stored = gym(
        1,
        [
          reps('0662', 'push-up', [(0, 10)]),
        ],
        id: 'new',
        bodyWeight: 90,
      );
      final c = ProviderContainer(
        overrides: [
          sessionsProvider.overrideWith((ref) => Stream.value([stored, old])),
          bodyProvider.overrideWith(
            (ref) => Stream.value([BodyEntry(id: 'b', date: now.subtract(const Duration(days: 20)), weightKg: 75)]),
          ),
          profileProvider.overrideWith((ref) => Stream.value(male80)),
        ],
      );
      addTearDown(c.dispose);
      c.listen(sessionListProvider, (_, __) {});
      await c.read(sessionsProvider.future);
      await c.read(bodyProvider.future);
      await c.read(profileProvider.future);
      final list = c.read(sessionListProvider);
      expect(list.firstWhere((s) => s.id == 'new').bodyWeightKg, 90);
      expect(list.firstWhere((s) => s.id == 'old').bodyWeightKg, 75);
      expect(list.firstWhere((s) => s.id == 'old').volume, closeTo(0.64 * 75 * 10, 1e-6));
    });

    test('bodyweight leg and core work gets a body load when the workout starts (no 0 kg)', () {
      final out = lp(const []).apply([
        GymExercise(exId: '9001', name: 'bodyweight squat', sets: [GymSet(reps: 15)]),
        GymExercise(exId: '9002', name: 'sit-up', sets: [GymSet(reps: 15)]),
        GymExercise(exId: '2135', name: 'weighted front plank', sets: [GymSet()]),
      ]);
      expect(out[0].bw, isTrue);
      expect(out[0].bodyKg, 56);
      expect(out[1].bodyKg, 24);
      expect(out[2].bodyKg, 0, reason: 'a hold is measured in time');
      for (final s in out[0].sets) {
        s.done = true;
      }
      // The body load drives the load progression; the volume counts only added load for squats
      // (their loaded variants count only the bar – S8, volumeBodyShareOf).
      expect(out[0].volume, 0);
    });
  });

  group('records', () {
    test('holds: the longest hold; push-ups: the most reps; weighted pull-ups: e1RM incl. body', () {
      final h = [
        gym(1, [
          hold('2135', 'weighted front plank', [(0, 50, 45), (0, 40, 45)]),
          reps('0662', 'push-up', [(0, 20), (0, 18)], bw: true, bodyKg: 51.2),
          reps('0652', 'pull-up', [(10, 5)], bw: true, bodyKg: 80),
        ], id: 'b'),
        gym(5, [
          hold('2135', 'weighted front plank', [(0, 45, 45)]),
        ], id: 'a'),
      ];
      final r = exerciseRecords(h);
      expect(r['2135']!.longestHold, 50);
      expect(r['2135']!.bestE1rm, 0);
      expect(r['0662']!.bestE1rm, 0, reason: 'an e1RM of 64 % of the body reads like a lift');
      expect(r['0662']!.maxReps, 20);
      expect(r['0652']!.bestE1rm, closeTo(e1rm(90, 5), 1e-6));
      // A longer hold than ever is a new record.
      final next = gym(0, [
        hold('2135', 'weighted front plank', [(0, 55, 50)]),
      ], id: 'c');
      expect(newPrs(next, h), ['weighted front plank']);
      final shorter = gym(0, [
        hold('2135', 'weighted front plank', [(0, 48, 50)]),
      ], id: 'd');
      expect(newPrs(shorter, h), isEmpty);
    });
  });

  group('hold-time progression', () {
    GymExercise planned() => GymExercise(exId: '2135', name: 'weighted front plank', sets: [GymSet(), GymSet(), GymSet()]);

    test('no history: the bottom of the range, no weight', () {
      final p = lp(const []).forExercise(planned())!;
      expect(p.timed, isTrue);
      expect(p.reps, 30);
      expect(p.weight, 0);
      expect(p.fromHistory, isFalse);
      expect(prescriptionToday(de, p, kg, sets: 3), 'Heute: 3 × 30 s');
    });

    test('every set held: +10 s (+5 s below 30 s), from what was held', () {
      final h = [
        gym(3, [
          hold('2135', 'weighted front plank', [(0, 30, 30), (0, 32, 30), (0, 30, 30)]),
        ]),
      ];
      final p = lp(h).forExercise(planned())!;
      expect(p.reps, 40);
      expect(p.progression, ProgressionKind.addReps);
      expect(p.reason, ProgressReason.holdLonger);
      final short = [
        gym(3, [
          hold('0705', 'side bridge v. 2', [(0, 20, 20), (0, 20, 20)]),
        ]),
      ];
      expect(lp(short).forExercise(GymExercise(exId: '0705', name: 'side bridge v. 2', sets: [GymSet()]))!.reps, 25);
    });

    test('top of the range: +2.5 kg and back to the bottom; stretches stay at the top', () {
      final h = [
        gym(3, [
          hold('2135', 'weighted front plank', [(0, 60, 60), (0, 60, 60)]),
        ]),
      ];
      final p = lp(h).forExercise(planned())!;
      expect(p.weight, 2.5);
      expect(p.reps, 30);
      expect(p.reason, ProgressReason.holdAddLoad);
      expect(prescriptionToday(de, p, kg, sets: 2), 'Heute: 2 × 30 s @ +2.5 kg');
      final st = [
        gym(3, [
          hold('x5', 'hamstring stretch', [(0, 60, 60)]),
        ]),
      ];
      final q = lp(st).forExercise(GymExercise(exId: 'x5', name: 'hamstring stretch', sets: [GymSet()]))!;
      expect(q.weight, 0);
      expect(q.reps, 60);
      expect(q.reason, ProgressReason.holdTop);
    });

    test('a target clearly missed holds the time; missed twice steps back', () {
      final once = [
        gym(3, [
          hold('2135', 'weighted front plank', [(0, 45, 45), (0, 35, 45)]),
        ]),
      ];
      final p = lp(once).forExercise(planned())!;
      expect(p.reps, 45);
      expect(p.reason, ProgressReason.holdMissed);
      final twice = [
        once.first,
        gym(6, [
          hold('2135', 'weighted front plank', [(0, 30, 45)]),
        ], id: 'h2'),
      ];
      final q = lp(twice).forExercise(planned())!;
      expect(q.reps, 35);
      expect(q.reason, ProgressReason.holdShorter);
    });

    test('taken over from the plan: the same targets; deload week: ~80 % of the time', () {
      final fp = [
        gym(2, [
          hold('2135', 'weighted front plank', [(0, 50, 50)]),
        ], fromPlan: true),
      ];
      expect(lp(fp).forExercise(planned())!.reason, ProgressReason.fromPlan);
      expect(lp(fp).forExercise(planned())!.reps, 50);
      final h = [
        gym(3, [
          hold('2135', 'weighted front plank', [(0, 50, 50)]),
        ]),
      ];
      final d = lp(h).forExercise(planned(), phase: 'recovery')!;
      expect(d.reps, 40);
      expect(d.progression, ProgressionKind.hold);
    });

    test('apply fills hold times; a program\'s own times are kept until there is history', () {
      final own = GymExercise(exId: '2135', name: 'weighted front plank', sets: [GymSet(sec: 45), GymSet(sec: 45)]);
      final a = lp(const []).apply([own]).single;
      expect(a.sets.map((s) => s.sec), [45, 45]);
      expect(a.sets.map((s) => s.targetSec), [45, 45]);
      expect(a.sets.every((s) => s.reps == 0), isTrue);
      // An older program that stored the plank as 3 × 8 reps: hold times instead.
      final legacy = GymExercise(exId: '2135', name: 'weighted front plank', repMin: 8, repMax: 15, sets: [GymSet(reps: 8)]);
      final b = lp(const []).apply([legacy]).single;
      expect(b.sets.single.sec, 30);
      expect(b.sets.single.reps, 0);
      final h = [
        gym(3, [
          hold('2135', 'weighted front plank', [(0, 45, 45), (0, 45, 45)]),
        ]),
      ];
      expect(lp(h).apply([own]).single.sets.map((s) => s.sec), [55, 55]);
    });
  });

  group('plan fill, compliance, minutes', () {
    test('mark as done: the planned hold time, no reps', () {
      final p = PlannedWorkout(
        id: 'p',
        date: now,
        sport: Sport.gym,
        title: 'Core',
        durationMin: 20,
        exercises: [
          GymExercise(exId: '2135', name: 'weighted front plank', sets: [GymSet(sec: 40), GymSet(sec: 40)]),
        ],
      );
      final fill = PlanFill.of(p, profile: male80, prescriber: lp(const []));
      final e = fill.exercises.single;
      expect(e.sets.every((s) => s.done && s.sec == 40 && s.targetSec == 40 && s.reps == 0), isTrue);
      final s = sessionFromPlan(p, fill, id: 'x', start: now, title: 'Core', bodyWeightKg: 80);
      expect(s.bodyWeightKg, 80);
      expect(s.holdSec, 80);
    });

    test('execution of a hold: held time against the target', () {
      final s = gym(0, [
        hold('2135', 'weighted front plank', [(0, 45, 45), (0, 36, 45)]),
      ]);
      expect(gymExecution(s), closeTo((1 + 0.8) / 2, 1e-9));
    });

    test('a long hold takes longer than a rep set', () {
      final h = GymExercise(exId: '3', name: 'wall sit', restSec: 60, sets: [GymSet(sec: 90), GymSet(sec: 90)]);
      final r = GymExercise(exId: '4', name: 'push-up', restSec: 60, sets: [GymSet(reps: 10), GymSet(reps: 10)]);
      expect(estimateGymMinutes([h]), greaterThan(estimateGymMinutes([r])));
    });
  });

  group('active workout', () {
    ProviderContainer container(ActiveGym g) {
      final c = ProviderContainer(
        overrides: [activeGymProvider.overrideWith(() => _PresetGym(g)), profileProvider.overrideWith((ref) => Stream.value(male80))],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('hold timer: stop logs the held time, checks the set off and starts the rest', () {
      final plank = GymExercise(exId: '2135', name: 'weighted front plank', restSec: 60, sets: [GymSet(sec: 45), GymSet(sec: 45)]);
      final c = container(ActiveGym(title: 't', start: now, exercises: [plank]));
      final n = c.read(activeGymProvider.notifier);
      n.startHold(0, 0);
      expect(c.read(activeGymProvider)!.holding(0, 0), isTrue);
      expect(c.read(activeGymProvider)!.holdTarget, 45);
      n.stopHold(sec: 38);
      final w = c.read(activeGymProvider)!;
      expect(w.holdStart, isNull);
      expect(plank.sets.first.done, isTrue);
      expect(plank.sets.first.sec, 38);
      expect(w.restEnd, isNotNull);
      // Checked off without the timer: the planned time.
      n.skipRest();
      plank.sets[1].sec = 0;
      plank.sets[1].targetSec = 45;
      n.toggleDone(0, 1);
      expect(plank.sets[1].sec, 45);
    });

    test('removing the set cancels a running hold', () {
      final plank = GymExercise(exId: '2135', name: 'weighted front plank', sets: [GymSet(sec: 45), GymSet(sec: 45)]);
      final c = container(ActiveGym(title: 't', start: now, exercises: [plank]));
      final n = c.read(activeGymProvider.notifier);
      n.startHold(0, 1);
      n.removeSet(0, 1);
      expect(c.read(activeGymProvider)!.holdStart, isNull);
      expect(plank.sets, hasLength(1));
    });

    test('switching to timed and back converts the open sets; new sets copy the hold time', () {
      final e = GymExercise(exId: 'x', name: 'dumbbell row', sets: [GymSet(weight: 20, reps: 10), GymSet(weight: 20, reps: 10)]);
      final c = container(ActiveGym(title: 't', start: now, exercises: [e]));
      final n = c.read(activeGymProvider.notifier);
      n.setTimed(0, true);
      expect(e.isTimed, isTrue);
      expect(e.sets.every((s) => s.sec == 30 && s.reps == 0), isTrue);
      n.updateSet(0, 0, sec: 40);
      expect(e.sets[1].sec, 40, reason: 'a new hold time carries over to the open sets');
      n.addSet(0);
      expect(e.sets.last.sec, 40);
      n.setTimed(0, false);
      expect(e.sets.every((s) => s.sec == 0 && s.reps > 0), isTrue);
    });

    test('the finished session keeps the body weight of the day', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // finish() releases the wake lock – no platform in unit tests.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
      );
      final e = reps('0662', 'push-up', [(0, 10)], bw: true, bodyKg: 51.2);
      final c = container(ActiveGym(title: 't', start: now, exercises: [e]));
      c.listen(profileOrDefaultProvider, (_, __) {});
      await c.read(profileProvider.future);
      final s = c.read(activeGymProvider.notifier).finish('id');
      expect(s.bodyWeightKg, 80);
      expect(s.volume, closeTo(512, 1e-6));
    });
  });

  group('UI', () {
    Future<SharedPreferences> prefs({bool table = false}) async {
      SharedPreferences.setMockInitialValues({'gymTableView': table});
      return SharedPreferences.getInstance();
    }

    List<Override> overrides(SharedPreferences p, {ActiveGym? g, List<Session> history = const []}) => [
      prefsProvider.overrideWithValue(p),
      profileProvider.overrideWith((ref) => Stream.value(male80)),
      sessionsProvider.overrideWith((ref) => Stream.value(history)),
      plansProvider.overrideWith((ref) => Stream.value(const <PlannedWorkout>[])),
      bodyProvider.overrideWith((ref) => Stream.value(const <BodyEntry>[])),
      exerciseDbProvider.overrideWith((ref) => Completer<ExerciseDb>().future),
      if (g != null) activeGymProvider.overrideWith(() => _PresetGym(g)),
    ];

    Future<ProviderContainer> pump(WidgetTester t, Widget page, List<Override> o) async {
      t.view.physicalSize = const Size(420, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: o,
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('de'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: page,
          ),
        ),
      );
      await t.pump();
      await t.pump();
      return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    }

    GymExercise plank() => GymExercise(
      exId: '2135',
      name: 'weighted front plank',
      bw: true,
      restSec: 60,
      sets: [GymSet(sec: 45, targetSec: 45), GymSet(sec: 45, targetSec: 45)],
    );

    testWidgets('focus view: hold editor with timer; at the target time the set is checked off', (t) async {
      final p = await prefs();
      final e = plank();
      final c = await pump(t, const ExerciseFocusPage(), overrides(p, g: ActiveGym(title: 'Core', start: now, exercises: [e])));
      expect(find.byKey(const ValueKey('holdStart')), findsOneWidget);
      expect(find.text(de.holdStartBtn('0:45')), findsOneWidget);
      expect(find.text(de.holdTime), findsOneWidget);
      expect(find.text('45 s'), findsNWidgets(2), reason: 'sets show their hold time');
      await t.tap(find.byKey(const ValueKey('holdStart')));
      await t.pump();
      expect(find.byKey(const ValueKey('holdRunning')), findsOneWidget);
      expect(c.read(activeGymProvider)!.holding(0, 0), isTrue);
      // 3-s lead-in ("3, 2, 1"), then the 45-s hold.
      await t.pump(const Duration(seconds: holdLeadInSec + 46));
      expect(e.sets.first.done, isTrue);
      expect(e.sets.first.sec, 45);
      expect(c.read(activeGymProvider)!.restEnd, isNotNull);
      c.read(activeGymProvider.notifier).skipRest();
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('focus view: auto check-off off → the stop button logs the held time', (t) async {
      final p = await prefs();
      await p.setBool(ActiveGymNotifier.holdAutoDoneKey, false);
      final e = plank();
      final c = await pump(t, const ExerciseFocusPage(), overrides(p, g: ActiveGym(title: 'Core', start: now, exercises: [e])));
      await t.tap(find.byKey(const ValueKey('holdStart')));
      await t.pump();
      await t.pump(const Duration(seconds: 46));
      expect(e.sets.first.done, isFalse, reason: 'counts on as a stopwatch');
      expect(find.byKey(const ValueKey('holdStop')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('holdStop')));
      await t.pump();
      expect(e.sets.first.done, isTrue);
      expect(e.sets.first.sec, greaterThanOrEqualTo(1));
      c.read(activeGymProvider.notifier).skipRest();
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('table view: hold rows with time, play and check; running hold in the bottom bar', (t) async {
      final p = await prefs(table: true);
      final e = plank();
      final c = await pump(t, const GymSessionPage(), overrides(p, g: ActiveGym(title: 'Core', start: now, exercises: [e])));
      expect(find.text(de.holdTime), findsOneWidget);
      expect(find.text('0:45'), findsNWidgets(2));
      await t.tap(find.byKey(const ValueKey('holdPlay-0-0')));
      await t.pump();
      expect(find.byKey(const ValueKey('holdBar')), findsOneWidget);
      await t.pump(const Duration(seconds: holdLeadInSec + 1)); // stopped during the lead-in it would just cancel
      await t.tap(find.text(de.holdStop).last);
      await t.pump();
      expect(e.sets.first.done, isTrue);
      expect(find.byKey(const ValueKey('holdBar')), findsNothing);
      c.read(activeGymProvider.notifier).skipRest();
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('overview tile: "2 × 45 s"', (t) async {
      final p = await prefs();
      await pump(t, const GymSessionPage(), overrides(p, g: ActiveGym(title: 'Core', start: now, exercises: [plank()])));
      expect(find.textContaining('2 × 45 s'), findsWidgets);
    });

    testWidgets('program editor: hold range chip and hold fields; toggling timed converts the sets', (t) async {
      final p = await prefs();
      final list = [
        GymExercise(exId: '2135', name: 'weighted front plank', sets: [GymSet(sec: 40)]),
      ];
      await pump(t, Scaffold(body: SingleChildScrollView(child: GymExerciseEditor(exercises: list, onChanged: () {}))), overrides(p));
      expect(find.byKey(const ValueKey('holdRangeChip')), findsOneWidget);
      expect(find.text('30–60 s'), findsOneWidget);
      expect(find.text('0:40'), findsOneWidget);
      expect(find.text(de.holdTime), findsOneWidget);
      await t.tap(find.byIcon(Icons.more_vert));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('timedToggle')));
      await t.pumpAndSettle();
      expect(list.single.timed, isFalse);
      expect(list.single.sets.single.sec, 0);
      expect(list.single.sets.single.reps, greaterThan(0));
    });

    testWidgets('session detail: hold sets, hold time and "incl. body weight"', (t) async {
      final p = await prefs();
      final s = gym(
        1,
        [
          hold('2135', 'weighted front plank', [(0, 45, 45), (5, 40, 45)]),
          reps('0662', 'push-up', [(0, 10)]),
        ],
        bodyWeight: 80,
        id: 's1',
      );
      await pump(t, const SessionDetailPage(sessionId: 's1'), overrides(p, history: [s]));
      expect(find.text('45 s'), findsOneWidget);
      expect(find.text('+5 kg · 40 s'), findsOneWidget);
      expect(find.text(de.volumeInclBodyKg('80 kg')), findsOneWidget);
      expect(find.byKey(const ValueKey('detailHold')), findsOneWidget);
      expect(find.text('1:25'), findsWidgets);
      expect(find.text('10 ×'), findsOneWidget);
    });

    test('labels: sets, legacy reps and summaries', () {
      final e = plank();
      expect(setLabelOf(de, e, e.sets.first, kg), '45 s');
      expect(setLabelOf(de, e, GymSet(weight: 10, sec: 90), kg), '+10 kg · 1:30 min');
      expect(
        setLabelOf(de, e, GymSet(reps: 60, done: true), kg),
        '${de.bodyweightShort} × 60',
        reason: 'stored as reps before hold times existed',
      );
      expect(exerciseSummary(de, e, kg, range: (8, 12)), '2 × 45 s');
      final carry = GymExercise(exId: '2133', name: 'farmers walk', sets: [GymSet(weight: 24, sec: 40)]);
      expect(exerciseSummary(de, carry, kg, range: (8, 12)), '1 × 40 s · 24 kg');
    });
  });
}
