import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/session/music.dart';
import 'package:strive/l10n/gen/app_localizations_de.dart';
import 'package:strive/l10n/gen/app_localizations_en.dart';
import 'package:strive/services/active_workout.dart';

void main() {
  final de = AppLocalizationsDe();
  final en = AppLocalizationsEn();

  group('step intensity', () {
    test('warm-up, cool-down and rests are easy whatever the zone', () {
      expect(musicIdOfStep(const WorkoutStep(kind: 'warmup', zone: 'Z4')), MusicId.easy);
      expect(musicIdOfStep(const WorkoutStep(kind: 'recovery', zone: 'I')), MusicId.easy);
      expect(musicIdOfStep(const WorkoutStep(kind: 'cooldown', zone: 'T')), MusicId.easy);
      expect(musicIdOfStep(null), MusicId.easy);
    });
    test('work steps follow the zone', () {
      expect(musicIdOfStep(const WorkoutStep(kind: 'work', zone: 'E')), MusicId.easy);
      expect(musicIdOfStep(const WorkoutStep(kind: 'work', zone: 'M')), MusicId.steady);
      expect(musicIdOfStep(const WorkoutStep(kind: 'work', zone: 'SS')), MusicId.steady);
      expect(musicIdOfStep(const WorkoutStep(kind: 'work', zone: 'T')), MusicId.hard);
      expect(musicIdOfStep(const WorkoutStep(kind: 'work', zone: 'Z4')), MusicId.hard);
      expect(musicIdOfStep(const WorkoutStep(kind: 'work', zone: 'I')), MusicId.max);
      expect(musicIdOfStep(const WorkoutStep(kind: 'work', zone: 'Z5')), MusicId.max);
      expect(musicIdOfStep(const WorkoutStep(kind: 'work', zone: 'R')), MusicId.max);
    });
  });

  group('sport-specific suggestions', () {
    String all(MusicPlan p) => [p.intro, p.hint ?? '', for (final o in p.options) '${o.title} ${o.sub} ${o.query}'].join(' | ');

    test('cycling never uses running wording and matches cadence', () {
      for (final indoor in [false, true]) {
        final p = musicPlan(de, Sport.ride, indoor: indoor, now: MusicId.easy);
        final text = all(p).toLowerCase();
        expect(text, isNot(contains('lauf')));
        expect(text, isNot(contains('running')));
        expect(p.now!.title, 'Lockere Fahrt');
        expect(p.now!.sub, contains('U/min'));
        expect(p.options.every((o) => o.query.contains('cycling') || o.query.contains('spinning')), isTrue);
      }
      // Safety note outdoors only.
      expect(musicPlan(de, Sport.ride).hint, isNotNull);
      expect(musicPlan(de, Sport.ride, indoor: true).hint, isNull);
      expect(musicPlan(en, Sport.ride, now: MusicId.max).now!.title, 'Intervals & sprints');
    });

    test('running: right now follows the step and uses cadence-matched BPM', () {
      final p = musicPlan(de, Sport.run, now: musicIdOfStep(const WorkoutStep(kind: 'work', zone: 'I')));
      expect(p.now!.title, 'Intervalle & Steigerungen');
      expect(p.now!.sub, '180–190 BPM');
      expect(musicPlan(de, Sport.run, now: MusicId.easy).now!.sub, '150–160 BPM');
      expect(all(p).toLowerCase(), isNot(contains('cycling')));
    });

    test('swimming: no "right now" pick, waterproof headphone hint, no running/cycling wording', () {
      for (final indoor in [true, false]) {
        final p = musicPlan(de, Sport.swim, indoor: indoor, now: MusicId.hard);
        expect(p.now, isNull);
        expect(p.hint, contains('Knochenschall'));
        final text = all(p).toLowerCase();
        expect(text, isNot(contains('lauf')));
        expect(text, isNot(contains('cycling')));
      }
    });

    test('gym: strength 120–135 BPM, circuits higher, all options are gym specific', () {
      final p = musicPlan(en, Sport.gym, now: MusicId.strength);
      expect(p.now!.title, 'Strength training');
      expect(p.now!.sub, '120–135 BPM');
      expect(p.options.map((o) => o.id), containsAll([MusicId.warmup, MusicId.heavy, MusicId.circuit, MusicId.cooldown]));
      expect(all(p).toLowerCase(), isNot(contains('running')));
    });
  });

  group('gym right now', () {
    GymExercise ex(String id, List<GymSet> sets, {String? group}) => GymExercise(exId: id, name: id, sets: sets)..group = group;
    ActiveGym gym(List<GymExercise> e, {int focus = 0}) => ActiveGym(title: 'T', start: DateTime(2026), exercises: e, focus: focus);

    test('warm-up sets first, then strength', () {
      final w = gym([
        ex('squat', [GymSet(reps: 8, type: SetType.warmup), GymSet(reps: 8), GymSet(reps: 8)]),
      ]);
      expect(gymMusicNow(w), MusicId.warmup);
      w.exercises[0].sets[0].done = true;
      expect(gymMusicNow(w), MusicId.strength);
    });
    test('low-rep sets are heavy, supersets are circuits, done is cool-down', () {
      expect(
        gymMusicNow(
          gym([
            ex('dl', [GymSet(reps: 3), GymSet(reps: 3)]),
          ]),
        ),
        MusicId.heavy,
      );
      final ss = gym([
        ex('a', [GymSet(reps: 12)], group: 'A'),
        ex('b', [GymSet(reps: 12)], group: 'A'),
      ]);
      expect(gymMusicNow(ss), MusicId.circuit);
      expect(
        gymMusicNow(
          gym([
            ex('a', [GymSet(reps: 10, done: true)]),
          ]),
        ),
        MusicId.cooldown,
      );
    });
  });
}
