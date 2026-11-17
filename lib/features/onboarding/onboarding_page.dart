import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/event_distances.dart';
import '../../core/event_sport_x.dart';
import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/default_programs.dart';
import '../../data/repository.dart' show deepEquals;
import '../calendar/feasibility_card.dart';
import '../calendar/replace_plan_dialog.dart';
import 'gym_assign_section.dart';
import '../shell/account.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/event_spec.dart';
import '../../services/goal_model.dart';
import '../../services/plan_generator.dart';
import '../../services/plan_service.dart';
import '../../services/schedule_advisor.dart';
import '../../services/zones.dart';
import '../../widgets/common.dart';
import '../../widgets/target_suggestion_line.dart';
import '../goals/goal_forecast_widgets.dart' show activeEventGoal;
import '../goals/goals_page.dart' show eventKeyForKm;
import '../../widgets/event_distance_picker.dart';
import '../../widgets/term_info.dart';
import '../../widgets/segments.dart';
import '../../widgets/discard_guard.dart';
import '../../widgets/duration_picker.dart';
import '../../services/target_suggestion.dart';
import '../session/step_text.dart' show zoneLabel;

/// What the setup flow edits.
enum SetupMode {
  /// First-time setup: everything.
  setup,

  /// Personal data only (name, body, level, health) – from the profile.
  profile,

  /// Training-plan inputs only (focus, week, times, sport data, event, plan) –
  /// from "Plan neu erstellen"; regenerates the plan on finish.
  plan,
}

/// First-time setup, profile editing and plan settings.
///
/// Two paths: **Quick** (general questions, ~2 min) and **Detailed** (sport-specific
/// data such as race times, weekly volume, FTP, CSS, 1RMs and a per-weekday plan).
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, this.mode = SetupMode.setup});

  final SetupMode mode;
  bool get edit => mode != SetupMode.setup;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

