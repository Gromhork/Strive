import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:strive/core/format.dart';
import 'package:strive/core/sport.dart';
import 'package:strive/data/models.dart';
import 'package:strive/features/calendar/feasibility_card.dart';
import 'package:strive/features/onboarding/onboarding_page.dart';
import 'package:strive/l10n/gen/app_localizations.dart';
import 'package:strive/services/event_spec.dart';
import 'package:strive/services/plan_generator.dart';
import 'package:strive/services/zones.dart';

/// Long-run time cap and its opt-in extension (user report 2026-11: "Deine langen Läufe enden bei 3 h" shown as
/// a warning although 5 h were set for the long day). The cap stays the default (marathon 3 h, ultra 3:30 h);
/// athletes whose cap covers clearly less than the race's long run and who have the time may allow the last
/// long runs before the taper to go up to 3:30 h / 4 h – and the note says that their time is not the limit.
final _start = DateTime(2026, 11, 9); // Monday
DateTime _race(int weeks) => DateTime(_start.year, _start.month, _start.day + 7 * (weeks - 1) + 6);

UserProfile _p(
  String ev, {
  String level = 'intermediate',
  int tenK = 68 * 60,
  Map<int, int> dayMinutes = const {6: 300},
  bool extend = false,
  int weeks = 18,
  TrainingFocus focus = TrainingFocus.run,
  List<int> days = const [1, 2, 4, 6, 7],
  int age = 35,
  List<String> limitations = const [],
  String setupMode = 'advanced',
  int sessionMinutes = 75,
}) => UserProfile(
  level: level,
  focus: focus,
  birthYear: DateTime.now().year - age,
  experience: {...focus.sports},
  trainingDays: days,
  longDay: 6,
  goals: const ['race'],
  athlete: AthleteData(
    setupMode: setupMode,
    sessionMinutes: sessionMinutes,
    dayMinutes: dayMinutes,
    raceTimes: {'10k': tenK},
    runWeeklyKm: 35,
    longestRunKm: 16,
    limitations: limitations,
    ftp: 200,
    eventDistance: ev,
    eventDate: _race(weeks),
    longRunExtend: extend,
  ),
);

const _dayNames = ['', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];

