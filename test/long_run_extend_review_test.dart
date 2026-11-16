import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/core/theme.dart';
import 'package:strive/data/models.dart';
import 'package:strive/data/repository.dart';
import 'package:strive/features/calendar/feasibility_card.dart';
import 'package:strive/features/calendar/plan_editor.dart';
import 'package:strive/features/onboarding/onboarding_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/providers.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/plan_recalibrate.dart';
import 'package:strive/services/zones.dart';

/// Review of the long-run cap opt-in (PR #68, 2026-11): the extension's distance to race day counted from the
/// run's own day, a note that only speaks of the cap when the cap is the limit (with the plan's own numbers),
/// consent per event, recovery after the last extended run, one "worth it" rule for plan and note, the switch
/// of "Plan neu aufsetzen" saved with the rebuild, and the recalibration's +5 % stopping at the cap.
final _start = DateTime(2026, 11, 9); // Monday

UserProfile _p(
  String ev, {
  int tenK = 68 * 60,
  Map<int, int> dayMinutes = const {6: 300},
  bool extend = false,
  int weeks = 18,
  int raceWeekday = 7,
  int longDay = 6,
  List<int> days = const [1, 2, 4, 6, 7],
  double longest = 16,
  DateTime? monday,
}) {
  final m = monday ?? _start;
  return UserProfile(
    name: 'Mia',
    level: 'intermediate',
    focus: TrainingFocus.run,
    birthYear: DateTime.now().year - 35,
    experience: const {Sport.run},
    trainingDays: days,
    longDay: longDay,
    goals: const ['race'],
    onboarded: true,
    athlete: AthleteData(
      setupMode: 'advanced',
      sessionMinutes: 75,
      dayMinutes: dayMinutes,
      raceTimes: {'10k': tenK},
      runWeeklyKm: 35,
      longestRunKm: longest,
      eventDistance: ev,
      eventDate: addDays(m, 7 * (weeks - 1) + raceWeekday - 1),
      longRunExtend: extend,
    ),
  );
}

const _dayNames = ['', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];

class _FakeRepo extends Repository {
  _FakeRepo() : super('test');
  var _n = 0;
  final savedProfiles = <UserProfile>[];
  final savedPlans = <PlannedWorkout>[];
  @override
  String newId() => 'id${_n++}';
  @override
  void saveProfile(UserProfile p) => savedProfiles.add(p);
  @override
  Future<void> saveTemplates(List<WorkoutTemplate> list) async {}
  @override
  Future<void> savePlans(List<PlannedWorkout> list) async => savedPlans.addAll(list);
  @override
  Future<void> replacePlans(List<PlannedWorkout> all, DateTime from, List<PlannedWorkout> plan, {Set<String> keep = const {}}) async =>
      savedPlans.addAll(plan);
  @override
  Future<List<WorkoutTemplate>?> templatesFromServer() async => null;
}