typedef _Step = (String id, Widget Function(AppLocalizations) build);

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pager = PageController();
  int _page = 0;

  /// Race goal (true) or just a plan length in weeks (false).
  /// (A pure gym plan has no race – [eventFitsFocus].)
  late bool _withEvent = p.focus != TrainingFocus.gym && (a.eventDate != null || a.eventDistance != null);

  /// Race goal without a date: the race is on the long-session day of the last of
  /// [AthleteData.planWeeks] weeks ([PlanGenerator.raceDayForWeeks]), kept in [AthleteData.eventDate]
  /// like a picked date so goal, countdown, forecast and taper work unchanged.
  bool _raceByWeeks = false;

  /// The race date picked in "Datum" mode while "Planlänge" is shown (restored on the way back).
  DateTime? _pickedDate;
  late UserProfile p;
  late AthleteData a;
  final _name = TextEditingController();
  bool _imperial = false;

  // Event
  final _eventName = TextEditingController();
  bool _generatePlan = true;

  /// (Checked in the background – the page rebuilds when a check is done.)
  late final _feasibility = FeasibilityCache(
    onUpdate: () {
      if (mounted) setState(() {});
    },
  );

  @override
  void initState() {
    super.initState();
    p = ref.read(profileProvider).value ?? UserProfile(name: _accountName(), birthYear: DateTime.now().year - 28);
    a = p.athlete;
    _eventName.text = a.eventName ?? '';
    if (widget.mode == SetupMode.plan) _prefillWeek();
    _orig = _profile;
    _origName = _eventName.text;
    if (widget.mode == SetupMode.plan) {
      // The goals may still be loading (nothing else listened yet): prefill once they arrive.
      ref.listenManual(goalsProvider, (_, next) {
        final goals = next.value;
        if (_goalPrefilled || goals == null) return;
        _goalPrefilled = true;
        _inInit ? _prefillGoal(goals) : setState(() => _prefillGoal(goals));
      }, fireImmediately: true);
    }
    _inInit = false;
    // The recorded sessions (target suggestion) – subscribed after the first frame: a first
    // subscription while building refreshes dependent providers during the build (Riverpod:
    // "markNeedsBuild() called during build").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listenManual(sessionListProvider, (_, next) => setState(() => _sessions = next), fireImmediately: true);
    });
    _name.text = p.name;
    _imperial = p.imperial;
    _generatePlan = widget.mode != SetupMode.profile;
    _markPristine();
  }

  /// What the page showed before any input (after prefilling) – leaving with other values asks
  /// "Discard changes?".
  Map<String, dynamic>? _pristine;

  void _markPristine() => _pristine = _snapshot();

  Map<String, dynamic> _snapshot() => {
    ..._profile.toMap(),
    'nameField': _name.text.trim(),
    'eventNameField': _eventName.text.trim(),
    'imperialField': _imperial,
    'withEvent': _withEvent,
    'removeRaceGoal': _removeRaceGoal,
  };

  bool get _dirty => _pristine != null && !deepEquals(_pristine, _snapshot());

  bool _goalPrefilled = false;
  List<Session> _sessions = const [];
  bool _inInit = true;

  /// Plan settings start from what the current plan is built on: the race of the active
  /// event goal (name, date, distance – the focus follows a multisport race) and, in the
  /// detailed setup, the week of the current plan (every sport in it, e.g. its swim session).
  void _prefillGoal(List<Goal> goals) {
    final today = dayOnly(DateTime.now());
    final goal = activeEventGoal(goals, today);
    // Arriving after the first frame: the prefilled values are the starting point, not a change
    // (unless the athlete already changed something).
    final wasDirty = _dirty;
    if (goal != null) {
      final key = eventDistanceOf(goal.eventKey) != null ? goal.eventKey : eventKeyForKm(goal.eventKm ?? goal.target);
      final sameRace = a.eventDate != null && sameDay(a.eventDate!, goal.deadline!);
      a = a.merge({
        'eventDate': goal.deadline,
        if (key != null) 'eventDistance': key,
        if (key != null && !(sameRace && a.eventDistance == key)) 'targetTimeSec': null,
        'eventName': goal.title,
      });
      if (key != null && !eventFitsFocus(key, p.focus)) {
        p = p.copyWith(focus: focusForRace(key, p.focus));
        // The week of the old focus has no cycling for the new triathlon focus: derive it anew.
        final week = [for (final v in a.dayPlan.values) ...v];
        if (_advanced && p.focus.sports.any((s) => !week.contains(s))) a = a.merge({'dayPlan': PlanGenerator.deriveSchedule(_profile)});
      }
      _withEvent = true;
      _eventName.text = goal.title;
      _prefilledGoal = goal;
    }
    if (!wasDirty) _markPristine();
  }

  /// The race goal the plan settings started from: changing its date or distance here edits that
  /// goal – a second goal next to it would leave the old race "not aligned" with the new plan.
  Goal? _prefilledGoal;

  /// "Nur Planlänge" with a race goal set: the goal the old plan was built for is removed with the
  /// new plan (the review step says so and lets the athlete keep it) – a kept goal would go on
  /// showing a countdown, phases and "goal and plan don't match" for a plan without that race.
  bool _removeRaceGoal = true;

  /// The race goal a plan without a race leaves behind (null: none, or the plan has a race).
  Goal? get _orphanRaceGoal => widget.mode == SetupMode.plan && !_withEvent ? _prefilledGoal : null;

  void _prefillWeek() {
    if (!_advanced) return;
    // The week the current plan really has (incl. e.g. its swim session) – a stored day plan
    // can be older than the plan.
    final week = _currentWeek();
    if (week.isNotEmpty) {
      a = a.merge({'dayPlan': week, if (week.values.any((v) => v.length > 1)) 'sessionsPerDay': 2});
    } else if (a.dayPlan.values.every((v) => v.isEmpty)) {
      a = a.merge({'dayPlan': PlanGenerator.scheduleOf(_quickProfile)});
    }
  }

  /// Weekday → sports of the current plan's next seven days (at most two per day).
  Map<int, List<Sport>> _currentWeek() {
    final today = dayOnly(DateTime.now());
    final end = addDays(today, 7);
    final out = <int, List<Sport>>{};
    for (final w in ref.read(planListProvider)) {
      if (w.status == 'skipped' || w.date.isBefore(today) || !w.date.isBefore(end)) continue;
      final list = out.putIfAbsent(w.date.weekday, () => []);
      if (!list.contains(w.sport) && list.length < 2) list.add(w.sport);
    }
    return out;
  }

  /// The settings when the page opened (the summary lists what changed).
  late UserProfile _orig;
  late String _origName;

  @override
  void dispose() {
    _pager.dispose();
    _name.dispose();
    _eventName.dispose();
    super.dispose();
  }

  /// Display name of the signed-in account (empty without Firebase, e.g. in tests).
  static String _accountName() {
    try {
      return FirebaseAuth.instance.currentUser?.displayName ?? '';
    } catch (_) {
      return '';
    }
  }

  bool get _advanced => a.setupMode == 'advanced';

  /// The profile as edited so far ([p] holds the personal data, [a] the athlete data).
  UserProfile get _profile => p.copyWith(athlete: a);

  /// The quick setup's view of the profile: one session a day, no detailed day plan –
  /// exactly what the plan generator uses for it.
  UserProfile get _quickProfile => p.copyWith(athlete: a.merge({'setupMode': 'simple', 'sessionsPerDay': 1}));

  /// Detailed setup: a day plan without one of the focus sports (e.g. derived while the
  /// focus was still "strength", or after switching to triathlon) is derived anew.
  void _syncDayPlan() {
    if (!_advanced) return;
    final sports = _sports;
    final plan = [for (final v in a.dayPlan.values) ...v.where(sports.contains)];
    if (p.focus.sports.any((s) => !plan.contains(s))) _setA({'dayPlan': PlanGenerator.deriveSchedule(_profile)});
  }

  /// Applies a tapped option of the feasibility card (audit UX-9) – right here in the setup.
  void _applyFeasibility(FeasibilityAction x) {
    switch (x) {
      case FeasLaterDate(:final date):
        setState(() => _raceByWeeks = false);
        _setA({'eventDate': date});
      case FeasShorter(:final distance):
        _setA({'eventDistance': distance, 'targetTimeSec': null});
      case FeasDayMinutes(:final minutes):
        _setA({
          'dayMinutes': {...a.dayMinutes, ...minutes},
        });
      case FeasLongDay(:final weekday):
        _setLongDay(weekday);
      case FeasAddDay():
        // The week: the quick setup's days, or the detailed day plan.
        final i = _steps.indexWhere((s) => s.$1 == 'week' || s.$1 == 'schedule');
        if (i >= 0) _pager.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  /// Sets the long-session day ([d] null = automatic).
  void _setLongDay(int? d) => setState(() => p = UserProfile.fromMap({...p.toMap(), 'longDay': d}));
  Set<Sport> get _sports => {...p.focus.sports, if (p.goals.contains('strength') || p.goals.contains('muscle')) Sport.gym};

  void _setA(Map<String, dynamic> changes) => setState(() {
    final before = a.eventDistance;
    a = a.merge(changes);
    // An automatic race name ("Halbmarathon" – the distance's own name, filled in from the goal)
    // follows the distance; only a name the athlete typed stays ("Halbmarathon · Marathon" never).
    if (a.eventDistance != before && _eventName.text.trim() == _distanceLabel(context.l10n, before)) _eventName.clear();
    _syncRaceDay();
  });

  List<_Step> get _steps {
    final setup = widget.mode == SetupMode.setup;
    final plan = widget.mode != SetupMode.profile;
    final profile = widget.mode != SetupMode.plan;
    return [
      if (setup) ('welcome', _welcome),
      if (profile) ('body', _body),
      if (profile) ('fitness', _fitness),
      if (plan) ('focus', _focus),
      if (plan) (_advanced ? 'week' : 'schedule', _advanced ? _weekPlan : _schedule),
      if (plan && _advanced && _sports.contains(Sport.run)) ('run', _running),
      if (plan && _advanced && _sports.contains(Sport.ride)) ('ride', _cycling),
      if (plan && _advanced && _sports.contains(Sport.swim)) ('swim', _swimming),
      if (plan && _sports.contains(Sport.gym)) ('gym', _strength),
      // Health limitations shape the plan (less impact, intensity caps) – asked in both setups.
      if (profile) ('health', _health),
      if (plan) ('event', _event),
      if (plan) ('plan', _plan),
      if (widget.mode == SetupMode.plan) ('summary', _summary),
    ];
  }

  void _next() {
    FocusScope.of(context).unfocus();
    // The week or the long day may have changed on an earlier step.
    _syncRaceDay();
    if (_page < _steps.length - 1) {
      _pager.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  /// Set while finishing: a second tap on "Finish" must not run the setup (and the plan
  /// generation) twice.
  bool _finishing = false;

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    try {
      await _doFinish();
    } finally {
      _finishing = false;
      PlanService.creating.value = false;
    }
  }

  Future<void> _doFinish() async {
    // Asked first: cancelling leaves everything as it was.
    var start = dayOnly(DateTime.now());
    if (_generatePlan && widget.mode != SetupMode.profile) {
      final s = await confirmReplacePlan(context, ref.read(planListProvider));
      if (s == null || !mounted) return;
      start = s;
    }
    final repo = ref.read(repoProvider)!;
    // Read through the container from here on: saving the finished setup's profile replaces this
    // page with the app (AuthGate) – the plan and the race goal must still be created then (the
    // first setup used to stop at the next `mounted` check: a new account had no plan).
    final container = ProviderScope.containerOf(context, listen: false);
    final l = context.l10n;
    final de = context.localeName.startsWith('de');
    // A race given as a plan length stays on the day shown (also when the plan starts next Monday).
    _syncRaceDay();
    // Sports that are no longer part of the focus (e.g. after switching from
    // triathlon to hybrid) are removed from the week plan.
    final sports = _sports;
    a = a.merge({
      'dayPlan': {for (final e in a.dayPlan.entries) e.key: e.value.where(sports.contains).toList()},
      'eventName': _eventName.text.trim().isEmpty ? null : _eventName.text.trim(),
      // Never plan for a race of another sport than the focus.
      if (!eventFitsFocus(a.eventDistance, p.focus)) 'eventDistance': null,
      if (!eventFitsFocus(a.eventDistance, p.focus)) 'targetTimeSec': null,
      // … and a pure gym plan for no race at all (audit UX-1): it runs for its plan length.
      if (p.focus == TrainingFocus.gym) 'eventDate': null,
    });
    var days = [...(p.trainingDays.isEmpty ? defaultTrainingDays : p.trainingDays)]..sort();
    var longDays = days; // days that can hold the long endurance session
    if (_advanced && a.dayPlan.values.any((v) => v.isNotEmpty)) {
      days = (a.dayPlan.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toList()..sort());
      longDays = [
        for (final e in a.dayPlan.entries)
          if (e.value.any((s) => s != Sport.gym)) e.key,
      ];
    } else if (widget.mode != SetupMode.profile) {
      // Quick setup: the generator derives the week from the training days – a day plan
      // left over from an earlier detailed setup must not override the days just chosen.
      a = a.merge({'dayPlan': <int, List<Sport>>{}, 'sessionsPerDay': 1});
    }
    final profile = UserProfile.fromMap({
      ...p
          .copyWith(
            name: _name.text.trim().isEmpty ? p.name : _name.text.trim(),
            imperial: _imperial,
            onboarded: true,
            athlete: a,
            trainingDays: days,
          )
          .toMap(),
      // A long day that is no longer a training day would be silently ignored – store "automatic".
      'longDay': longDays.contains(p.longDay) ? p.longDay : null,
    });
    if (_generatePlan && widget.mode == SetupMode.setup) PlanService.creating.value = true;
    repo.saveProfile(profile);
    final now = DateTime.now();

    if (widget.mode == SetupMode.setup) {
      repo.saveBody(
        BodyEntry(id: repo.newId(), date: now, weightKg: profile.weightKg, fatPct: profile.fatPct, musclePct: profile.musclePct),
      );
    }
    if (widget.mode == SetupMode.profile) {
      if (mounted) Navigator.pop(context);
      return;
    }

    // Programs: all built-ins for new users; otherwise add the ones the split needs. "New"
    // only when the server confirms there are none – an empty local cache (first start
    // offline) must not add every built-in program a second time.
    var templates = container.read(templateListProvider);
    if (templates.isEmpty) {
      templates = await repo.templatesFromServer() ?? templates;
    }
    final added =
        templates.isEmpty
            ? defaultTemplates(repo.newId, de: de)
            : missingBuiltins(templates, repo.newId, de: de, only: PlanGenerator.gymKeysFor(profile).toSet());
    if (added.isNotEmpty) {
      repo.saveTemplates(added);
      templates = [...templates, ...added];
    }

    if (a.eventDate != null && (a.eventDistance != null || _eventName.text.trim().isNotEmpty)) {
      final km = _eventKm(a.eventDistance);
      final goals = container.read(goalsProvider).value ?? const <Goal>[];
      final existing =
          goals.where((g) => g.type == GoalType.event && g.deadline != null && sameDay(g.deadline!, a.eventDate!)).firstOrNull ??
          goals.where((g) => g.id == _prefilledGoal?.id).firstOrNull;
      repo.saveGoal(
        Goal(
          id: existing?.id ?? repo.newId(),
          type: GoalType.event,
          title: _eventName.text.trim().isEmpty ? _distanceLabel(l, a.eventDistance) : _eventName.text.trim(),
          sport: profile.focus.sports.last,
          target: km ?? 0,
          eventKm: km,
          eventKey: a.eventDistance,
          created: existing?.created ?? now,
          deadline: a.eventDate,
        ),
      );
    }

    // "Nur Planlänge": the race goal of the old plan goes with it (unless kept on the review step).
    final orphan = _orphanRaceGoal;
    if (orphan != null && _removeRaceGoal) repo.deleteGoal(orphan.id);

    if (_generatePlan) {
      await PlanService.replacePlan(
        repo: repo,
        l: l,
        profile: profile,
        templates: templates,
        existing: container.read(planListProvider),
        sessions: container.read(sessionListProvider),
        start: start,
        weeks: a.planWeeks,
      );
    }
    if (widget.edit && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Keep programs and plans loaded: finishing the setup reads them (built-in programs
    // are only added when missing, old planned workouts are replaced).
    ref.watch(templateListProvider);
    ref.watch(planListProvider);
    final steps = _steps;
    final last = _page == steps.length - 1;
    // Android back goes one step back like the app-bar arrow; only on the first step it
    // leaves – the profile / plan settings (✕ or back) after "Discard changes?" when something
    // was changed, like every other editor.
    return PopScope(
      canPop: _page == 0 && !widget.edit,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_page > 0) {
          _pager.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          return;
        }
        if (_dirty && !await confirmDiscard(context)) return;
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading:
              _page > 0
                  ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => _pager.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                  )
                  : (widget.edit ? const CloseButton() : null),
          title: Text(switch (widget.mode) {
            SetupMode.setup => l.onboardingTitle,
            SetupMode.profile => l.editProfile,
            SetupMode.plan => l.planSettings,
          }),
          actions: [
            if (!widget.edit) IconButton(tooltip: l.logout, onPressed: () => signOutAndClear(context), icon: const Icon(Icons.logout)),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (_page + 1) / steps.length),
              duration: const Duration(milliseconds: 300),
              builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 4),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                // Built lazily, each step in its own element: typing on one step no longer rebuilds
                // every other step (the plan step generates a whole plan for its feasibility check),
                // and an error while building one step stays inside that step – it used to replace
                // the whole page, and the PageView built anew started over at the first step.
                child: PageView.builder(
                  controller: _pager,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: steps.length,
                  // Steps come and go with the focus (run / ride / swim): a page keeps its state by id.
                  findChildIndexCallback: (key) {
                    final i = steps.indexWhere((s) => ValueKey(s.$1) == key);
                    return i < 0 ? null : i;
                  },
                  itemBuilder: (_, i) => _StepPage(key: ValueKey(steps[i].$1), content: () => steps[i].$2(l)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _page == 0 && widget.mode == SetupMode.setup && _name.text.trim().isEmpty ? null : _next,
                    child: Text(
                      last ? (widget.mode == SetupMode.plan && _generatePlan ? l.recreatePlan : (widget.edit ? l.save : l.letsGo)) : l.next,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────── building blocks ─────────────────────────────

  Widget _h(String title, String sub, {IconData? icon, Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: (color ?? AppColors.brand).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color ?? AppColors.brand),
          ),
          const SizedBox(height: 14),
        ],
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(sub, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
      ],
    ),
  );

  Widget _label(String s, {String? hint, Term? term}) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [Flexible(child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600))), if (term != null) TermInfoButton(term)],
        ),
        if (hint != null) Text(hint, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );

  Widget _choiceCard({
    required bool selected,
    required String title,
    required String sub,
    required IconData icon,
    required VoidCallback onTap,
    Color color = AppColors.brand,
    String? badge,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? color.withValues(alpha: 0.16) : scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? color : scheme.outlineVariant, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: selected ? color : scheme.outline, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                              child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(sub, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _numField(String label, num? value, ValueChanged<double?> onChanged, {String? suffix, String? hint, bool decimal = true}) =>
      TextFormField(
        initialValue: value == null ? '' : Units.num(value.toDouble()),
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: label, suffixText: suffix, hintText: hint),
        onChanged: (v) => onChanged(parseNum(v)),
      );

  /// Race time of a running distance ([key] '5k' | '10k' | 'hm' | 'm') in the race time grid: scroll
  /// wheels within the plausible range ([eventTimeBounds]), starting at the time the other entries
  /// (or the level) predict.
  Widget _raceTimeField(AppLocalizations l, String key, String label) {
    final bounds = eventTimeBounds(key)!;
    final predicted = Vdot.raceTime(Vdot.of(a) ?? Vdot.defaultFor(p.level), Vdot.distances[key]!);
    return DurationField(
      key: ValueKey('raceTime-$key'),
      value: a.raceTimes[key],
      onChanged: (v) => _setRace(key, v),
      inlineLabel: label,
      title: l.bestTimeFor(label),
      min: bounds.$1,
      max: bounds.$2,
      initial: (predicted / 5).round() * 5,
    );
  }

  /// Time of the 400 m / 200 m swim test ([meters]) – minutes and seconds, starting at the time the
  /// known (or the level's) CSS predicts.
  Widget _swimTestField(AppLocalizations l, int meters) {
    final (lo, hi) = swimTestBounds(meters);
    final css = SwimZones.fromTests(a.swim400Sec, a.swim200Sec) ?? SwimZones.defaultFor(p.level);
    final field = meters == 400 ? 'swim400Sec' : 'swim200Sec';
    // With the other distance entered: the time that fits it (the 400 m take about 2.1 × the 200 m) – the
    // CSS's guess made 4:00 for the 200 m next to a 7:35 400 m, a pair the hint then rejected (audit UX-15).
    final other = meters == 400 ? a.swim200Sec : a.swim400Sec;
    final fromOther = other == null || other <= 0 ? null : (meters == 400 ? other * 2.1 : other / 2.1);
    return DurationField(
      key: ValueKey('swimTest$meters'),
      value: meters == 400 ? a.swim400Sec : a.swim200Sec,
      onChanged: (v) => _setA({field: v}),
      inlineLabel: '$meters m',
      title: l.swimTestFor('$meters m'),
      min: lo,
      max: hi,
      initial: (((fromOther ?? css * meters / 100 + (meters == 400 ? 15 : 0)) / 5).round() * 5).clamp(lo, hi),
    );
  }

  // ───────────────────────────── pages ─────────────────────────────

  Widget _welcome(AppLocalizations l) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _h(l.welcomeTitle, l.welcomeSub),
      Row(children: [for (final s in Sport.values) Padding(padding: const EdgeInsets.only(right: 8), child: SportBadge(s, size: 48))]),
      const SizedBox(height: 24),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: l.yourName, prefixIcon: const Icon(Icons.badge_outlined)),
        onChanged: (_) => setState(() {}),
      ),
      _label(l.setupModeTitle),
      _choiceCard(
        selected: !_advanced,
        title: l.setupQuick,
        sub: l.setupQuickSub,
        icon: Icons.bolt_rounded,
        onTap: () => _setA({'setupMode': 'simple'}),
      ),
      _choiceCard(
        selected: _advanced,
        title: l.setupDetailed,
        sub: l.setupDetailedSub,
        icon: Icons.tune_rounded,
        badge: l.recommended,
        onTap: () {
          _setA({'setupMode': 'advanced'});
          if (a.dayPlan.values.every((v) => v.isEmpty)) _setA({'dayPlan': PlanGenerator.deriveSchedule(_profile)});
        },
      ),
    ],
  );

  Widget _body(AppLocalizations l) {
    final u = Units(_imperial);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h(l.aboutYou, l.aboutYouSub, icon: Icons.person_outline_rounded),
        if (widget.mode == SetupMode.profile) ...[
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l.yourName, prefixIcon: const Icon(Icons.badge_outlined)),
          ),
          const SizedBox(height: 16),
        ],
        Segments<String>(
          segments: [Seg('m', label: l.male), Seg('f', label: l.female), Seg('d', label: l.diverse)],
          value: p.gender,
          onChanged: (v) => setState(() => p = p.copyWith(gender: v)),
        ),
        const SizedBox(height: 12),
        LabeledSlider(
          label: l.age,
          value: (DateTime.now().year - (p.birthYear ?? 1998)).toDouble(),
          min: 12,
          max: 90,
          divisions: 78,
          onChanged: (v) => setState(() => p = p.copyWith(birthYear: DateTime.now().year - v.round())),
        ),
        LabeledSlider(
          label: l.height,
          value: p.heightCm,
          min: 130,
          max: 220,
          divisions: 90,
          format: (v) => '${v.round()} cm',
          onChanged: (v) => setState(() => p = p.copyWith(heightCm: v.roundToDouble())),
        ),
        LabeledSlider(
          label: l.weight,
          value: p.weightKg,
          min: 35,
          max: 180,
          divisions: 290,
          format: (v) => u.weight(v),
          onChanged: (v) => setState(() => p = p.copyWith(weightKg: (v * 2).round() / 2)),
        ),
        _label(l.bodyCompositionOptional),
        Row(
          children: [
            Expanded(child: _numField(l.bodyFat, p.fatPct, (v) => p = p.copyWith(fatPct: v), suffix: '%')),
            const SizedBox(width: 12),
            Expanded(child: _numField(l.muscleMass, p.musclePct, (v) => p = p.copyWith(musclePct: v), suffix: '%')),
          ],
        ),
        if (_advanced) ...[
          _label(l.heartRateOptional, hint: l.heartRateHint),
          Row(
            children: [
              Expanded(child: _numField(l.restingHr, a.restHr, (v) => a = a.merge({'restHr': v?.round()}), suffix: 'bpm', decimal: false)),
              const SizedBox(width: 12),
              Expanded(
                child: _numField(
                  l.maxHr,
                  p.maxHr,
                  (v) => p = UserProfile.fromMap({...p.toMap(), 'maxHr': v?.round()}),
                  suffix: 'bpm',
                  hint: '${p.estimatedMaxHr}',
                  decimal: false,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text('BMI ${Units.fixed(p.bmi)}', style: Theme.of(context).textTheme.bodySmall),
        if (widget.mode == SetupMode.profile) ...[_label(l.units), _unitsSwitch(l)],
      ],
    );
  }

  Widget _fitness(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h(l.fitnessLevel, l.fitnessLevelSub, icon: Icons.insights_rounded),
        _choiceCard(
          selected: p.level == 'beginner',
          title: l.beginner,
          sub: l.beginnerDesc,
          icon: Icons.eco_outlined,
          onTap: () => setState(() => p = p.copyWith(level: 'beginner')),
        ),
        _choiceCard(
          selected: p.level == 'intermediate',
          title: l.intermediate,
          sub: l.intermediateDesc,
          icon: Icons.trending_up_rounded,
          onTap: () => setState(() => p = p.copyWith(level: 'intermediate')),
        ),
        _choiceCard(
          selected: p.level == 'advanced',
          title: l.advanced,
          sub: l.advancedDesc,
          icon: Icons.rocket_launch_outlined,
          onTap: () => setState(() => p = p.copyWith(level: 'advanced')),
        ),
        _label(l.experienceWith),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in Sport.values)
              FilterChip(
                avatar: Icon(s.icon, size: 18, color: s.color),
                label: Text(s.label(l)),
                selected: p.experience.contains(s),
                onSelected:
                    (v) => setState(() {
                      final e = {...p.experience};
                      v ? e.add(s) : e.remove(s);
                      p = p.copyWith(experience: e);
                    }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _focus(AppLocalizations l) {
    final goals = {
      'strength': l.goalStrength,
      'muscle': l.goalMuscle,
      'fatloss': l.goalFatLoss,
      'endurance': l.goalEndurance,
      'health': l.goalHealth,
      'race': l.goalRace,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h(l.focusTitle, l.focusSub, icon: Icons.center_focus_strong_rounded),
        if (widget.mode == SetupMode.plan) ...[
          Segments<String>(
            segments: [
              Seg('simple', label: l.setupQuick, icon: Icons.bolt_rounded),
              Seg('advanced', label: l.setupDetailed, icon: Icons.tune_rounded),
            ],
            value: a.setupMode,
            onChanged: (v) {
              _setA({'setupMode': v});
              if (v == 'advanced' && a.dayPlan.values.every((x) => x.isEmpty)) {
                final week = _currentWeek();
                _setA({'dayPlan': week.isNotEmpty ? week : PlanGenerator.scheduleOf(_quickProfile)});
              }
              _syncDayPlan();
            },
          ),
          const SizedBox(height: 20),
        ],
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: [
            for (final f in TrainingFocus.values)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() => p = p.copyWith(focus: f));
                  // A race of another sport doesn't fit the new focus.
                  if (!eventFitsFocus(a.eventDistance, f)) _setA({'eventDistance': null, 'targetTimeSec': null});
                  // A pure gym plan trains for no race (audit UX-1): a plan length instead.
                  if (f == TrainingFocus.gym && _withEvent) {
                    setState(() {
                      _withEvent = false;
                      _raceByWeeks = false;
                    });
                    _eventName.clear();
                    _setA({'eventDate': null, 'eventDistance': null, 'targetTimeSec': null});
                  }
                  _syncDayPlan();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: p.focus == f ? AppColors.brand.withValues(alpha: 0.2) : Theme.of(context).colorScheme.surfaceContainer,
                    border: Border.all(
                      color: p.focus == f ? AppColors.brand : Theme.of(context).colorScheme.outlineVariant,
                      width: p.focus == f ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(f.icon, color: f.sports.length == 1 ? f.sports.first.color : AppColors.brand),
                      const SizedBox(width: 10),
                      Expanded(child: Text(f.label(l), style: const TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              ),
          ],
        ),
        _label(l.yourGoals),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in goals.entries)
              FilterChip(
                label: Text(g.value),
                selected: p.goals.contains(g.key),
                onSelected: (v) {
                  setState(() {
                    final list = [...p.goals];
                    v ? list.add(g.key) : list.remove(g.key);
                    p = p.copyWith(goals: list);
                  });
                  _syncDayPlan();
                },
              ),
          ],
        ),
      ],
    );
  }

  String _dayName(int d) => DateFormat.E(context.localeName).format(addDays(startOfWeek(DateTime.now()), d - 1));

  /// Quick setup: training days + long day + time + units.
  ///
  /// Shows the week the plan will really use (one session a day, beginners keep rest days,
  /// strength days for a strength goal), so the chosen days and the plan never disagree.
  Widget _schedule(AppLocalizations l) {
    final quick = _quickProfile;
    final adv = ScheduleAdvisor(quick, _sports);
    final recPlan = adv.autoSchedule(adv.recommended());
    final recDays = recPlan.keys.toList()..sort();
    // The advisor puts the long session on the preferred day (default Saturday).
    final recLong = recDays.contains(p.longDay ?? 6) ? (p.longDay ?? 6) : null;
    final recProfile = UserProfile.fromMap({...quick.toMap(), 'trainingDays': recDays, 'longDay': recLong});
    final recWeek = PlanGenerator.scheduleOf(recProfile).values.expand((v) => v);
    final freq = {
      for (final s in Sport.values)
        if (recWeek.contains(s)) s: recWeek.where((x) => x == s).length,
    };
    final week = PlanGenerator.scheduleOf(quick);
    final used = week.keys.toList()..sort();
    final chosen = [...p.trainingDays]..sort();
    final outline = Theme.of(context).colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h(l.scheduleTitle, l.scheduleSub, icon: Icons.calendar_month_rounded),
        _RecommendationCard(
          freq: freq,
          title: l.recDays(recDays.length),
          action: l.recAutoDays,
          applied: _listEq(recDays, chosen),
          onApply: () => setState(() => p = UserProfile.fromMap({...p.toMap(), 'trainingDays': recDays, 'longDay': recLong})),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var d = 1; d <= 7; d++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DayChip(
                    key: ValueKey('day$d'),
                    label: _dayName(d),
                    selected: chosen.contains(d),
                    onTap: () {
                      final days = [...p.trainingDays];
                      if (days.contains(d)) {
                        // At least one training day – an empty week would silently become Mon/Wed/Fri.
                        if (days.length <= 1) {
                          toast(context, l.quickMinOneDay);
                          return;
                        }
                        days.remove(d);
                      } else {
                        days.add(d);
                      }
                      days.sort();
                      // A long day that is no longer a training day goes back to "automatic".
                      setState(
                        () => p = UserProfile.fromMap({...p.toMap(), 'trainingDays': days, if (!days.contains(p.longDay)) 'longDay': null}),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // The plan's week: sport per day; chosen days the plan keeps free are marked as rest.
        Row(
          children: [
            for (var d = 1; d <= 7; d++)
              Expanded(
                child: SizedBox(
                  key: ValueKey('use$d'),
                  height: 22,
                  child: Center(
                    child:
                        week[d] != null
                            ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [for (final s in week[d]!) Icon(s.icon, size: 16, color: s.color)],
                            )
                            : (chosen.contains(d) ? Icon(Icons.bedtime_outlined, size: 16, color: outline) : null),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          used.length < chosen.length ? l.quickDaysCapped(used.length, chosen.length) : l.daysPerWeek(used.length),
          key: const ValueKey('daysHint'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (p.focus != TrainingFocus.gym) ...[
          _label(l.longSessionDay),
          DropdownButtonFormField<int?>(
            key: const ValueKey('longDay'),
            value: chosen.contains(p.longDay) ? p.longDay : null,
            items: [
              DropdownMenuItem(value: null, child: Text(l.automatic)),
              for (final d in chosen) DropdownMenuItem(value: d, child: Text(_dayName(d))),
            ],
            onChanged: _setLongDay,
          ),
        ],
        _timeSection(l, days: used),
        // What the athlete can do today decides how the plan starts (run/walk, swim technique ladder).
        if (_sports.contains(Sport.run) || _sports.contains(Sport.swim)) ...[
          _label(l.abilityTitle),
          if (_sports.contains(Sport.run))
            SwitchListTile(
              key: const ValueKey('quickCanRun30'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.canRun30),
              subtitle: Text(l.canRun30Sub),
              // A beginner without running experience starts on run/walk whatever the default answer
              // said – the switch shows what the plan does, and "yes" counts as running experience.
              value: a.canRun30 && PlanGenerator.runWalkStartFor(_quickProfile) != 0,
              onChanged: (v) {
                if (v && !p.experience.contains(Sport.run)) setState(() => p = p.copyWith(experience: {...p.experience, Sport.run}));
                _setA({'canRun30': v});
              },
            ),
          if (_sports.contains(Sport.swim))
            SwitchListTile(
              key: const ValueKey('quickCanSwim400'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.canSwim400),
              subtitle: Text(l.canSwim400Sub),
              value: a.canSwim400,
              onChanged: (v) => _setA({'canSwim400': v}),
            ),
        ],
        if (widget.mode == SetupMode.setup) ...[_label(l.units), _unitsSwitch(l)],
      ],
    );
  }

  static bool _listEq(List<int> x, List<int> y) => x.length == y.length && List.generate(x.length, (i) => x[i] == y[i]).every((v) => v);

  /// Max. training time per day (global) with optional per-day overrides.
  Widget _timeSection(AppLocalizations l, {required List<int> days}) {
    final profile = _advanced ? _profile : _quickProfile;
    final longDay = PlanGenerator.longDayOf(profile);
    // Long sessions capped below the time the athlete set for their day, and the opt-in extension of the
    // long run's cap (marathon / ultra, [PlanGenerator.longRunExtension]).
    final caps = PlanGenerator.longCapsBelowDayTime(profile);
    final ext = PlanGenerator.longRunExtension(profile);
    final extSpec = EventSpec.of(a.eventDistance);
    // Shown where it does something: the plan with the extension really has runs beyond the cap
    // ([LongRunCapNote.gains] – not when the week's volume or the weeks left keep the long run at or below the
    // cap anyway, review 2026-11) – or it is on and can be taken back.
    final gains = ext != null && a.eventDate != null && (_feasibility.capNote(profile, DateTime.now(), l)?.gains ?? false);
    final extShown = gains || (a.longRunExtend && (extSpec?.longRunExtraMin ?? 0) > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(l.timeTitle, hint: l.timeHint),
        _MinutesStepper(value: a.sessionMinutes, onChanged: (v) => _setA({'sessionMinutes': v}), big: true),
        if (longDay != null && !a.dayMinutes.containsKey(longDay))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.timeLongDayHint2(_MinutesStepper.fmt(max(a.sessionMinutes, PlanGenerator.longDayDefault(profile)))),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: a.dayMinutes.isNotEmpty,
            leading: const Icon(Icons.tune_rounded, size: 20),
            title: Text(l.timePerDay, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle:
                a.dayMinutes.isEmpty ? null : Text(l.timeCustomDays(a.dayMinutes.length), style: Theme.of(context).textTheme.bodySmall),
            children: [
              for (final d in [...days]..sort())
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 44, child: Text(_dayName(d), style: const TextStyle(fontWeight: FontWeight.w700))),
                      if (d == longDay) const Icon(Icons.star_rounded, size: 16, color: AppColors.brand),
                      const Spacer(),
                      if (a.dayMinutes.containsKey(d))
                        IconButton(
                          tooltip: l.timeDefault,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.restart_alt_rounded, size: 20),
                          onPressed:
                              () => _setA({
                                'dayMinutes': {...a.dayMinutes}..remove(d),
                              }),
                        ),
                      _MinutesStepper(
                        value: PlanGenerator.dayMinutesFor(profile, d),
                        dimmed: !a.dayMinutes.containsKey(d),
                        onChanged:
                            (v) => _setA({
                              'dayMinutes': {...a.dayMinutes, d: v},
                            }),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        for (final c in caps)
          Padding(
            key: ValueKey('longCapHint-${c.sport.name}'),
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              c.sport == Sport.ride ? l.timeLongCapRide(_MinutesStepper.fmt(c.capMin)) : l.timeLongCapRun(_MinutesStepper.fmt(c.capMin)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (extShown)
          SwitchListTile(
            key: const ValueKey('extendLongRunSetting'),
            contentPadding: EdgeInsets.zero,
            value: a.longRunExtend,
            onChanged: (v) => _setA({'longRunExtend': v}),
            title: Text(
              l.longRunExtendSwitch(_MinutesStepper.fmt(ext?.maxMin ?? extSpec!.longRunCapMin + extSpec.longRunExtraMin)),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              l.longRunExtendSub(_MinutesStepper.fmt(ext?.capMin ?? extSpec!.longRunCapMin)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _unitsSwitch(AppLocalizations l) => Segments<bool>(
    segments: [Seg(false, label: l.metric), Seg(true, label: l.imperial)],
    value: _imperial,
    onChanged: (v) => setState(() => _imperial = v),
  );

  /// Detailed setup: which sport on which weekday (1–2 sessions per day).
  Widget _weekPlan(AppLocalizations l) {
    final sports = _sports.toList()..sort((x, y) => x.index.compareTo(y.index));
    final plan = {for (final e in a.dayPlan.entries) e.key: e.value.where(_sports.contains).toList()};
    final perSport = {for (final s in sports) s: plan.values.where((v) => v.contains(s)).length};
    final total = plan.values.fold<int>(0, (n, v) => n + v.length);
    void toggle(int d, Sport s) {
      final list = plan[d] ?? <Sport>[];
      if (list.contains(s)) {
        list.remove(s);
      } else {
        if (a.sessionsPerDay == 1) list.clear();
        if (list.length >= 2) list.removeAt(0);
        list.add(s);
      }
      plan[d] = list;
      _setA({'dayPlan': plan});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h(l.weekPlanTitle, l.weekPlanSub, icon: Icons.view_week_rounded),
        Builder(
          builder: (_) {
            final adv = ScheduleAdvisor(_profile, _sports);
            final freq = adv.recommended();
            return _RecommendationCard(
              freq: freq,
              current: perSport,
              // The race's minimum sessions do not fit in one session a day on the days a week leaves (audit UX-4).
              note: a.sessionsPerDay == 1 && adv.raceMinSessions > adv.maxDays ? l.recMinNoFit(adv.raceMinSessions, adv.maxDays) : null,
              title: l.recTitle,
              action: l.recAuto,
              applied: freq.entries.every((e) => perSport[e.key] == e.value),
              onApply: () {
                final plan = adv.autoSchedule(freq);
                final ld = plan.entries.where((e) => e.value.any((s) => s != Sport.gym)).map((e) => e.key).toList()..sort();
                if (ld.isNotEmpty && !ld.contains(p.longDay)) _setLongDay(ld.contains(6) ? 6 : ld.last);
                _setA({'dayPlan': plan});
                toast(context, l.recApplied);
              },
            );
          },
        ),
        const SizedBox(height: 16),
        Segments<int>(
          segments: [Seg(1, label: l.oncePerDay), Seg(2, label: l.twicePerDay)],
          value: a.sessionsPerDay,
          onChanged: (v) {
            final n = v;
            // Switching back to one session per day: keep only the first sport of each day.
            if (n == 1) {
              for (final d in plan.keys) {
                if (plan[d]!.length > 1) plan[d] = [plan[d]!.first];
              }
            }
            _setA({'sessionsPerDay': n, 'dayPlan': plan});
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const SizedBox(width: 46),
            for (final s in sports)
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(s.label(l), maxLines: 1, style: TextStyle(fontSize: 11, color: s.color, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            const SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 6),
        for (var d = 1; d <= 7; d++)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.longDay == d ? AppColors.brand : Colors.transparent),
            ),
            child: Row(
              children: [
                SizedBox(width: 38, child: Text(_dayName(d), style: const TextStyle(fontWeight: FontWeight.w700))),
                for (final s in sports)
                  Expanded(child: Center(child: _SportToggle(sport: s, selected: (plan[d] ?? []).contains(s), onTap: () => toggle(d, s)))),
                SizedBox(
                  width: 40,
                  child:
                      (plan[d] ?? []).any((s) => s != Sport.gym)
                          ? IconButton(
                            tooltip: l.longSessionDay,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              p.longDay == d ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: p.longDay == d ? AppColors.brand : Theme.of(context).colorScheme.outline,
                            ),
                            onPressed: () => _setLongDay(d),
                          )
                          : null,
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          '${l.sessionsPerWeekN(total)} · ${perSport.entries.map((e) => '${e.key.label(l)} ${e.value}×').join(' · ')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(l.longDayHint, style: Theme.of(context).textTheme.bodySmall),
        if (total > 0 && plan.values.where((v) => v.isNotEmpty).length >= 7)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.noRestDayWarning, style: const TextStyle(color: AppColors.warning, fontSize: 12)),
          ),
        // A sport of the focus without a single day (triathlon without cycling) is no plan for it.
        if (p.focus.sports.length > 1 && p.focus.sports.any((s) => (perSport[s] ?? 0) == 0))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l.weekMissingSport(
                [
                  for (final s in sports)
                    if (p.focus.sports.contains(s) && (perSport[s] ?? 0) == 0) s.label(l),
                ].join(', '),
                p.focus.label(l),
              ),
              key: const ValueKey('weekMissingSport'),
              style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        _timeSection(
          l,
          days: [
            for (final e in plan.entries)
              if (e.value.isNotEmpty) e.key,
          ],
        ),
        _label(l.preferredTime),
        Segments<String>(
          segments: [Seg('morning', label: l.morning), Seg('midday', label: l.midday), Seg('evening', label: l.evening)],
          value: a.preferredTime,
          onChanged: (v) => _setA({'preferredTime': v}),
        ),
        if (widget.mode == SetupMode.setup) ...[_label(l.units), _unitsSwitch(l)],
      ],
    );
  }

  Widget _running(AppLocalizations l) {
    final vdot = Vdot.of(a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h(l.runSetupTitle, l.runSetupSub, icon: Sport.run.icon, color: Sport.run.color),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.canRun30),
          subtitle: Text(l.canRun30Sub),
          value: a.canRun30,
          onChanged: (v) => _setA({'canRun30': v}),
        ),
        _label(l.raceTimesTitle, hint: l.raceTimesHint),
        Row(
          children: [
            Expanded(child: _raceTimeField(l, '5k', '5 km')),
            const SizedBox(width: 12),
            Expanded(child: _raceTimeField(l, '10k', '10 km')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _raceTimeField(l, 'hm', '${Units.num(21.1)} km')),
            const SizedBox(width: 12),
            Expanded(child: _raceTimeField(l, 'm', '${Units.num(42.2)} km')),
          ],
        ),
        if (vdot != null) ...[const SizedBox(height: 12), _ZonesPreview(vdot: vdot)],
        _label(l.currentVolume),
        LabeledSlider(
          label: l.weeklyKmNow,
          value: a.runWeeklyKm ?? 0,
          min: 0,
          max: 120,
          divisions: 60,
          format: (v) => v == 0 ? l.notSure : '${v.round()} km',
          onChanged: (v) => _setA({'runWeeklyKm': v == 0 ? null : v.roundToDouble()}),
        ),
        LabeledSlider(
          label: l.longestRun4w,
          value: a.longestRunKm ?? 0,
          min: 0,
          max: 42,
          divisions: 84,
          format: (v) => v == 0 ? l.notSure : '${Units.num(v)} km',
          onChanged: (v) => _setA({'longestRunKm': v == 0 ? null : (v * 2).round() / 2}),
        ),
      ],
    );
  }

  void _setRace(String k, int? v) {
    final m = {...a.raceTimes};
    if (v == null || v <= 0) {
      m.remove(k);
    } else {
      m[k] = v;
    }
    _setA({'raceTimes': m});
  }

  Widget _cycling(AppLocalizations l) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _h(l.rideSetupTitle, l.rideSetupSub, icon: Sport.ride.icon, color: Sport.ride.color),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.hasPowerMeter),
        value: a.hasPowerMeter,
        onChanged: (v) => _setA({'hasPowerMeter': v}),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.hasIndoorTrainer),
        value: a.indoorTrainer,
        onChanged: (v) => _setA({'indoorTrainer': v}),
      ),
      _label(l.ftpTitle, hint: l.ftpHint, term: Term.ftp),
      _numField(
        'FTP',
        a.ftp,
        (v) => a = a.merge({'ftp': v?.round()}),
        suffix: 'W',
        hint: a.hasPowerMeter ? '${PowerZones.estimate(p.level, p.weightKg)}' : null,
        decimal: false,
      ),
      _label(l.currentVolume),
      LabeledSlider(
        label: l.weeklyHoursNow,
        value: a.bikeWeeklyHours ?? 0,
        min: 0,
        max: 20,
        divisions: 40,
        format: (v) => v == 0 ? l.notSure : '${Units.num(v)} h',
        onChanged: (v) => _setA({'bikeWeeklyHours': v == 0 ? null : (v * 2).round() / 2}),
      ),
      LabeledSlider(
        label: l.longestRide4w,
        value: a.longestRideKm ?? 0,
        min: 0,
        max: 250,
        divisions: 50,
        format: (v) => v == 0 ? l.notSure : '${v.round()} km',
        onChanged: (v) => _setA({'longestRideKm': v == 0 ? null : v.roundToDouble()}),
      ),
    ],
  );

  Widget _swimming(AppLocalizations l) {
    final test = SwimZones.test(a.swim400Sec, a.swim200Sec);
    final css = test.css;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h(l.swimSetupTitle, l.swimSetupSub, icon: Sport.swim.icon, color: Sport.swim.color),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.canSwim400),
          subtitle: Text(l.canSwim400Sub),
          value: a.canSwim400,
          // No 400 m in one go: no 400 m test either (audit UX-15) – its times go with the switch.
          onChanged: (v) => _setA({'canSwim400': v, if (!v) 'swim400Sec': null, if (!v) 'swim200Sec': null}),
        ),
        if (a.canSwim400) ...[
          _label(l.cssTitle, hint: l.cssHint, term: Term.css),
          Row(children: [Expanded(child: _swimTestField(l, 400)), const SizedBox(width: 12), Expanded(child: _swimTestField(l, 200))]),
        ],
        // Feedback like the run step's pace zones: the CSS and the swim zones it gives, and why
        // an entry is not used as entered.
        if (a.canSwim400 && (test.kind == SwimTestKind.implausible || test.kind == SwimTestKind.only200))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              key: const ValueKey('swimTestHint'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    test.kind == SwimTestKind.only200 ? l.swimTestOnly200 : l.swimTestImplausible,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        if (css != null) ...[const SizedBox(height: 12), _SwimZonesPreview(css: css, estimated: test.kind != SwimTestKind.both)],
        _label(l.poolLength),
        Segments<int>(
          segments: [Seg(25, label: '25 m'), Seg(50, label: '50 m'), Seg(0, label: l.openWater)],
          value: a.poolLength,
          onChanged: (v) => _setA({'poolLength': v}),
        ),
        _label(l.currentVolume),
        LabeledSlider(
          label: l.weeklySwimKm,
          value: a.swimWeeklyKm ?? 0,
          min: 0,
          max: 25,
          divisions: 50,
          format: (v) => v == 0 ? l.notSure : '${Units.num(v)} km',
          onChanged: (v) => _setA({'swimWeeklyKm': v == 0 ? null : (v * 2).round() / 2}),
        ),
      ],
    );
  }

  Widget _strength(AppLocalizations l) {
    final lifts = {'squat': l.liftSquat, 'bench': l.liftBench, 'deadlift': l.liftDeadlift, 'ohp': l.liftOhp};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h(l.gymSetupTitle, l.gymSetupSub, icon: Sport.gym.icon, color: Sport.gym.color),
        _label(l.equipmentTitle),
        _choiceCard(
          selected: a.equipment == 'gym',
          title: l.equipGym,
          sub: l.equipGymSub,
          icon: Icons.fitness_center_rounded,
          color: AppColors.gym,
          onTap: () => _setA({'equipment': 'gym'}),
        ),
        _choiceCard(
          selected: a.equipment == 'home',
          title: l.equipHome,
          sub: l.equipHomeSub,
          icon: Icons.home_outlined,
          color: AppColors.gym,
          onTap: () => _setA({'equipment': 'home'}),
        ),
        _choiceCard(
          selected: a.equipment == 'bodyweight',
          title: l.equipBodyweight,
          sub: l.equipBodyweightSub2,
          icon: Icons.accessibility_new_rounded,
          color: AppColors.gym,
          onTap: () => _setA({'equipment': 'bodyweight'}),
        ),
        _splitSection(l),
        _label(l.gymGoalTitle),
        Segments<String>(
          segments: [Seg('strength', label: l.goalStrength), Seg('hypertrophy', label: l.goalMuscle), Seg('general', label: l.general)],
          value: a.gymGoal,
          onChanged: (v) => _setA({'gymGoal': v}),
        ),
        // Programs per gym day (own or built-in), optionally week A / week B.
        GymAssignSection(profile: _advanced ? _profile : _quickProfile, templates: ref.watch(templateListProvider), onChanged: _setA),
        if (_advanced) _label(l.oneRmTitle, hint: l.oneRmHint),
        if (_advanced)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.6,
            crossAxisSpacing: 12,
            children: [
              for (final e in lifts.entries)
                _numField(e.value, a.oneRm[e.key], (v) {
                  final m = {...a.oneRm};
                  v == null ? m.remove(e.key) : m[e.key] = v;
                  a = a.merge({'oneRm': m});
                }, suffix: 'kg'),
            ],
          ),
      ],
    );
  }

  /// Gym days in the current schedule (week plan or quick training days).
  Map<int, List<Sport>> get _week => PlanGenerator.scheduleOf(_advanced ? _profile : _quickProfile);

  int get _gymDays => _week.values.where((v) => v.contains(Sport.gym)).length;

  int get _enduranceSessions => _week.values.expand((v) => v).where((s) => s != Sport.gym).length;

  String _splitName(AppLocalizations l, String s) => switch (s) {
    'fullbody' => l.splitFullbody,
    'upperlower' => l.splitUpperLower,
    'ppl' => l.splitPpl,
    'ulppl' => l.splitUlppl,
    'bro' => l.splitBro,
    _ => l.splitAuto,
  };

  Widget _splitSection(AppLocalizations l) {
    final days = _gymDays;
    final rec = recommendedSplit(days, enduranceSessions: _enduranceSessions);
    if (a.equipment != 'gym') {
      return Padding(padding: const EdgeInsets.only(top: 16), child: Text(l.splitHomeNote2, style: Theme.of(context).textTheme.bodySmall));
    }
    String freq(String s) => l.splitFreq(NumberFormat('0.#', context.localeName).format(splitFrequency(s, days)));
    Widget card(String key, IconData icon, String sub) => _choiceCard(
      selected: a.gymSplit == key,
      title: key == 'auto' ? l.splitAuto : _splitName(l, key),
      sub: key == 'auto' ? l.splitAutoSub(_splitName(l, rec)) : '$sub\n${freq(key)}',
      icon: icon,
      color: AppColors.gym,
      badge: key == rec ? l.splitForDays(days) : null,
      onTap: () => _setA({'gymSplit': key}),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(l.splitTitle, hint: l.splitHint),
        card('auto', Icons.auto_awesome_rounded, ''),
        card('fullbody', Icons.accessibility_new_rounded, l.splitFullbodySub),
        card('upperlower', Icons.swap_vert_rounded, l.splitUpperLowerSub),
        card('ppl', Icons.view_column_rounded, l.splitPplSub),
        card('ulppl', Icons.dashboard_customize_rounded, l.splitUlpplSub),
        card('bro', Icons.calendar_view_week_rounded, l.splitBroSub),
        if (a.gymSplit == 'bro') Text(l.splitBroWarning, style: const TextStyle(color: AppColors.warning, fontSize: 12)),
        // Full body chosen for 4+ days: every muscle on consecutive days (review 2026-11 GYM-4).
        if (a.gymSplit == 'fullbody' && days >= 4)
          Text(l.splitFullbodyWarning, style: const TextStyle(color: AppColors.warning, fontSize: 12)),
      ],
    );
  }

  Widget _health(AppLocalizations l) {
    final opts = {
      'knee': l.limitKnee,
      'back': l.limitBack,
      'shoulder': l.limitShoulder,
      'hip': l.limitHip,
      'ankle': l.limitAnkle,
      'heart': l.limitHeart,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h(l.healthTitle, l.healthSub, icon: Icons.health_and_safety_outlined, color: AppColors.danger),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in opts.entries)
              FilterChip(
                label: Text(e.value),
                selected: a.limitations.contains(e.key),
                onSelected: (v) {
                  final list = [...a.limitations];
                  v ? list.add(e.key) : list.remove(e.key);
                  _setA({'limitations': list});
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(child: Text(l.healthDisclaimer, style: const TextStyle(fontSize: 13))),
            ],
          ),
        ),
      ],
    );
  }

  static double? _eventKm(String? d) => eventDistanceOf(d)?.km;

  String _distanceLabel(AppLocalizations l, String? d) => eventDistanceOf(d) == null ? l.goalTypeEvent : eventDistanceLabel(l, d!);

  Widget _event(AppLocalizations l) {
    final df = DateFormat.yMMMd(context.localeName);
    final sport = EventSportX.fromFocus(p.focus);
    // A pure gym plan trains for no race (audit UX-1: a 10 km after 17 weeks without a run): only a
    // plan length, and where a race goes instead.
    if (p.focus == TrainingFocus.gym) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h(l.planLength, l.eventGymNoRace, icon: Icons.date_range_rounded, color: AppColors.warning),
          Text(l.goalKindWeeksHint, style: Theme.of(context).textTheme.bodySmall),
          _label(l.planLength),
          _weekChips(l),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The examples are the races offered for this focus (hybrid: running races only).
        _h(
          l.eventQuestion,
          l.eventSubFor([for (final d in eventDistancesFor(sport).where((d) => d.primary).take(3)) d.label(l)].join(', ')),
          icon: Icons.emoji_events_outlined,
          color: AppColors.warning,
        ),
        // Race goal or just a plan length – both are first-class choices.
        Segments<bool>(
          key: const ValueKey('goalKind'),
          segments: [
            Seg(true, icon: Icons.emoji_events_outlined, label: l.goalKindRace),
            Seg(false, icon: Icons.date_range_rounded, label: l.goalKindWeeks),
          ],
          value: _withEvent,
          onChanged: (v) {
            FocusScope.of(context).unfocus();
            setState(() => _withEvent = v);
            if (!_withEvent) {
              _raceByWeeks = false;
              _eventName.clear();
              _setA({'eventDate': null, 'eventDistance': null, 'targetTimeSec': null});
            }
          },
        ),
        const SizedBox(height: 16),
        if (!_withEvent) ...[
          Text(l.goalKindWeeksHint, style: Theme.of(context).textTheme.bodySmall),
          _label(l.planLength),
          _weekChips(l),
        ] else ...[
          TextField(
            controller: _eventName,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l.eventName,
              // Left empty, the goal is named after the distance ("Halbmarathon").
              hintText: a.eventDistance == null ? null : _distanceLabel(l, a.eventDistance),
              prefixIcon: const Icon(Icons.flag_outlined),
            ),
          ),
          _label(l.eventDistance),
          EventDistanceChips(
            sports: [sport],
            selected: eventFitsFocus(a.eventDistance, p.focus) ? a.eventDistance : null,
            // A target time belongs to its distance.
            onChanged: (k) => _setA({'eventDistance': k, if (k != a.eventDistance) 'targetTimeSec': null}),
          ),
          _label(l.raceWhen),
          Segments<bool>(
            key: const ValueKey('raceWhen'),
            segments: [Seg(false, icon: Icons.event, label: l.raceByDate), Seg(true, icon: Icons.date_range_rounded, label: l.raceByWeeks)],
            value: _raceByWeeks,
            onChanged: _setRaceByWeeks,
          ),
          const SizedBox(height: 12),
          if (!_raceByWeeks) ...[
            OutlinedButton.icon(
              key: const ValueKey('eventDateButton'),
              icon: const Icon(Icons.event),
              label: Text(a.eventDate == null ? l.eventDate : df.format(a.eventDate!)),
              onPressed: () async {
                FocusScope.of(context).unfocus();
                final today = dayOnly(DateTime.now());
                final d = await showDatePicker(
                  context: context,
                  firstDate: today,
                  lastDate: addDays(today, 730),
                  initialDate: a.eventDate != null && !a.eventDate!.isBefore(today) ? a.eventDate! : _defaultRaceDate(today),
                );
                if (d != null) _setA({'eventDate': d});
              },
            ),
            if (a.eventDate == null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l.goalNeedsDate,
                  key: const ValueKey('eventNeedsDate'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
                ),
              ),
          ] else ...[
            Text(l.raceByWeeksHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            _weekChips(l, race: true),
            if (a.eventDate != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('raceOnDate'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_outlined, color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.raceOnDate(DateFormat.MMMEd(context.localeName).format(a.eventDate!)),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (a.eventDistance != null) ...[_label(l.targetTime, hint: l.targetTimeHint), _targetTimeField(l), _targetSuggestion(l)],
        ],
      ],
    );
  }

  /// Where the race date picker opens: the start of the race's recommended plan length, moved to
  /// the following race day – the long-session day, else Sunday (most races are on a weekend).
  DateTime _defaultRaceDate(DateTime today) => defaultRaceDate(today, _recommendedRange.$1, longDay: p.longDay);

  /// The profile the plan is generated from (the quick setup's view of it in the quick setup).
  UserProfile get _planProfile => _advanced ? _profile : _quickProfile;

  /// Date ↔ plan length of a race goal. The plan length starts in the recommended range of the race.
  void _setRaceByWeeks(bool byWeeks) {
    FocusScope.of(context).unfocus();
    if (byWeeks == _raceByWeeks) return;
    // A date picked before switching to "plan length" comes back when switching back (with it the
    // target suggestion) – switching to look at the plan lengths must not lose the entry.
    if (byWeeks) _pickedDate = a.eventDate;
    setState(() => _raceByWeeks = byWeeks);
    if (!byWeeks) {
      _setA({'eventDate': _pickedDate});
      return;
    }
    final rec = _recommendedRange;
    if (a.planWeeks < rec.$1 || a.planWeeks > rec.$2) {
      _setA({'planWeeks': rec.$1});
    } else {
      _setA({});
    }
  }

  /// Keeps the race day of a race given as a plan length on the long-session day of the plan's last
  /// week ([PlanGenerator.raceDayForWeeks], plan from [start]) – the long day follows the week, the
  /// race distance and the setup, so this runs after every change and before the plan is made.
  void _syncRaceDay({DateTime? start}) {
    if (!_withEvent || !_raceByWeeks) return;
    final d = PlanGenerator.raceDayForWeeks(_planProfile, start ?? dayOnly(DateTime.now()), a.planWeeks);
    if (a.eventDate == null || !sameDay(a.eventDate!, d)) a = a.merge({'eventDate': d});
  }

  /// Target time: scroll wheels within the race's plausible range, starting at the suggestion.
  Widget _targetTimeField(AppLocalizations l) {
    final key = a.eventDistance!;
    final bounds = eventTimeBounds(key);
    final date = a.eventDate ?? addDays(dayOnly(DateTime.now()), 7 * _recommendedRange.$1);
    final suggested = suggestTargetTime(_planProfile, key, date, sessions: _sessions).sec;
    return DurationField(
      key: const ValueKey('targetTime'),
      value: a.targetTimeSec,
      onChanged: (v) => _setA({'targetTimeSec': v}),
      title: l.targetTime,
      emptyText: l.noTargetTime,
      min: bounds?.$1,
      max: bounds?.$2,
      // A finish goal has no suggestion: halfway between the fastest and the slowest plausible time.
      initial: suggested ?? (bounds == null ? null : GoalModel.roundTarget(sqrt(bounds.$1 * bounds.$2).round())),
    );
  }

  /// Suggested target time for the chosen race (from race times, recent runs or the
  /// level) with one tap to take it over; "finish" for races without a time model.
  Widget _targetSuggestion(AppLocalizations l) {
    final key = a.eventDistance;
    final date = a.eventDate;
    if (key == null || date == null) return const SizedBox.shrink();
    return TargetSuggestionLine(
      profile: _advanced ? _profile : _quickProfile,
      eventKey: key,
      eventDate: date,
      sessions: _sessions,
      current: a.targetTimeSec,
      onApply: (sec) => _setA({'targetTimeSec': sec}),
    );
  }

  /// Plan length chips (weeks), the recommended range marked. [race]: the weeks to a race without a
  /// date – plain "12 Wochen" labels, and the race's recommended range is always offered.
  Widget _weekChips(AppLocalizations l, {bool race = false}) {
    final rec = _recommendedRange;
    final options =
        race
            ? [
              for (final w in ({4, 8, 12, 16, 20, rec.$1, rec.$2}.toList()..sort()))
                if (w >= PlanGenerator.supportedWeeks.first && w <= GoalModel.maxEventWeeks) (w, l.planWeeksN(w)),
            ]
            : [
              for (final w in const [4, 8, 12, 16, 20]) (w, l.planWeeksN(w)),
            ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (w, label) in options)
              ChoiceChip(
                key: ValueKey('weeks$w'),
                // The recommended lengths carry the same "Empfohlen" badge as the difficulty
                // cards (an icon in the avatar slot collided with the selection check).
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Narrow phones / large text: the label gives way, never an overflow.
                    Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (w >= rec.$1 && w <= rec.$2) ...[
                      const SizedBox(width: 6),
                      Container(
                        key: ValueKey('weeksRec$w'),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(8)),
                        child: Text(l.recommended, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                selected: a.planWeeks == w,
                onSelected: (_) => _setA({'planWeeks': w}),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l.planLengthHint(rec.$1, rec.$2), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  /// Recommended plan length (weeks) for the goal and level (training-science §1.8).
  (int, int) get _recommendedRange {
    final spec = EventSpec.of(a.eventDistance);
    if (spec != null) return spec.weeksFor(p.level);
    // No race: the generator's recommendation for focus and level.
    final r = PlanGenerator.recommendedWeeks(_profile);
    return (r.min, r.max);
  }

  /// Last step of the plan settings: "Das ändert sich: …", then "Plan neu erstellen" (with
  /// the usual replace confirmation).
  Widget _summary(AppLocalizations l) {
    final now = _advanced ? _profile : _quickProfile;
    final before =
        _orig.athlete.setupMode == 'advanced'
            ? _orig
            : _orig.copyWith(athlete: _orig.athlete.merge({'setupMode': 'simple', 'sessionsPerDay': 1}));
    final changes = planSettingChanges(l, context.localeName, before, now, nameBefore: _origName, nameAfter: _eventName.text.trim());
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h(l.summaryTitle, l.summarySub, icon: Icons.fact_check_outlined),
        Text(l.summaryChanges, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (changes.isEmpty)
          Text(l.summaryNoChanges, key: const ValueKey('summaryNoChanges'), style: t.bodyMedium)
        else
          for (final c in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.arrow_right_rounded, size: 20, color: AppColors.brand)),
                  const SizedBox(width: 4),
                  Expanded(child: Text(c, style: t.bodyMedium)),
                ],
              ),
            ),
        if (_orphanRaceGoal case final g?) ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('summaryRaceGoal'),
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 10),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  key: const ValueKey('removeRaceGoal'),
                  contentPadding: const EdgeInsets.only(right: 6),
                  value: _removeRaceGoal,
                  onChanged: (v) => setState(() => _removeRaceGoal = v),
                  title: Text(
                    l.summaryRemoveRaceGoal(g.title, DateFormat.yMMMd(context.localeName).format(g.deadline!)),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(_removeRaceGoal ? l.summaryRemoveRaceGoalOn : l.summaryRemoveRaceGoalOff, style: t.bodySmall),
                ),
              ],
            ),
          ),
        ],
        if (_generatePlan) ...[
          const SizedBox(height: 16),
          Text(l.summaryNewPlan, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final line in planSummaryLines(l, now))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check_rounded, size: 18, color: AppColors.success)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(line, style: t.bodyMedium)),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        if (_generatePlan) Text(l.planKeepsDone, style: t.bodySmall),
      ],
    );
  }

  Widget _plan(AppLocalizations l) {
    final weeksToEvent = a.eventDate == null ? null : PlanGenerator.planWeeksUntil(_planProfile, a.eventDate!, DateTime.now());
    // The generator's own race-specific block (Ironman 30, ultra 24, else 20 weeks) – audit T5.
    final specific = PlanGenerator.specificWeeksFor(_planProfile);
    final pre = weeksToEvent == null ? 0 : weeksToEvent - specific;
    final rec = _recommendedRange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h(l.planSetupTitle, l.planSetupSub, icon: Icons.auto_graph_rounded),
        _label(l.difficultyTitle, hint: l.difficultyHint),
        _choiceCard(
          selected: a.difficulty == 'easy',
          title: l.diffEasy,
          sub: l.diffEasySub,
          icon: Icons.spa_outlined,
          color: AppColors.run,
          onTap: () => _setA({'difficulty': 'easy'}),
        ),
        _choiceCard(
          selected: a.difficulty == 'balanced',
          title: l.diffBalanced,
          sub: l.diffBalancedSub,
          icon: Icons.balance_rounded,
          badge: l.recommended,
          onTap: () => _setA({'difficulty': 'balanced'}),
        ),
        _choiceCard(
          selected: a.difficulty == 'challenging',
          title: l.diffChallenging,
          sub: l.diffChallengingSub,
          icon: Icons.local_fire_department_outlined,
          color: AppColors.gym,
          onTap: () => _setA({'difficulty': 'challenging'}),
        ),
        _label(l.planLength),
        if (weeksToEvent != null && weeksToEvent >= 1 && weeksToEvent <= GoalModel.maxEventWeeks)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded, color: AppColors.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    [
                      pre > 0
                          ? l.planToEventPre(weeksToEvent, pre, specific)
                          : (weeksToEvent == 1
                              ? l.planToEventRaceWeek
                              : (weeksToEvent < rec.$1 ? l.planToEventShort(weeksToEvent, rec.$1) : l.planToEvent(weeksToEvent))),
                      if (widget.edit) l.planKeepsDone,
                    ].join('\n'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (weeksToEvent != null && weeksToEvent > GoalModel.maxEventWeeks) ...[
            Text(l.planEventTooFar, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
          ],
          _weekChips(l),
        ],
        // Goal not realistic in the time left (§1.8): say why and what would work – the
        // plan is generated anyway.
        if (a.eventDate != null && a.eventDistance != null) ...[
          const SizedBox(height: 12),
          FeasibilityCard(
            _feasibility.of(_advanced ? _profile : _quickProfile, DateTime.now(), l),
            planAnyway: _generatePlan,
            showTargetOk: true,
            onAdjustTarget: (sec) => _setA({'targetTimeSec': sec}),
            onExtendLongRun: (v) => _setA({'longRunExtend': v}),
            onAction: _applyFeasibility,
          ),
        ],
        const Divider(height: 32),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _generatePlan,
          onChanged: (v) => setState(() => _generatePlan = v),
          title: Text(l.generatePlanNow),
          subtitle: Text(l.generatePlanNowSub),
        ),
        const SizedBox(height: 8),
        Text(l.planScienceNote, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// The plan the settings will create: sessions per sport of a week ("Laufen 3× · Radfahren
/// 2× · …") and its length (to race day when the race is within reach, else the chosen weeks).
List<String> planSummaryLines(AppLocalizations l, UserProfile p, {DateTime? now}) {
  final week = PlanGenerator.scheduleOf(p);
  final count = <Sport, int>{};
  for (final v in week.values) {
    for (final s in v) {
      count[s] = (count[s] ?? 0) + 1;
    }
  }
  final sports = count.keys.toList()..sort((a, b) => a.index.compareTo(b.index));
  final total = count.values.fold<int>(0, (a, n) => a + n);
  final a = p.athlete;
  final toEvent = a.eventDate == null ? null : PlanGenerator.planWeeksUntil(p, a.eventDate!, now ?? DateTime.now());
  return [
    l.summaryWeekStructure('${l.sessionsPerWeekN(total)} – ${sports.map((s) => '${s.label(l)} ${count[s]}×').join(' · ')}'),
    toEvent != null && toEvent >= 1 && toEvent <= GoalModel.maxEventWeeks
        ? (toEvent == 1 ? l.summaryPlanLengthRaceWeek : l.summaryPlanLengthEvent(toEvent))
        : l.summaryPlanLength(a.planWeeks),
  ];
}

/// What the new plan settings change compared with [before] – one line each (empty: nothing).
List<String> planSettingChanges(
  AppLocalizations l,
  String locale,
  UserProfile before,
  UserProfile after, {
  String? nameBefore,
  String? nameAfter,
}) {
  final b = before.athlete, a = after.athlete;
  final df = DateFormat.yMMMd(locale);
  String days(UserProfile p) {
    final week = PlanGenerator.scheduleOf(p);
    final names = DateFormat.E(locale);
    return ([...week.keys]
      ..sort()).map((d) => '${names.format(DateTime(2024, 1, d))} ${week[d]!.map((s) => s.label(l)).join('+')}').join(', ');
  }

  String race(AthleteData x, String? name) {
    if (x.eventDate == null) return l.noRace;
    final distance = eventDistanceOf(x.eventDistance) == null ? null : eventDistanceLabel(l, x.eventDistance!);
    return [
      if (name != null && name.isNotEmpty) name,
      // An automatic name is the distance itself – once, not "Halbmarathon · Halbmarathon".
      if (distance != null && distance.toLowerCase() != name?.toLowerCase()) distance,
      df.format(x.eventDate!),
      if (x.targetTimeSec != null) clock(x.targetTimeSec!),
    ].join(' · ');
  }

  String diff(String d) => switch (d) {
    'easy' => l.diffEasy,
    'challenging' => l.diffChallenging,
    _ => l.diffBalanced,
  };
  final out = <String>[];
  void add(String label, String from, String to) {
    if (from != to) out.add('$label: $from → $to');
  }

  add(l.focusTitle, before.focus.label(l), after.focus.label(l));
  // Quick ↔ detailed setup is how the settings were entered, not a property of the plan – its
  // effect shows in the week line below.
  add(l.summaryWeek, days(before), days(after));
  add(l.timeTitle, formatMinutes(b.sessionMinutes), formatMinutes(a.sessionMinutes));
  add(l.summaryRace, race(b, nameBefore), race(a, nameAfter));
  if (a.eventDate == null) add(l.planLength, l.planWeeksN(b.planWeeks), l.planWeeksN(a.planWeeks));
  add(l.difficultyTitle, diff(b.difficulty), diff(a.difficulty));
  add(l.longRunExtendTitle, b.longRunExtend ? l.yes : l.no, a.longRunExtend ? l.yes : l.no);
  // The sport data (a new best time changes every pace of the plan) – the running form by name, the
  // rest (bike, swim, gym, health) in one line: "nothing changes" after a new 10 km time was wrong.
  String vdot(double? v) => v == null ? '–' : Units.fixed(v);
  final vb = Vdot.of(b), va = Vdot.of(a);
  add(l.summaryRunFitness, vdot(vb), vdot(va));
  const sportData = [
    'raceTimes', 'runWeeklyKm', 'longestRunKm', 'canRun30', 'ftp', 'bikeWeeklyHours', 'longestRideKm', 'hasPowerMeter', //
    'indoorTrainer', 'swim400Sec', 'swim200Sec', 'swimWeeklyKm', 'canSwim400', 'poolLength', 'equipment', 'gymGoal', //
    'gymSplit', 'oneRm', 'gymAssign', 'gymAB', 'gymPlanA', 'gymPlanB', 'limitations', 'restHr',
  ];
  final bm = b.toMap(), am = a.toMap();
  final otherData =
      before.level != after.level ||
      '${before.experience.map((s) => s.name).toList()..sort()}' != '${after.experience.map((s) => s.name).toList()..sort()}' ||
      sportData.any((k) => !(k == 'raceTimes' && vdot(vb) != vdot(va)) && '${bm[k]}' != '${am[k]}');
  if (otherData) out.add(l.summarySportDataChanged);
  return out;
}

/// Live pace zones preview from the entered race times (VDOT).
class _ZonesPreview extends StatelessWidget {
  const _ZonesPreview({required this.vdot});
  final double vdot;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final z = PaceZones(vdot);
    Widget row(String name, String pace, Color c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(name)),
          Text('$pace /km', style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.run.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text('${l.yourPaceZones} · VDOT ${Units.fixed(vdot)}', style: const TextStyle(fontWeight: FontWeight.w700))),
              const TermInfoButton(Term.vdot),
            ],
          ),
          const SizedBox(height: 6),
          row(l.zoneEasy, '${fmtPace(z.easyFast)}–${fmtPace(z.easySlow)}', AppColors.run),
          row(l.zoneMarathon, fmtPace(z.marathon), AppColors.swim),
          row(l.zoneThreshold, fmtPace(z.threshold), AppColors.ride),
          row(l.zoneInterval, fmtPace(z.interval), AppColors.gym),
          row(l.zoneRepetition, fmtPace(z.repetition), AppColors.danger),
        ],
      ),
    );
  }
}

