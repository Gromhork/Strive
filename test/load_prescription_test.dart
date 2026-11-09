import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/services/gym_tools.dart';
import 'package:strive/services/load_prescription.dart';

final now = DateTime(2026, 11, 9, 18);
var _id = 0;

Session gym(int daysAgo, List<GymExercise> ex, {String? source}) => Session(
  id: 's${_id++}',
  sport: Sport.gym,
  title: 'Gym',
  start: now.subtract(Duration(days: daysAgo)),
  durationSec: 3600,
  exercises: ex,
  source: source,
);

GymExercise done(String id, String name, List<(double, int)> sets) => GymExercise(
  exId: id,
  name: name,
  sets: [for (final (w, r) in sets) GymSet(weight: w, reps: r, done: true)],
);

GymExercise planned(String id, String name, {int sets = 3, int lo = 6, int hi = 10, double w = 0, bool warmup = false}) =>
    GymExercise(
      exId: id,
      name: name,
      repMin: lo,
      repMax: hi,
      sets: [
        if (warmup) GymSet(type: SetType.warmup),
        if (warmup) GymSet(type: SetType.warmup),
        for (var i = 0; i < sets; i++) GymSet(weight: w, reps: lo),
      ],
    );

const male80 = UserProfile(weightKg: 80, gender: 'm', level: 'intermediate', birthYear: 1996);

LoadPrescriber lp(List<Session> h, [UserProfile p = male80]) => LoadPrescriber(history: h, profile: p, now: now);

final bench = planned('0025', 'barbell bench press');