void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  String id() => 'x';
  List<PlannedWorkout> gen(UserProfile p) => PlanGenerator(l, p, const [], id).generate(start: _start);
  List<PlannedWorkout> longs(List<PlannedWorkout> plan) =>
      plan.where((w) => w.sport == Sport.run && w.intensity == 'long').toList()..sort((a, b) => a.date.compareTo(b.date));
  List<PlannedWorkout> beyond(List<PlannedWorkout> plan, int capMin) => longs(plan).where((w) => w.durationMin > capMin + 2).toList();
  PlanFeasibility feas(UserProfile p) => PlanGenerator.feasibility(p, start: _start, l: l);
  String issue(PlanFeasibility f, String key, {bool canSwitch = false}) =>
      (f.extraIssueText(l, key, dayName: (d) => _dayNames[d], canSwitch: canSwitch) ?? '').replaceAll(nbsp, ' ');
  String sig(PlannedWorkout w) => '${dayKey(w.date)} ${w.title} ${w.durationMin} ${w.distanceKm}';
  String dur(int m) => formatMinutes(m).replaceAll(nbsp, ' ');
  String kmText(double v) => v.toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '');

  group('1 – at least 3 weeks before the race, counted from the day of the run', () {
    for (final (ev, cap, weeks, longDay, raceWd, name) in const [
      ('m', 180, 18, 7, 6, 'Sunday long run, Saturday race'),
      ('m', 180, 18, 7, 3, 'Sunday long run, Wednesday race'),
      ('m', 180, 18, 6, 4, 'Saturday long run, Thursday race'),
      ('m', 180, 18, 7, 1, 'Sunday long run, Monday race'),
      ('ultra50', 210, 24, 7, 6, 'Sunday long run, Saturday race'),
      ('ultra50', 210, 24, 6, 3, 'Saturday long run, Wednesday race'),
    ]) {
      test('$ev: $name', () {
        final p = _p(ev, weeks: weeks, longDay: longDay, raceWeekday: raceWd, dayMinutes: {longDay: 300}, extend: true);
        final plan = gen(p);
        final race = dayOnly(p.athlete.eventDate!);
        final ext = beyond(plan, cap);
        expect(ext, isNotEmpty, reason: 'the plan still has its extended runs');
        expect(ext.length, lessThanOrEqualTo(2));
        for (final w in ext) {
          expect(w.date.weekday, longDay);
          expect(daysBetween(dayOnly(w.date), race), greaterThanOrEqualTo(21), reason: '${w.date} → $race');
        }
        // The note counts the same runs.
        expect(feas(p).capNote!.extendRuns, ext.length);
      });
    }

    test('short plans, race weekday before the long day: never inside the last 21 days', () {
      for (final weeks in [4, 5, 6, 7, 8, 10]) {
        final p = _p('m', weeks: weeks, longDay: 7, raceWeekday: 6, dayMinutes: const {7: 300}, longest: 21, extend: true);
        for (final w in beyond(gen(p), 180)) {
          expect(daysBetween(dayOnly(w.date), dayOnly(p.athlete.eventDate!)), greaterThanOrEqualTo(21), reason: '$weeks weeks');
        }
      }
    });
  });

  group('2 – the note speaks of the cap only when the cap is the limit', () {
    final three = _p('m', days: const [2, 4, 6]);

    test('three runs a week: the volume keeps the long run below 3 h – no cap note, no switch, real numbers', () {
      final plan = gen(three);
      final top = longs(plan).reduce((a, b) => runningKm(b) > runningKm(a) ? b : a);
      final longest = longs(plan).fold(0, (x, w) => x > w.durationMin ? x : w.durationMin);
      expect(longest, lessThan(175), reason: 'premise: the cap (180) is not what stops these runs');
      for (final p in [
        three,
        _p('m', days: const [2, 4, 6], extend: true),
      ]) {
        final f = feas(p);
        expect(f.issues, isNot(contains('longRunTimeCap')));
        expect(f.capNote, isNull);
        expect(f.issues, contains('runFrequency'));
        final t = issue(f, 'runFrequency');
        // The plan's real longest long run, km and time – and the real limit.
        expect(f.planLongKm, runningKm(top));
        expect(f.planLongMin, longest);
        expect(t, contains('etwa ${kmText(runningKm(top))} km (${dur(longest)})'));
        expect(t, contains('Die Grenze setzen die Läufe pro Woche, nicht deine Zeit.'));
        expect(t, isNot(contains('enden bei 3 h')));
      }
      // The switch changes nothing there – and is not offered.
      expect(gen(_p('m', days: const [2, 4, 6], extend: true)).map(sig).toList(), plan.map(sig).toList());
    });

    testWidgets('three runs a week: the card has no switch', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: SizedBox(width: 320, child: FeasibilityCard(feas(three), onExtendLongRun: (_) {}))),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('extendLongRun')), findsNothing);
      expect(find.byKey(const ValueKey('feasWarnIcon')), findsOneWidget, reason: 'too few runs a week is a real problem');
      expect(tester.takeException(), isNull);
    });

    test('the switch is shown only where it does something – or to take it back', () {
      const base = LongRunCapNote(capMin: 180, capKm: 21.5, raceKm: 28, extendMaxMin: 210);
      expect(base.gains, isFalse);
      expect(base.showSwitch, isFalse, reason: 'offered nothing: no dead switch');
      const offer = LongRunCapNote(capMin: 180, capKm: 21.5, raceKm: 28, extendMaxMin: 210, extendMin: 210, extendKm: 24.8, extendRuns: 2);
      expect(offer.showSwitch, isTrue);
      const onNoGain = LongRunCapNote(capMin: 180, capKm: 21.5, raceKm: 28, extendMaxMin: 210, extendOn: true);
      expect(onNoGain.showSwitch, isTrue);
      expect(const LongRunCapNote(capMin: 180, capKm: 21.5, raceKm: 28).showSwitch, isFalse);
    });

    test('"cannot use them" names the real reason: too few weeks or the weekly volume', () {
      String t(LongRunCapNote n) => n.text(l, dayName: (d) => _dayNames[d]).replaceAll(nbsp, ' ');
      const weeks = LongRunCapNote(capMin: 180, capKm: 21.5, raceKm: 28, extendMaxMin: 210, extendOn: true);
      expect(t(weeks), contains('Es bleiben zu wenige Wochen'));
      expect(t(weeks), isNot(contains('Wochenumfang')));
      const volume = LongRunCapNote(capMin: 180, capKm: 21.5, raceKm: 28, extendMaxMin: 210, extendOn: true, noGainByVolume: true);
      expect(t(volume), contains('Dein Wochenumfang trägt keinen längeren langen Lauf'));
      expect(t(volume), isNot(contains('zu wenige Wochen')));
      // Plans set up a few weeks before the race: no week left for an extended run – never "weekly volume".
      for (final w in [3, 4]) {
        final short = _p('m', weeks: w, longest: 21, extend: true);
        expect(beyond(gen(short), 180), isEmpty, reason: '$w weeks');
        final n = feas(short).capNote;
        if (n == null) continue;
        expect(n.gains, isFalse);
        expect(n.noGainByVolume, isFalse);
        expect(t(n), contains('Es bleiben zu wenige Wochen'));
      }
    });
  });

  group('3 – cap and distance of the note are those of the plan', () {
    test('slow half-marathon runner whose plan reaches 15 km: no finish-goal note', () {
      final p = _p('hm', tenK: 80 * 60, weeks: 14);
      final top = longs(gen(p)).fold(0.0, (x, w) => x > runningKm(w) ? x : runningKm(w));
      expect(top, greaterThanOrEqualTo(15), reason: 'premise');
      final f = feas(p);
      expect(f.issues, isNot(contains('longRunTimeCap')));
      expect(f.capNote, isNull);
      expect(f.issues, isEmpty);
    });

    test('note cap == cap of the day-time hint == longest long run of the plan (HM, 10 km, marathon, ultra)', () {
      var notes = 0;
      for (final (ev, weeks) in const [('hm', 14), ('10k', 12), ('m', 18), ('ultra50', 24)]) {
        for (final tenK in const [56, 68, 80, 100]) {
          final p = _p(ev, tenK: tenK * 60, weeks: weeks);
          final f = feas(p);
          final hint = PlanGenerator.longCapsBelowDayTime(p).where((c) => c.sport == Sport.run).single;
          final plan = longs(gen(p));
          final longest = plan.fold(0, (x, w) => x > w.durationMin ? x : w.durationMin);
          expect(longest, lessThanOrEqualTo(hint.capMin + 2), reason: '$ev $tenK: the "at most" of the hint');
          final n = f.capNote;
          if (n == null) {
            expect(f.issues, isNot(contains('longRunTimeCap')), reason: '$ev $tenK');
            continue;
          }
          notes++;
          expect(n.capMin, hint.capMin, reason: '$ev $tenK');
          // (Within a 0.5 km step of the cap; a race-pace finish makes the same km a few minutes shorter.)
          expect(longest, inInclusiveRange(n.capMin - 12, n.capMin + 2), reason: '$ev $tenK: longest $longest');
          expect(n.capKm, plan.fold(0.0, (x, w) => x > runningKm(w) ? x : runningKm(w)), reason: '$ev $tenK');
          expect(n.capKm, lessThan(n.raceKm * 0.9), reason: '$ev $tenK');
          expect(issue(f, 'longRunTimeCap'), contains('enden bei ${dur(n.capMin)}'));
        }
      }
      expect(notes, greaterThanOrEqualTo(4), reason: 'the slow profiles do get the note');
    });

    test('a very slow half-marathon runner: the note names the 2:30 h the plan really runs', () {
      final f = feas(_p('hm', tenK: 100 * 60, weeks: 14));
      expect(f.issues, contains('longRunTimeCap'));
      expect(f.capNote!.capMin, 150);
      expect(f.capNote!.extendMaxMin, isNull);
      final t = issue(f, 'longRunTimeCap');
      expect(t, contains('enden bei 2:30 h'));
      expect(t, isNot(contains('enden bei 2 h')));
    });
  });

  group('4 – the consent belongs to one event', () {
    test('another event distance resets it; other changes and an explicit value keep it', () {
      final on = _p('m', extend: true).athlete;
      expect(on.merge({'eventDistance': 'ultra50'}).longRunExtend, isFalse);
      expect(on.merge({'eventDistance': null}).longRunExtend, isFalse);
      expect(on.merge({'eventDistance': 'm', 'targetTimeSec': null}).longRunExtend, isTrue, reason: 'same event');
      expect(on.merge({'eventDate': DateTime(2027, 5, 1)}).longRunExtend, isTrue);
      expect(on.merge({'eventDistance': 'ultra50', 'longRunExtend': true}).longRunExtend, isTrue, reason: 'asked again and allowed');
    });

    test('marathon → ultra: no 4 h runs without asking, and the change summary says so', () async {
      await initializeDateFormatting('de');
      final m = _p('m', extend: true, weeks: 24);
      final ultra = m.copyWith(athlete: m.athlete.merge({'eventDistance': 'ultra50'}));
      expect(beyond(gen(ultra), 210), isEmpty);
      expect(planSettingChanges(l, 'de', m, ultra), contains('${l.longRunExtendTitle}: ${l.yes} → ${l.no}'));
    });
  });

  group('5 – the week after the last extended run is lighter', () {
    for (final (weeks, longDay, raceWd) in const [(8, 6, 7), (6, 6, 7), (7, 6, 7), (18, 7, 6), (18, 6, 4)]) {
      test('$weeks weeks (long day $longDay, race weekday $raceWd)', () {
        final p = _p(
          'm',
          weeks: weeks,
          longDay: longDay,
          raceWeekday: raceWd,
          dayMinutes: {longDay: 300},
          longest: weeks < 12 ? 21 : 16,
          extend: true,
        );
        final all = longs(gen(p));
        final ext = beyond(all, 180);
        expect(ext, isNotEmpty);
        for (final w in ext) {
          final next = all.where((x) => daysBetween(dayOnly(w.date), dayOnly(x.date)) == 7).firstOrNull;
          if (next == null) continue;
          expect(next.title, isNot(l.wLongRunMp), reason: 'no race-pace long run a week after ${w.durationMin} min');
          expect(next.steps.any((s) => s.zone == 'M'), isFalse);
          expect(next.durationMin, lessThanOrEqualTo(153), reason: 'at most ~80 % of the cap (or a recovery / taper week)');
        }
      });
    }
  });

  group('6 – one rule for plan and note', () {
    test('a day 10–15 min above the cap: nothing offered, nothing planned', () {
      for (final day in [190, 195]) {
        final off = _p('m', dayMinutes: {6: day}), on = _p('m', dayMinutes: {6: day}, extend: true);
        expect(PlanGenerator.longRunExtension(off), isNull, reason: '$day');
        expect(gen(on).map(sig).toList(), gen(off).map(sig).toList(), reason: '$day: the same plan, marathon-pace long runs included');
        final t = issue(feas(on), 'longRunTimeCap');
        expect(t, isNot(contains('Du hast längere Läufe erlaubt')), reason: '$day');
      }
    });

    test('plan and note agree for every day time; an extended run covers at least 1 km more than the capped one', () {
      for (final day in [180, 185, 190, 195, 200, 205, 210, 215, 240, 300]) {
        for (final tenK in const [62, 68, 75]) {
          final why = 'day $day, 10 km in $tenK min';
          final p = _p('m', dayMinutes: {6: day}, tenK: tenK * 60, extend: true);
          final ext = beyond(gen(p), 180);
          final n = feas(p).capNote;
          expect(n?.gains ?? false, ext.isNotEmpty, reason: why);
          expect(n?.extendRuns ?? 0, ext.length, reason: why);
          if (ext.isEmpty) continue;
          final off = longs(gen(_p('m', dayMinutes: {6: day}, tenK: tenK * 60)));
          final capped = off.fold<double>(0, (x, w) => x > (w.distanceKm ?? 0) ? x : w.distanceKm!);
          final top = ext.fold<double>(0, (x, w) => x > w.distanceKm! ? x : w.distanceKm!);
          expect(top, greaterThanOrEqualTo(capped + PlanGenerator.longRunExtraGainKm - 0.05), reason: why);
          expect(ext.last.durationMin, greaterThanOrEqualTo(180 + PlanGenerator.longRunExtraFloor - 2), reason: why);
          // More running too, not just walking further.
          expect(runningKm(ext.last), greaterThan(off.fold<double>(0, (x, w) => x > runningKm(w) ? x : runningKm(w))), reason: why);
        }
      }
    });
  });

  group('9 – wording', () {
    test('finish-goal advice follows the reason; the offer comes last; no dangling "Daher"', () {
      for (final canSwitch in [false, true]) {
        final t = issue(feas(_p('m')), 'longRunTimeCap', canSwitch: canSwitch);
        final why = t.indexOf('länger am Stück bringt mehr Verletzungsrisiko');
        final finish = t.indexOf('Ankommen ist deshalb das Ziel');
        final offer = t.indexOf('schrittweise bis 3:30 h');
        expect(why, greaterThan(0));
        expect(finish, greaterThan(why));
        expect(offer, greaterThan(finish));
        expect(t, isNot(contains('Daher')));
        expect(
          RegExp(r'[a-zäöü)]\. [A-ZÄÖÜ]').allMatches(t.replaceAll('z. B. ', '')).length,
          lessThanOrEqualTo(3),
          reason: 'four sentences at most: $t',
        );
      }
      final on = issue(feas(_p('m', extend: true)), 'longRunTimeCap');
      expect(on.indexOf('Du hast längere Läufe erlaubt'), greaterThan(on.indexOf('Ankommen ist deshalb das Ziel')));
      expect(on, isNot(contains('Daher')));
    });
  });

  group('7 – "Plan neu aufsetzen": the switch is saved with the rebuild', () {
    Future<_FakeRepo> pump(WidgetTester tester, UserProfile profile) async {
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final repo = _FakeRepo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repoProvider.overrideWithValue(repo),
            profileProvider.overrideWith((ref) => Stream.value(profile)),
            templatesProvider.overrideWith((ref) => Stream.value(const <WorkoutTemplate>[])),
            plansProvider.overrideWith((ref) => Stream.value(const <PlannedWorkout>[])),
            sessionsProvider.overrideWith((ref) => Stream.value(const <Session>[])),
            goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
          ],
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
            home: Scaffold(
              body: Consumer(
                builder:
                    (c, ref, _) => TextButton(
                      key: ValueKey(ref.watch(profileProvider).value?.name),
                      onPressed: () => showPlanGenerator(c, ref),
                      child: const Text('open'),
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return repo;
    }

    UserProfile profile() => _p('m', monday: startOfWeek(dayOnly(DateTime.now())));

    testWidgets('toggled and closed without rebuilding: the profile is untouched', (tester) async {
      final repo = await pump(tester, profile());
      final sw = find.byKey(const ValueKey('extendLongRun'));
      expect(sw, findsOneWidget);
      expect(tester.widget<SwitchListTile>(sw).value, isFalse);
      expect(find.byKey(const ValueKey('extendRebuildHint')), findsNothing);
      await tester.ensureVisible(sw);
      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(sw).value, isTrue, reason: 'the sheet shows the plan it would build');
      expect(find.textContaining('Du hast längere Läufe erlaubt'), findsOneWidget);
      expect(find.byKey(const ValueKey('extendRebuildHint')), findsOneWidget);
      expect(find.text(l.planRebuildExtendHint), findsOneWidget);
      expect(repo.savedProfiles, isEmpty, reason: 'nothing is saved before the plan is rebuilt');
      // Back off again: no hint, still nothing saved.
      await tester.ensureVisible(sw);
      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('extendRebuildHint')), findsNothing);
      await tester.ensureVisible(sw);
      await tester.tap(sw);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(sw)).pop();
      await tester.pumpAndSettle();
      expect(repo.savedProfiles, isEmpty);
      expect(repo.savedPlans, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('toggled and rebuilt: profile and plan carry it together', (tester) async {
      final repo = await pump(tester, profile());
      final sw = find.byKey(const ValueKey('extendLongRun'));
      await tester.ensureVisible(sw);
      await tester.tap(sw);
      await tester.pumpAndSettle();
      final go = find.text(l.startOverButton);
      await tester.ensureVisible(go);
      await tester.tap(go);
      await tester.pumpAndSettle();
      expect(repo.savedProfiles, isNotEmpty);
      expect(repo.savedProfiles.last.athlete.longRunExtend, isTrue);
      final ext = repo.savedPlans.where((w) => w.sport == Sport.run && w.intensity == 'long' && w.durationMin > 182);
      expect(ext.length, inInclusiveRange(1, 2));
      expect(ext.every((w) => w.durationMin <= 210), isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('8 – recalibration: "a little more volume" stops at the cap', () {
    var n = 0;
    String wid() => 'w${n++}';
    PlannedWorkout asDone(PlannedWorkout p, Session s) => PlannedWorkout.fromMap(p.id, {...p.toMap(), 'status': 'done', 'sessionId': s.id});

    /// Every workout before [at] done as planned; quality runs felt easy (RPE 3, no pace data) → "rpeLow".
    (List<PlannedWorkout>, List<Session>) history(UserProfile p, DateTime at) {
      final plans = <PlannedWorkout>[], sessions = <Session>[];
      for (final w in PlanGenerator(l, p, const [], wid).generate(start: _start)) {
        if (!w.date.isBefore(dayOnly(at))) {
          plans.add(w);
          continue;
        }
        final q = w.intensity == 'tempo' || w.intensity == 'intervals';
        final s = Session(
          id: 's${w.id}',
          sport: w.sport,
          title: w.title,
          start: DateTime(w.date.year, w.date.month, w.date.day, 18),
          durationSec: w.durationMin * 60,
          distanceM: q ? 0 : (w.distanceKm ?? 0) * 1000,
          rpe: q ? 3 : (w.intensity == 'long' ? 4 : 3),
          planId: w.id,
        );
        sessions.add(s);
        plans.add(asDone(w, s));
      }
      return (plans, sessions);
    }

    test('PlanGenerator.longSessionCapMin: the default caps', () {
      expect(PlanGenerator.longSessionCapMin(_p('m'), Sport.run), 180);
      expect(PlanGenerator.longSessionCapMin(_p('m', extend: true), Sport.run), 180, reason: 'the default cap, not the extension');
      expect(PlanGenerator.longSessionCapMin(_p('ultra50', weeks: 24), Sport.run), 210);
      expect(PlanGenerator.longSessionCapMin(_p('hm', weeks: 14), Sport.run), 150);
      expect(PlanGenerator.longSessionCapMin(_p('m'), Sport.ride), isNull);
      expect(PlanGenerator.longSessionCapMin(_p('m'), Sport.swim), isNull);
    });

    for (final extend in [false, true]) {
      test('long runs at the cap${extend ? ' and extended ones' : ''} are not raised beyond it', () {
        final p = _p('m', extend: extend);
        final base = PlanGenerator(l, p, const [], wid).generate(start: _start);
        final atCap = longs(base).where((w) => w.durationMin >= 172 && w.phase != 'taper').toList();
        expect(atCap.length, greaterThanOrEqualTo(3), reason: 'premise');
        var raisedOther = 0, checked = 0;
        for (final target in atCap.skip(1)) {
          // The Monday of the week of a long run at (or beyond) the cap.
          final at = startOfWeek(dayOnly(target.date)).add(const Duration(hours: 7));
          final (plans, sessions) = history(p, at);
          final r = Recalibrator(l, p, plans: plans, sessions: sessions, now: at).run();
          raisedOther += r.changes.where((c) => c.kind == RecalKind.harder && c.before.intensity == 'easy').length;
          for (final w in plans.where((w) => w.sport == Sport.run && w.intensity == 'long' && !w.isDone)) {
            final after = r.changes.where((c) => c.before.id == w.id).firstOrNull?.after ?? w;
            if (after.durationMin != w.durationMin) checked++;
            expect(after.durationMin, lessThanOrEqualTo(extend ? 210 : 181), reason: '${w.date}: ${w.durationMin} → ${after.durationMin}');
            final cap = w.durationMin > 182 ? w.durationMin : 181;
            expect(after.durationMin, lessThanOrEqualTo(cap), reason: '${w.date}: ${w.durationMin} → ${after.durationMin}');
          }
        }
        expect(raisedOther, greaterThan(0), reason: 'premise: the +5 % did apply to the easy runs ($checked long-run changes)');
      });
    }
  });
}