/// Live swim zones preview from the CSS test (the swim counterpart of [_ZonesPreview]).
class _SwimZonesPreview extends StatelessWidget {
  const _SwimZonesPreview({required this.css, required this.estimated});
  final int css;

  /// From the 400 m alone (or with an implausible 200 m) – an estimate.
  final bool estimated;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final z = SwimZones(css);
    String range(String zone) {
      final r = z.range(zone);
      return '${fmtPace(r.$1)}–${fmtPace(r.$2)}';
    }

    Widget row(String name, String pace, Color c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(name)),
          Text('$pace /100 m', style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
    return Container(
      key: const ValueKey('swimZonesPreview'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.swim.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  '${l.yourSwimZones} · CSS ${estimated ? '≈ ' : ''}${fmtPace(css)} /100 m',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const TermInfoButton(Term.css),
            ],
          ),
          if (estimated) Text(l.swimCssEstimated, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          row(zoneLabel(l, 'REC', sport: Sport.swim), range('REC'), const Color(0xFF7D8CA3)),
          row(zoneLabel(l, 'EN', sport: Sport.swim), range('EN'), AppColors.run),
          row(zoneLabel(l, 'CSS', sport: Sport.swim), range('CSS'), AppColors.ride),
          row(zoneLabel(l, 'SP', sport: Sport.swim), range('SP'), AppColors.danger),
        ],
      ),
    );
  }
}