void main() {
  final l = lookupAppLocalizations(const Locale('de'));
  String id() => 'x';
  List<PlannedWorkout> gen(UserProfile p) => PlanGenerator(l, p, const [], id).generate(start: _start);
  List<PlannedWorkout> longs(List<PlannedWorkout> plan) =>
      plan.where((w) => w.sport == Sport.run && w.intensity == 'long').toList()..sort((a, b) => a.date.compareTo(b.date));
  List<PlannedWorkout> beyond(List<PlannedWorkout> plan, int capMin) => longs(plan).where((w) => w.durationMin > capMin + 2).toList();
  PlanFeasibility feas(UserProfile p) => PlanGenerator.feasibility(p, start: _start, l: l);
  String text(PlanFeasibility f, {bool canSwitch = false}) =>
      (f.extraIssueText(l, 'longRunTimeCap', dayName: (d) => _dayNames[d], canSwitch: canSwitch) ?? '').replaceAll(nbsp, ' ');
  String desc(PlannedWorkout w) => w.description.replaceAll(nbsp, ' ');

  group('default: the cap stays', () {
    test('marathon ≤ 3 h, ultra ≤ 3:30 h without the option – whatever time the day has', () {
      for (final (ev, cap, weeks) in const [('m', 180, 18), ('ultra50', 210, 24)]) {
        final plan = gen(_p(ev, weeks: weeks, dayMinutes: const {6: 420}));
        expect(beyond(plan, cap), isEmpty, reason: ev);
        expect(longs(plan).map((w) => w.durationMin).reduce((a, b) => a > b ? a : b), greaterThan(cap - 15), reason: ev);
      }
    });

    test('the option is off by default and stored only when on (old profiles read as off)', () {
      const a = AthleteData();
      expect(a.longRunExtend, isFalse);
      expect(a.toMap().containsKey('longRunExtend'), isFalse);
      expect(AthleteData.fromMap(const {}).longRunExtend, isFalse);
      final on = a.merge({'longRunExtend': true});
      expect(on.longRunExtend, isTrue);
      expect(AthleteData.fromMap(on.toMap()).longRunExtend, isTrue);
      expect(on.merge({'targetTimeSec': null}).longRunExtend, isTrue, reason: 'other changes keep it');
      expect(on.merge({'longRunExtend': false}).longRunExtend, isFalse);
    });
  });

  group('who gets the offer', () {
    test('slow marathoner with 5 h on the long day: 3 h → 3:30 h; ultra 3:30 h → 4 h', () {
      expect(PlanGenerator.longRunExtension(_p('m')), (capMin: 180, maxMin: 210));
      expect(PlanGenerator.longRunExtension(_p('ultra50', weeks: 24)), (capMin: 210, maxMin: 240));
    });

    test('not when 3 h already cover the race\'s long run (faster runners) – the plan ignores a stale switch', () {
      final fast = _p('m', tenK: 48 * 60);
      expect(PlanGenerator.longRunExtension(fast), isNull);
      final off = longs(gen(fast)).map((w) => (w.durationMin, w.distanceKm, w.title)).toList();
      final on = longs(gen(_p('m', tenK: 48 * 60, extend: true))).map((w) => (w.durationMin, w.distanceKm, w.title)).toList();
      expect(on, off);
      expect(feas(fast).issues, isNot(contains('longRunTimeCap')));
    });

    test('not without the time on the long day; a day between cap and maximum limits the extension', () {
      expect(PlanGenerator.longRunExtension(_p('m', dayMinutes: const {6: 180})), isNull);
      expect(PlanGenerator.longRunExtension(_p('m', dayMinutes: const {6: 185})), isNull);
      expect(PlanGenerator.longRunExtension(_p('m', dayMinutes: const {6: 200})), (capMin: 180, maxMin: 200));
      final plan = gen(_p('m', dayMinutes: const {6: 200}, extend: true));
      expect(beyond(plan, 180), isNotEmpty);
      expect(beyond(plan, 200), isEmpty);
      expect(beyond(gen(_p('m', dayMinutes: const {6: 180}, extend: true)), 180), isEmpty);
    });

    test('a long day left to the app\'s default grows with the option (quick setup)', () {
      final off = _p('m', dayMinutes: const {}, setupMode: 'simple', sessionMinutes: 60);
      final on = _p('m', dayMinutes: const {}, setupMode: 'simple', sessionMinutes: 60, extend: true);
      expect(PlanGenerator.longRunExtension(off), (capMin: 180, maxMin: 210));
      expect(PlanGenerator.dayMinutesFor(off, 6), 180);
      expect(PlanGenerator.dayMinutesFor(on, 6), 210);
      expect(beyond(gen(off), 180), isEmpty);
      final ext = beyond(gen(on), 180);
      expect(ext, isNotEmpty);
      expect(ext.every((w) => w.durationMin <= 210), isTrue);
    });

    test('beginners, seniors, joint problems and run/walk starters keep the cap', () {
      for (final p in [
        _p('m', level: 'beginner', extend: true),
        _p('m', age: 66, extend: true),
        _p('m', limitations: const ['knee'], extend: true),
      ]) {
        expect(PlanGenerator.longRunExtension(p), isNull);
        expect(beyond(gen(p), 180), isEmpty);
      }
    });

    test('hard caps: 70.3 / Ironman / duathlon long runs, HM and shorter – no extension, switch or not', () {
      for (final (ev, focus) in const [
        ('ironman', TrainingFocus.triathlon),
        ('70.3', TrainingFocus.triathlon),
        ('du_standard', TrainingFocus.duathlon),
        ('hm', TrainingFocus.run),
        ('10k', TrainingFocus.run),
      ]) {
        expect(EventSpec.of(ev)!.longRunExtraMin, 0, reason: ev);
        final weeks = EventSpec.of(ev)!.weeks.$2;
        final p = _p(ev, focus: focus, weeks: weeks, dayMinutes: const {6: 420, 7: 300}, tenK: 75 * 60, extend: true);
        expect(PlanGenerator.longRunExtension(p), isNull, reason: ev);
        expect(beyond(gen(p), EventSpec.of(ev)!.longRunCapMin), isEmpty, reason: ev);
      }
      expect(EventSpec.of('m')!.longRunExtraMin, 30);
      expect(EventSpec.of('ultra50')!.longRunExtraMin, 30);
    });
  });

  group('with the option on', () {
    for (final (ev, cap, weeks) in const [('m', 180, 18), ('ultra50', 210, 24)]) {
      test('$ev: at most two runs beyond the cap, progressive, ≥ 3 weeks out, run/walk, recovery after', () {
        final p = _p(ev, weeks: weeks, extend: true);
        final plan = gen(p);
        final race = dayOnly(p.athlete.eventDate!);
        final ext = beyond(plan, cap);
        expect(ext.length, inInclusiveRange(1, 2));
        expect(ext.length, 2, reason: 'a full-length plan has room for both');
        for (final w in ext) {
          expect(w.durationMin, lessThanOrEqualTo(cap + 30));
          expect(daysBetween(dayOnly(w.date), race), greaterThanOrEqualTo(21), reason: '≥ 3 weeks before the race');
          expect(w.phase, anyOf('build', 'peak'));
          // Run/walk structure: a 1 min walk between ~10 min blocks, and the description says so.
          expect(w.steps.where((s) => s.zone == 'walk').length, greaterThan(10));
          expect(w.steps.where((s) => s.zone == 'walk').every((s) => s.durationSec == 60), isTrue);
          expect(desc(w), contains('Verlängerter langer Lauf'));
          expect(desc(w), contains('nach je 10 min Laufen 1 min gehen'));
          expect(w.title, l.planLongRun, reason: 'plain easy – no race-pace finish, no progression');
          expect(w.steps.any((s) => s.zone == 'M'), isFalse);
          // Recovery after: nothing hard for two days, the next day's run stays short.
          for (final x in plan.where((x) => x.sport == Sport.run)) {
            final gap = daysBetween(dayOnly(w.date), dayOnly(x.date));
            if (gap < 1 || gap > 2) continue;
            expect(x.intensity, 'easy', reason: '${x.title} $gap d after');
            if (gap == 1) expect(x.durationMin, lessThanOrEqualTo(60), reason: x.title);
          }
        }
        // Progressive: half the extension first, the full one last; the longest of the plan is the last one.
        expect(ext.first.durationMin, lessThan(ext.last.durationMin));
        expect(ext.first.durationMin, lessThanOrEqualTo(cap + 17));
        expect(ext.last.durationMin, greaterThan(cap + 20));
        // Never in consecutive weeks: a recovery week or a clearly shorter long run lies between them.
        expect(daysBetween(dayOnly(ext.first.date), dayOnly(ext.last.date)), greaterThanOrEqualTo(14));
        final between = longs(plan).where((w) => w.date.isAfter(ext.first.date) && w.date.isBefore(ext.last.date));
        expect(between, isNotEmpty);
        for (final w in between) {
          expect(w.durationMin, lessThanOrEqualTo((cap * 0.85).round()), reason: 'shorter long run between the extended ones');
          expect(w.steps.any((s) => s.zone == 'M'), isFalse);
        }
        // More distance than the cap gives.
        final capped = longs(gen(_p(ev, weeks: weeks))).fold<double>(0, (x, w) => x > (w.distanceKm ?? 0) ? x : w.distanceKm!);
        expect(ext.last.distanceKm!, greaterThan(capped + 1.5));
      });
    }

    test('ultra: the back-to-back run after an extended long run is a short easy run', () {
      final plan = gen(_p('ultra50', weeks: 24, extend: true));
      for (final w in beyond(plan, 210)) {
        final next = plan.where((x) => x.sport == Sport.run && daysBetween(dayOnly(w.date), dayOnly(x.date)) == 1).toList();
        expect(next, hasLength(1));
        expect(next.single.durationMin, lessThanOrEqualTo(60));
      }
    });

    test('everything before the last weeks is the same plan as without the option', () {
      final off = gen(_p('m')), on = gen(_p('m', extend: true));
      final first = beyond(on, 180).first.date;
      final week = startOfWeek(dayOnly(first));
      String sig(PlannedWorkout w) => '${dayKey(w.date)} ${w.title} ${w.durationMin} ${w.distanceKm}';
      expect(on.where((w) => w.date.isBefore(week)).map(sig).toList(), off.where((w) => w.date.isBefore(week)).map(sig).toList());
    });

    test('a plan set up close to the race never extends inside the last three weeks', () {
      for (final weeks in [4, 5, 6, 8]) {
        final p = _p('m', weeks: weeks, extend: true).copyWith();
        final plan = gen(
          UserProfile.fromMap({
            ...p.toMap(),
            'athlete': p.athlete.merge({'longestRunKm': 21.0}).toMap(),
          }),
        );
        for (final w in beyond(plan, 180)) {
          expect(daysBetween(dayOnly(w.date), dayOnly(p.athlete.eventDate!)), greaterThanOrEqualTo(21), reason: '$weeks weeks');
        }
        expect(beyond(plan, 180).length, lessThanOrEqualTo(2));
      }
    });
  });

  group('the note', () {
    test('names the time the athlete set, says it is not the limit, and offers the extension', () {
      final f = feas(_p('m'));
      expect(f.issues, ['longRunTimeCap']);
      expect(f.onlyNotes, isTrue);
      final n = f.capNote!;
      expect(n.capMin, 180);
      expect(n.setDay, 6);
      expect(n.setDayMin, 300);
      expect(n.extendMaxMin, 210);
      expect(n.extendOn, isFalse);
      expect(n.extendMin, 210);
      expect(n.extendRuns, 2);
      expect(n.extendKm!, greaterThan(n.capKm + 1.5));
      final t = text(f);
      expect(t, contains('enden bei 3 h'));
      expect(t, contains('Das liegt nicht an deiner Zeit (für Samstag hast du 5 h eingeplant)'));
      expect(t, contains('schrittweise bis 3:30 h'));
      expect(t, contains('Einschalten kannst du das in den Planeinstellungen.'));
      expect(t, contains('Ankommen ist das Ziel'));
      // Where the switch is right there, the note does not send the athlete elsewhere.
      expect(text(f, canSwitch: true), isNot(contains('Planeinstellungen')));
    });

    test('with the option on: what is planned, with the km gained', () {
      final f = feas(_p('m', extend: true));
      final n = f.capNote!;
      expect(n.extendOn, isTrue);
      expect(n.extendMin, 210);
      final t = text(f);
      expect(t, contains('enden normalerweise bei 3 h'));
      expect(t, contains('Du hast längere Läufe erlaubt'));
      expect(t, contains('bis 3:30 h (etwa ${n.extendKm!.toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '')} km)'));
      expect(t, isNot(contains('Wenn du möchtest')));
      // The same numbers as the offer promised.
      final off = feas(_p('m')).capNote!;
      expect((off.extendMin, off.extendKm, off.extendRuns), (n.extendMin, n.extendKm, n.extendRuns));
    });

    test('finish-goal advice stays while even the extension is far from the usual distance – and goes when it is reached', () {
      // 10 km in 75 min: 3:30 h is still far below 28 km.
      final slow = feas(_p('m', tenK: 75 * 60, extend: true));
      expect(slow.capNote!.reachesRace, isFalse);
      expect(text(slow), contains('Ankommen ist das Ziel'));
      // 10 km in 62 min: 3 h ≈ 24 km (< 90 % of 28), 3:30 h reach ≥ 25.2 km.
      final close = feas(_p('m', tenK: 62 * 60, extend: true));
      expect(close.issues, contains('longRunTimeCap'));
      expect(close.capNote!.reachesRace, isTrue, reason: '${close.capNote!.extendKm}');
      expect(text(close), isNot(contains('Ankommen ist das Ziel')));
      expect(text(feas(_p('m', tenK: 62 * 60))), contains('Ankommen ist das Ziel'), reason: 'still true while the option is off');
    });

    test('without the time: no offer, no "not your time" – the plain note', () {
      final f = feas(_p('m', dayMinutes: const {6: 180}));
      expect(f.issues, contains('longRunTimeCap'));
      final n = f.capNote!;
      expect(n.setDay, isNull);
      expect(n.extendMaxMin, isNull);
      final t = text(f);
      expect(t, isNot(contains('nicht an deiner Zeit')));
      expect(t, isNot(contains('Wenn du möchtest')));
      expect(t, contains('Länger am Stück bringt mehr Verletzungsrisiko'));
    });

    test('quick setup (no day time typed): offer without a "you set" time', () {
      final f = feas(_p('m', dayMinutes: const {}, setupMode: 'simple', sessionMinutes: 60));
      final n = f.capNote!;
      expect(n.setDay, isNull);
      expect(n.extendMaxMin, 210);
      expect(text(f), contains('Wenn du möchtest'));
    });

    test('ultra: 3:30 h cap, offer up to 4 h', () {
      final f = feas(_p('ultra50', weeks: 24));
      expect(f.issues, contains('longRunTimeCap'));
      final t = text(f);
      expect(t, contains('enden bei 3:30 h'));
      expect(t, contains('für Samstag hast du 5 h eingeplant'));
      expect(t, contains('schrittweise bis 4 h'));
    });

    test('Ironman: the long run\'s cap is fixed – the note says why and mentions the set time, no offer', () {
      final p = _p(
        'ironman',
        focus: TrainingFocus.triathlon,
        weeks: 30,
        tenK: 70 * 60,
        days: const [1, 2, 3, 4, 6, 7],
        dayMinutes: const {6: 420, 7: 300},
        extend: true,
      );
      final f = feas(p);
      expect(f.issues, contains('longRunTimeCap'), reason: '${f.issues}');
      final n = f.capNote!;
      expect(n.hard, isTrue);
      expect(n.capMin, 180);
      expect(n.extendMaxMin, isNull);
      final t = text(f);
      expect(t, contains('enden bei 3 h'));
      expect(t, contains('Im Triathlon- und Duathlon-Training ist diese Grenze fest'));
      expect(t, contains('nicht an deiner Zeit'));
      expect(t, isNot(contains('Wenn du möchtest')));
      expect(t, contains('Verpflegungsstelle'));
    });

    test('English texts', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final f = PlanGenerator.feasibility(_p('m'), start: _start, l: en);
      final t = f.extraIssueText(en, 'longRunTimeCap', dayName: (d) => 'Saturday')!.replaceAll(nbsp, ' ');
      expect(t, contains('Your long runs stop at 3 h'));
      expect(t, contains('That is not about your time (you planned 5 h for Saturday)'));
      expect(t, contains('step by step up to 3:30 h'));
    });
  });

  group('plan settings', () {
    test('long sessions capped below the day\'s time are named next to the day times', () {
      expect(PlanGenerator.longCapsBelowDayTime(_p('m')), [(sport: Sport.run, capMin: 180, weekday: 6)]);
      expect(PlanGenerator.longCapsBelowDayTime(_p('m', extend: true)), [(sport: Sport.run, capMin: 210, weekday: 6)]);
      expect(PlanGenerator.longCapsBelowDayTime(_p('m', dayMinutes: const {6: 180})), isEmpty);
      expect(PlanGenerator.longCapsBelowDayTime(_p('10k', weeks: 12, dayMinutes: const {6: 240})), [
        (sport: Sport.run, capMin: 150, weekday: 6),
      ]);
      final ride = _p('ride160', focus: TrainingFocus.ride, weeks: 16, days: const [2, 4, 6], dayMinutes: const {6: 480});
      expect(PlanGenerator.longCapsBelowDayTime(ride), [(sport: Sport.ride, capMin: 330, weekday: 6)]);
      expect(
        PlanGenerator.longCapsBelowDayTime(
          _p('ride160', focus: TrainingFocus.ride, weeks: 16, days: const [2, 4, 6], dayMinutes: const {6: 300}),
        ),
        isEmpty,
      );
    });

    test('the change summary names the switch', () async {
      await initializeDateFormatting('de');
      final lines = planSettingChanges(l, 'de', _p('m'), _p('m', extend: true));
      expect(lines, ['${l.longRunExtendTitle}: ${l.no} → ${l.yes}']);
    });
  });

  group('card', () {
    Widget app(Widget child) => MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 320, child: child))),
    );

    testWidgets('a note is an info card with the switch – not a warning', (tester) async {
      var f = feas(_p('m'));
      bool? set;
      await tester.pumpWidget(app(FeasibilityCard(f, planAnyway: true, onExtendLongRun: (v) => set = v)));
      expect(find.text(l.feasTitleNote), findsOneWidget);
      expect(find.byKey(const ValueKey('feasNoteIcon')), findsOneWidget);
      expect(find.byKey(const ValueKey('feasWarnIcon')), findsNothing);
      expect(find.textContaining('Planeinstellungen'), findsNothing);
      final sw = find.byKey(const ValueKey('extendLongRun'));
      expect(sw, findsOneWidget);
      expect(tester.widget<SwitchListTile>(sw).value, isFalse);
      expect(find.text(l.longRunExtendSwitch(formatMinutes(210))), findsOneWidget);
      await tester.ensureVisible(sw);
      await tester.tap(sw);
      expect(set, isTrue);
      expect(tester.takeException(), isNull);

      f = feas(_p('m', extend: true));
      await tester.pumpWidget(app(FeasibilityCard(f, planAnyway: true, onExtendLongRun: (v) => set = v)));
      expect(tester.widget<SwitchListTile>(sw).value, isTrue);
      await tester.ensureVisible(sw);
      await tester.tap(sw);
      expect(set, isFalse);
    });

    testWidgets('without a switch the note says where to find it; no switch without an offer', (tester) async {
      await tester.pumpWidget(app(FeasibilityCard(feas(_p('m')))));
      expect(find.byKey(const ValueKey('extendLongRun')), findsNothing);
      expect(find.textContaining('Planeinstellungen'), findsOneWidget);

      await tester.pumpWidget(app(FeasibilityCard(feas(_p('m', dayMinutes: const {6: 180})), onExtendLongRun: (_) {})));
      expect(find.byKey(const ValueKey('feasNoteIcon')), findsOneWidget);
      expect(find.byKey(const ValueKey('extendLongRun')), findsNothing);
    });

    testWidgets('a real problem keeps the warning look', (tester) async {
      final f = feas(_p('m', level: 'beginner'));
      expect(f.onlyNotes, isFalse);
      await tester.pumpWidget(app(FeasibilityCard(f)));
      expect(find.byKey(const ValueKey('feasWarnIcon')), findsOneWidget);
      expect(find.byKey(const ValueKey('feasNoteIcon')), findsNothing);
    });
  });

  test('running km of an extended run stay within R1 of the longest run before it', () {
    final plan = gen(_p('m', extend: true));
    var longest = 0.0;
    for (final w in longs(plan)) {
      final km = runningKm(w);
      if (w.durationMin > 182) expect(km, lessThanOrEqualTo(longest * 1.12 + 0.01), reason: '${w.date}');
      if (km > longest) longest = km;
    }
  });
}