void main() {
  group('history', () {
    test('double progression: all sets at top of range → add load', () {
      final h = [gym(3, [done('0025', 'barbell bench press', [(60, 10), (60, 10), (60, 10)])])];
      final p = lp(h).forExercise(bench)!;
      expect(p.source, LoadSource.history);
      expect(p.weight, 62.5);
      expect(p.reps, 6);
      expect(p.progression, ProgressionKind.increase);
    });

    test('double progression: inside range → same weight, one more rep per set', () {
      final h = [gym(3, [done('0025', 'barbell bench press', [(60, 9), (60, 8), (60, 7)])])];
      final p = lp(h).forExercise(bench)!;
      expect(p.weight, 60);
      expect(p.progression, ProgressionKind.addReps);
      expect(p.setReps, [10, 9, 8]);
      final applied = lp(h).apply([bench]).single;
      expect(applied.sets.map((s) => s.reps), [10, 9, 8]);
      expect(applied.sets.every((s) => s.weight == 60 && !s.done), isTrue);
    });

    test('outlier session (typo 600 kg) is ignored', () {
      final h = [
        gym(2, [done('0025', 'x', [(600, 10), (600, 10), (600, 10)])]),
        gym(5, [done('0025', 'x', [(60, 8), (60, 8), (60, 8)])]),
        gym(9, [done('0025', 'x', [(57.5, 9), (57.5, 8), (57.5, 8)])]),
        gym(12, [done('0025', 'x', [(57.5, 8), (57.5, 8), (57.5, 7)])]),
        gym(16, [done('0025', 'x', [(55, 9), (55, 9), (55, 8)])]),
      ];
      final p = lp(h).forExercise(bench)!;
      expect(p.weight, 60);
      expect(p.e1rm!, lessThan(90));
    });

    test('single quick set way off is ignored', () {
      final h = [
        gym(1, [done('0025', 'x', [(100, 1)])]),
        gym(4, [done('0025', 'x', [(60, 10), (60, 10), (60, 10)])]),
        gym(8, [done('0025', 'x', [(60, 9), (60, 9), (60, 8)])]),
      ];
      expect(lp(h).forExercise(bench)!.weight, 62.5);
    });

    test('outlier set inside a session is ignored', () {
      final h = [gym(3, [done('0025', 'x', [(60, 10), (600, 10), (60, 10), (60, 10)])])];
      expect(lp(h).forExercise(bench)!.weight, 62.5);
    });

    test('imported / empty sessions and undone or zero-weight sets are ignored', () {
      final h = [
        gym(1, const [], source: 'Samsung Health'),
        gym(2, [done('0025', 'x', [(0, 10), (0, 10)])], source: 'Garmin'),
        gym(2, [
          GymExercise(exId: '0025', name: 'x', sets: [GymSet(weight: 100, reps: 10), GymSet(weight: 100, reps: 10)]),
        ]),
        gym(4, [done('0025', 'x', [(60, 10), (60, 10), (60, 10)])]),
      ];
      final p = lp(h).forExercise(bench)!;
      expect(p.source, LoadSource.history);
      expect(p.weight, 62.5);
    });

    test('break of 3–6 weeks → lighter, > 6 weeks → from e1RM × 0.9', () {
      final s = [(80.0, 8), (80.0, 8), (80.0, 8)];
      final four = lp([gym(35, [done('0025', 'x', s)])]).forExercise(bench)!;
      expect(four.weight, 70); // 80 × 0.9
      expect(four.breakDays, 35);
      expect(lp([gym(25, [done('0025', 'x', s)])]).forExercise(bench)!.weight, 75); // 80 × 0.95 = 76
      final eight = lp([gym(56, [done('0025', 'x', s)])]).forExercise(bench)!;
      // e1RM = 80 × (1 + 9/30) = 104 → × 0.9 at 6 reps RIR 2 ≈ 74.9 → 72.5
      expect(eight.weight, 72.5);
      expect(eight.weight, lessThan(80));
    });

    test('different rep range than last time uses the e1RM', () {
      final h = [gym(3, [done('0025', 'x', [(100, 3), (100, 3), (100, 3)])])];
      final p = lp(h).forExercise(planned('0025', 'x', lo: 12, hi: 15))!;
      // e1RM 100 × (1 + 4/30) ≈ 113 → 12 reps @ RIR 2 ≈ 70
      expect(p.weight, inInclusiveRange(65, 75));
      expect(p.reps, 12);
    });

    test('explicit template weight kept only without history', () {
      final t = planned('0025', 'x', w: 40);
      expect(lp(const []).apply([t]).single.sets.first.weight, 40);
      final h = [gym(3, [done('0025', 'x', [(60, 10), (60, 10), (60, 10)])])];
      expect(lp(h).apply([t]).single.sets.first.weight, 62.5);
    });
  });

  group('setup 1RM', () {
    final prof = male80.copyWith(athlete: const AthleteData(oneRm: {'bench': 100, 'squat': 140, 'deadlift': 180, 'ohp': 60}));

    test('anchor lift', () {
      final p = lp(const [], prof).forExercise(planned('0025', 'x', lo: 5, hi: 8))!;
      expect(p.source, LoadSource.oneRm);
      // 100 / (1 + 7/30) = 81.1 → 80
      expect(p.weight, 80);
    });

    test('mapped exercises', () {
      final x = lp(const [], prof);
      final db = x.forExercise(planned('0289', 'dumbbell bench press', lo: 8, hi: 12))!;
      expect(db.perHand, isTrue);
      expect(db.weight, inInclusiveRange(24, 30)); // 37 kg e1RM per dumbbell
      expect(db.weight % 2, 0);
      final lp45 = x.forExercise(planned('0739', 'sled 45° leg press', lo: 10, hi: 15))!;
      expect(lp45.weight, inInclusiveRange(140, 160));
      final lat = x.forExercise(planned('0334', 'dumbbell lateral raise', lo: 12, hi: 20))!;
      expect(lat.weight, inInclusiveRange(4, 6));
      final rdl = x.forExercise(planned('0085', 'barbell romanian deadlift', lo: 8, hi: 12))!;
      expect(rdl.weight, inInclusiveRange(85, 100));
    });

    test('name heuristic for exercises outside the built-ins', () {
      final x = lp(const [], prof);
      final ezCurl = x.forExercise(planned('9999', 'ez barbell curl', lo: 8, hi: 12))!;
      expect(ezCurl.weight, inInclusiveRange(25, 35));
      final cableRow = x.forExercise(planned('9998', 'cable one arm row', lo: 8, hi: 12))!;
      expect(cableRow.weight, inInclusiveRange(45, 60));
      expect(x.forExercise(planned('9997', 'mystery move')), isNull);
    });

    test('missing anchor inferred from the others', () {
      final p2 = male80.copyWith(athlete: const AthleteData(oneRm: {'bench': 100}));
      final (ohp, src) = lp(const [], p2).anchorOneRm(Anchor.ohp);
      expect(src, LoadSource.oneRm);
      expect(ohp, closeTo(65, 0.1));
    });
  });

  group('estimate', () {
    test('intermediate 80 kg male bench 8 reps ≈ 50–70 kg', () {
      final p = lp(const []).forExercise(planned('0025', 'x', lo: 8, hi: 12))!;
      expect(p.source, LoadSource.estimate);
      expect(p.weight, inInclusiveRange(50, 70));
    });

    test('women, beginners and older lifters get lighter loads; empty bar minimum', () {
      final f = male80.copyWith(gender: 'f', weightKg: 60, level: 'beginner');
      final bm = lp(const []).forExercise(planned('0025', 'x', lo: 8, hi: 12))!.weight;
      final bf = lp(const [], f).forExercise(planned('0025', 'x', lo: 8, hi: 12))!.weight;
      expect(bf, lessThan(bm));
      expect(bf, 20);
      final old = lp(const [], male80.copyWith(birthYear: 1960)).forExercise(planned('0043', 'x'))!.weight;
      final young = lp(const []).forExercise(planned('0043', 'x'))!.weight;
      expect(old, lessThan(young));
    });
  });

  group('phase', () {
    final h = [gym(3, [done('0025', 'x', [(60, 9), (60, 8), (60, 8)])])];

    test('deload week: ~90 % load and one set fewer', () {
      final p = lp(h).forExercise(bench, phase: 'recovery')!;
      expect(p.weight, 52.5); // 60 × 0.9 = 54 → 52.5 on the 2.5 kg grid
      expect(p.phaseAdjusted, isTrue);
      final applied = lp(h).apply([bench], phase: 'recovery').single;
      expect(applied.workSets.length, 2);
    });

    test('taper: lighter, same sets; build: unchanged', () {
      expect(lp(h).apply([bench], phase: 'taper').single.workSets.length, 3);
      expect(lp(h).forExercise(bench, phase: 'taper')!.weight, 52.5);
      expect(lp(h).forExercise(bench, phase: 'build')!.weight, 60);
    });
  });

  group('bodyweight & rounding', () {
    test('bodyweight exercise: no load, reps progress from history', () {
      final pu = planned('0652', 'pull-up', lo: 6, hi: 10);
      final none = lp(const []).forExercise(pu)!;
      expect(none.source, LoadSource.bodyweight);
      expect(none.weight, 0);
      expect(none.reps, 6);
      final h = [gym(3, [done('0652', 'pull-up', [(0, 8), (0, 7), (0, 6)])])];
      final p = lp(h).forExercise(pu)!;
      expect(p.source, LoadSource.bodyweight);
      expect(p.fromHistory, isTrue);
      expect(p.weight, 0);
      expect(p.setReps, [9, 8, 7]);
    });

    test('rounding: dumbbells 2 kg, machines 2.5 kg, odd real weights kept', () {
      final x = lp(const []);
      expect(x.forExercise(planned('0289', 'dumbbell bench press'))!.weight % 2, 0);
      expect(x.forExercise(planned('0585', 'lever leg extension', lo: 10, hi: 15))!.weight % 2.5, 0);
      final h = [gym(3, [done('0289', 'x', [(22.5, 12), (22.5, 12), (22.5, 12)])])];
      final p = lp(h).forExercise(planned('0289', 'x', lo: 8, hi: 12))!;
      expect(p.weight, 24.5); // 22.5 + 2 kg step
    });

    test('warm-up sets derive from the work weight', () {
      final h = [gym(3, [done('0043', 'x', [(100, 8), (100, 8), (100, 8)])])];
      final e = lp(h).apply([planned('0043', 'barbell full squat', lo: 5, hi: 8, warmup: true)]).single;
      final warm = e.sets.where((s) => s.warmup).toList();
      expect(warm.length, 2);
      expect(warm.first.weight, lessThan(warm.last.weight));
      expect(warm.last.weight, lessThan(e.workSets.first.weight));
      expect(e.workSets.first.weight, 105);
    });
  });
}