class _SportToggle extends StatelessWidget {
  const _SportToggle({required this.sport, required this.selected, required this.onTap});
  final Sport sport;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    customBorder: const CircleBorder(),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? sport.color : sport.color.withValues(alpha: 0.08),
        border: Border.all(color: sport.color.withValues(alpha: selected ? 1 : 0.35)),
      ),
      child: Icon(sport.icon, size: 20, color: selected ? Colors.black87 : sport.color.withValues(alpha: 0.7)),
    ),
  );
}

/// Recommended sessions per sport with an "apply" button.
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.freq,
    required this.title,
    required this.action,
    required this.onApply,
    this.current,
    this.applied = false,
    this.note,
  });
  final Map<Sport, int> freq;
  final Map<Sport, int>? current;

  /// A warning below the sessions (the race needs more than the week can hold).
  final String? note;
  final String title;
  final String action;
  final VoidCallback onApply;
  final bool applied;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: [AppColors.brand.withValues(alpha: 0.20), AppColors.brand.withValues(alpha: 0.06)]),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.brand),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in freq.entries)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: e.key.color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(e.key.icon, size: 16, color: e.key.color),
                      const SizedBox(width: 6),
                      // What the week has now, next to the recommendation ("5× / Woche · jetzt 4×") –
                      // wraps on a narrow phone instead of overflowing the chip.
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: l.recPerWeek(e.value), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              if (current != null && current![e.key] != e.value)
                                TextSpan(text: ' · ${l.recNow(current![e.key] ?? 0)}', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Row(
              key: const ValueKey('recMinNoFit'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                const SizedBox(width: 6),
                Expanded(child: Text(note!, style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(l.recSub, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child:
                applied
                    ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.brand),
                          const SizedBox(width: 6),
                          Text(l.recActive, style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                    : FilledButton.tonalIcon(
                      onPressed: onApply,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: Text(action),
                    ),
          ),
        ],
      ),
    );
  }
}

