import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/default_programs.dart';
import 'package:strive/data/models.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/plan_gaps.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_recalibrate.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  var n = 0;
  String id() => 'p${n++}';
  final templates = defaultTemplates(id, de: true);
  final start = DateTime(2026, 11, 2); // Monday
  final now = DateTime(2026, 11, 18, 7); // Wednesday of week 3, before training

  UserProfile profile({DateTime? event, String? distance, bool meta = true, int weeks = 10}) {
    final p = UserProfile(
      level: 'intermediate',
      focus: TrainingFocus.run,
      birthYear: 1990,
      trainingDays: const [1, 2, 4, 6, 7],
      longDay: 6,
      athlete: AthleteData(
        raceTimes: const {'10k': 50 * 60},
        runWeeklyKm: 30,
        longestRunKm: 12,
        sessionMinutes: 90,
        planWeeks: weeks,
        eventDate: event,
        eventDistance: distance,
      ),
    );
    return meta ? withPlanMeta(p, start, weeks) : p;
  }

  /// The generated plan; every workout before [at] done as planned (distance × [ratio]).
  (List<PlannedWorkout>, List<Session>) history(UserProfile p, {DateTime? at, double Function(PlannedWorkout w)? ratio}) {
    final plan = PlanGenerator(l, p, templates, id).generate(start: start, weeks: p.athlete.planWeeks);
    final plans = <PlannedWorkout>[];
    final sessions = <Session>[];
    for (final w in plan) {
      if (!dayOnly(w.date).isBefore(dayOnly(at ?? now))) {
        plans.add(w);
        continue;
      }
      final r = ratio?.call(w) ?? 1.0;
      final s = Session(
        id: 's${w.id}',
        sport: w.sport,
        title: w.title,
        start: w.date.add(const Duration(hours: 18)),
        durationSec: (w.durationMin * 60 * r).round(),
        distanceM: (w.distanceKm ?? 0) * 1000 * r,
        rpe: switch (w.intensity) {
          'tempo' || 'intervals' => 7,
          _ => 3,
        },
        planId: w.id,
      );
      sessions.add(s);
      plans.add(PlannedWorkout.fromMap(w.id, {...w.toMap(), 'status': 'done', 'sessionId': s.id}));
    }
    return (plans, sessions);
  }

  Recalibration recal(UserProfile p, List<PlannedWorkout> plans, List<Session> sessions, {DateTime? at}) =>
      Recalibrator(l, p, plans: plans, sessions: sessions, now: at ?? now, templates: templates, newId: id).run();
  List<RecalChange> added(Recalibration r) => r.changes.where((c) => c.kind == RecalKind.added).toList();
  DateTime day(int offset) => dayOnly(now).add(Duration(days: offset));
  int weekMin(Iterable<PlannedWorkout> ps, DateTime monday) => ps
      .where((p) => p.status != 'skipped' && !p.date.isBefore(monday) && p.date.isBefore(monday.add(const Duration(days: 7))))
      .fold(0, (x, p) => x + p.durationMin);

  /// Applying the proposal and running again proposes no further refills.
  void expectIdempotent(UserProfile p, List<PlannedWorkout> plans, List<Session> sessions, Recalibration r, {DateTime? at}) {
    final again = recal(p, [...plans, ...r.additions], sessions, at: at);
    expect(added(again), isEmpty, reason: added(again).map((c) => '${dayKey(c.after.date)} ${c.after.title}').join(', '));
  }

  for (final meta in [true, false]) {
    test('complete plan: nothing to fill (${meta ? 'stored plan start' : 'start reconstructed'})', () {
      final p = profile(meta: meta);
      final (plans, sessions) = history(p);
      final r = recal(p, plans, sessions);
      expect(added(r), isEmpty, reason: added(r).map((c) => '${dayKey(c.after.date)} ${c.after.title}').join(', '));
      expect(r.reasons, isNot(contains(RecalReason.planGaps)));
    });

    test('deleted session mid-week is proposed again (${meta ? 'stored' : 'reconstructed'})', () {
      final p = profile(meta: meta);
      final (all, sessions) = history(p);
      final gone = all.firstWhere((w) => sameDay(w.date, day(1))); // Thursday
      final plans = [...all]..remove(gone);
      final r = recal(p, plans, sessions);
      final a = added(r);
      expect(a.length, 1);
      expect(sameDay(a.single.after.date, gone.date), isTrue);
      expect(a.single.after.sport, gone.sport);
      expect(a.single.after.intensity, gone.intensity);
      expect(a.single.after.durationMin, closeTo(gone.durationMin, 5));
      expect(a.single.gap!.why, GapWhy.missing);
      expect(a.single.after.id, isNot(gone.id));
      expect(r.additions.single.status, 'planned');
      expect(r.updates.keys, isNot(contains(a.single.after.id)));
      expect(r.reasons, contains(RecalReason.planGaps));
      expectIdempotent(p, plans, sessions, r);
    });
  }

  test('whole next week empty: its sessions come back, rest days stay free, volume within the planned week', () {
    final p = profile();
    final (all, sessions) = history(p);
    final monday = DateTime(2026, 11, 23);
    final week = all.where((w) => !w.date.isBefore(monday) && w.date.isBefore(monday.add(const Duration(days: 7)))).toList();
    expect(week, isNotEmpty);
    final plans = all.where((w) => !week.contains(w)).toList();
    final r = recal(p, plans, sessions);
    final a = added(r);
    expect(a.length, week.length);
    expect({for (final c in a) dayKey(c.after.date)}, {for (final w in week) dayKey(w.date)});
    for (final c in a) {
      expect(c.gap!.why, GapWhy.emptyWeek);
      expect(const [3, 5], isNot(contains(c.after.date.weekday)), reason: 'rest days are never filled');
    }
    expect(weekMin(r.additions, monday), lessThanOrEqualTo(weekMin(week, monday)));
    expectIdempotent(p, plans, sessions, r);
  });

  test('plan ended two weeks before the event: taper and race come back, nothing after race day', () {
    final event = DateTime(2027, 1, 10); // Sunday of week 10
    final p = profile(event: event, distance: 'hm');
    final at = DateTime(2026, 12, 23, 7); // three weeks before
    final (all, sessions) = history(p, at: at);
    expect(all.any((w) => w.intensity == 'race' && sameDay(w.date, event)), isTrue);
    final cut = DateTime(2026, 12, 28); // last two weeks deleted
    final plans = all.where((w) => w.date.isBefore(cut)).toList();
    final r = recal(p, plans, sessions, at: at);
    final a = added(r);
    final deleted = all.where((w) => !w.date.isBefore(cut)).toList();
    expect(a.length, deleted.length);
    expect(a.where((c) => c.after.intensity == 'race' && sameDay(c.after.date, event)).length, 1);
    expect(a.every((c) => !dayOnly(c.after.date).isAfter(event)), isTrue);
    expect(a.every((c) => c.after.phase == 'taper'), isTrue);
    expectIdempotent(p, plans, sessions, r, at: at);
  });

  test('no event: a plan that ends inside the horizon is continued at its last volume', () {
    final p = profile(weeks: 4); // ends Sunday 29 Nov
    final (plans, sessions) = history(p);
    final r = recal(p, plans, sessions);
    final a = added(r);
    expect(a, isNotEmpty);
    expect(a.every((c) => c.gap!.why == GapWhy.planEnded), isTrue);
    expect(a.every((c) => !c.after.date.isBefore(DateTime(2026, 11, 30))), isTrue);
    // Last horizon day: Sunday of the 4th week after this one.
    expect(a.every((c) => c.after.date.isBefore(DateTime(2026, 12, 21))), isTrue);
    double km(Iterable<PlannedWorkout> ps, DateTime monday) => ps
        .where((w) => !w.date.isBefore(monday) && w.date.isBefore(monday.add(const Duration(days: 7))))
        .fold(0, (x, w) => x + (w.distanceKm ?? 0));
    final loading = [
      for (final m in [DateTime(2026, 11, 2), DateTime(2026, 11, 9), DateTime(2026, 11, 16)]) km(plans, m),
    ].reduce(max);
    expect(km(r.additions, DateTime(2026, 11, 30)), lessThanOrEqualTo(loading * 1.1 + 0.5));
    expect(a.every((c) => const [3, 5].contains(c.after.date.weekday) == false), isTrue);
    expectIdempotent(p, plans, sessions, r);
  });

  test('deleted long run: the refill respects the R1 cap', () {
    final p = profile();
    // The long runs so far ended at 60 %: the longest recent run is short.
    final (all, sessions) = history(p, ratio: (w) => w.intensity == 'long' ? 0.6 : 1.0);
    final long = all.firstWhere((w) => w.intensity == 'long' && w.status == 'planned');
    final plans = [...all]..remove(long);
    final r = recal(p, plans, sessions);
    final refill = added(r).singleWhere((c) => sameDay(c.after.date, long.date));
    expect(refill.after.intensity, 'long');
    final longest = sessions
        .where((s) => s.sport == Sport.run && now.difference(s.start).inDays <= 30)
        .map((s) => s.distanceM / 1000)
        .reduce(max);
    expect(refill.after.distanceKm!, lessThanOrEqualTo(longest * 1.1 * 1.03));
    expect(refill.after.distanceKm!, lessThan(long.distanceKm!));
    expect(refill.gap!.shortened, isTrue);
  });

  test('deleted quality session next to a hard day comes back easy', () {
    final p = profile();
    final (all, sessions) = history(p);
    final q = all.firstWhere((w) => w.status == 'planned' && (w.intensity == 'tempo' || w.intensity == 'intervals'));
    // A hard ride the athlete added by hand the day after.
    final ride = PlannedWorkout(
      id: 'ride',
      date: q.date.add(const Duration(days: 1)),
      sport: Sport.ride,
      title: 'Intervals',
      intensity: 'intervals',
      durationMin: 60,
    );
    final plans = [...all..remove(q), ride];
    final r = recal(p, plans, sessions);
    final refill = added(r).singleWhere((c) => sameDay(c.after.date, q.date));
    expect(refill.after.intensity, 'easy');
    expect(refill.after.isKey, isFalse);
    expect(refill.gap!.downgraded, isTrue);
    expect(refill.after.durationMin, lessThanOrEqualTo(q.durationMin));
  });

  test('a missing hard session next to a race is left out, with a reason', () {
    final p = profile();
    final (all, sessions) = history(p);
    final q = all.firstWhere((w) => w.status == 'planned' && (w.intensity == 'tempo' || w.intensity == 'intervals'));
    // A swim race the athlete entered by hand the day before.
    final race = PlannedWorkout(
      id: 'race',
      date: q.date.subtract(const Duration(days: 1)),
      sport: Sport.swim,
      title: 'Race',
      intensity: 'race',
      durationMin: 30,
      isKey: true,
    );
    final r = recal(p, [...all..remove(q), race], sessions);
    expect(added(r).where((c) => sameDay(c.after.date, q.date)), isEmpty);
    expect(r.reasons, contains(RecalReason.gapsOmitted));
  });
  test('intentional rest days, skipped sessions, past and today\'s gaps stay as they are', () {
    final p = profile();
    final (all, sessions) = history(p);
    final skipped = all.firstWhere((w) => sameDay(w.date, day(1)));
    final past = all.firstWhere((w) => sameDay(w.date, day(-2))); // Monday, done
    final plans = [
      for (final w in all)
        if (w == skipped) PlannedWorkout.fromMap(w.id, {...w.toMap(), 'status': 'skipped'}) else if (w != past) w,
    ];
    final r = recal(p, plans, sessions);
    expect(added(r), isEmpty, reason: added(r).map((c) => '${dayKey(c.after.date)} ${c.after.title}').join(', '));
    // Today's session deleted: today is the athlete's call, not refilled.
    final tue = DateTime(2026, 11, 17, 7);
    final (all2, sessions2) = history(p, at: tue);
    final today = all2.firstWhere((w) => sameDay(w.date, tue));
    final r2 = recal(p, [...all2]..remove(today), sessions2, at: tue);
    expect(added(r2), isEmpty);
  });

  test('AI / own plan (planLength 0) and no generated plan: nothing to fill', () {
    final p = profile();
    final (all, sessions) = history(p);
    final ai = p.copyWith(athlete: p.athlete.merge({'planLength': 0}));
    expect(added(recal(ai, all.where((w) => !sameDay(w.date, day(1))).toList(), sessions)), isEmpty);
    final own = [
      for (final w in all) PlannedWorkout.fromMap(w.id, {...w.toMap()}..remove('phase')),
    ];
    expect(added(recal(profile(meta: false), own.where((w) => !sameDay(w.date, day(1))).toList(), sessions)), isEmpty);
  });

  test('plan metadata round-trips and stays optional', () {
    final p = withPlanMeta(const UserProfile(), DateTime(2026, 11, 2, 15), 8);
    final back = UserProfile.fromMap(p.toMap());
    expect(back.athlete.planStart, DateTime(2026, 11, 2));
    expect(back.athlete.planLength, 8);
    expect(UserProfile.fromMap(const UserProfile().toMap()).athlete.planStart, isNull);
    expect(const UserProfile().toMap()['athlete'], isNot(contains('planStart')));
  });
}