/// Weekday toggle for the quick setup.
class _DayChip extends StatelessWidget {
  const _DayChip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.brand : scheme.outlineVariant),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : scheme.onSurfaceVariant)),
        ),
      ),
    );
  }
}

/// − 60 min + stepper (15-min steps, 20–240 min).
class _MinutesStepper extends StatelessWidget {
  const _MinutesStepper({required this.value, required this.onChanged, this.big = false, this.dimmed = false});
  final int value;
  final ValueChanged<int> onChanged;
  final bool big;
  final bool dimmed;

  static String fmt(int m) => formatMinutes(m);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Text(
      fmt(value),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: big ? 22 : 15,
        fontWeight: FontWeight.w700,
        color: dimmed ? scheme.outline : scheme.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final row = Row(
      mainAxisSize: big ? MainAxisSize.max : MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          visualDensity: big ? VisualDensity.standard : VisualDensity.compact,
          onPressed: value > 20 ? () => onChanged(value <= 30 ? 20 : value - (value > 180 ? 30 : 15)) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        big ? Expanded(child: text) : SizedBox(width: 74, child: text),
        IconButton.filledTonal(
          visualDensity: big ? VisualDensity.standard : VisualDensity.compact,
          // Up to 8 h (Ironman long rides 5–6 h + brick run); 30-min steps above 3 h.
          onPressed: value < 480 ? () => onChanged(value < 30 ? 30 : value + (value >= 180 ? 30 : 15)) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
    if (!big) return row;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(18)),
      child: row,
    );
  }
}

/// One step of the setup in its own element: it rebuilds with the page, but an exception while
/// building it is contained here (the framework's error widget replaces this step only).
class _StepPage extends StatelessWidget {
  const _StepPage({super.key, required this.content});
  final Widget Function() content;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), child: content());
}
