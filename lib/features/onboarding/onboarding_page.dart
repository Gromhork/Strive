import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/default_programs.dart';
import '../calendar/feasibility_card.dart';
import '../goals/race_search_page.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/plan_generator.dart';
import '../../services/schedule_advisor.dart';
import '../../services/zones.dart';
import '../../widgets/common.dart';
import '../../widgets/segments.dart';

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
  late UserProfile p;
  late AthleteData a;
  final _name = TextEditingController();
  bool _imperial = false;

  // Event
  final _eventName = TextEditingController();
  bool _generatePlan = true;
  final _feasibility = FeasibilityCache();

  @override
  void initState() {
    super.initState();
    p = ref.read(profileProvider).value ?? UserProfile(name: _accountName(), birthYear: DateTime.now().year - 28);
    a = p.athlete;
    _eventName.text = a.eventName ?? '';
    _name.text = p.name;
    _imperial = p.imperial;
    _generatePlan = widget.mode != SetupMode.profile;
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

  /// Sets the long-session day ([d] null = automatic).
  void _setLongDay(int? d) => setState(() => p = UserProfile.fromMap({...p.toMap(), 'longDay': d}));
  Set<Sport> get _sports => {...p.focus.sports, if (p.goals.contains('strength') || p.goals.contains('muscle')) Sport.gym};

  void _setA(Map<String, dynamic> changes) => setState(() => a = a.merge(changes));

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
    ];
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_page < _steps.length - 1) {
      _pager.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  void _finish() {
    final repo = ref.read(repoProvider)!;
    final l = context.l10n;
    final de = context.localeName.startsWith('de');
    // Sports that are no longer part of the focus (e.g. after switching from
    // triathlon to hybrid) are removed from the week plan.
    final sports = _sports;
    a = a.merge({
      'dayPlan': {for (final e in a.dayPlan.entries) e.key: e.value.where(sports.contains).toList()},
      'eventName': _eventName.text.trim().isEmpty ? null : _eventName.text.trim(),
    });
    var days = [
      ...(p.trainingDays.isEmpty ? const [1, 3, 5] : p.trainingDays),
    ]..sort();
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

    // Programs: all built-ins for new users; otherwise add the ones the split needs.
    var templates = ref.read(templateListProvider);
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
      final goals = ref.read(goalsProvider).value ?? const <Goal>[];
      final existing = goals.where((g) => g.type == GoalType.event && g.deadline != null && sameDay(g.deadline!, a.eventDate!)).firstOrNull;
      repo.saveGoal(
        Goal(
          id: existing?.id ?? repo.newId(),
          type: GoalType.event,
          title: _eventName.text.trim().isEmpty ? _distanceLabel(l, a.eventDistance) : _eventName.text.trim(),
          sport: profile.focus.sports.last,
          target: km ?? 0,
          eventKm: km,
          created: existing?.created ?? now,
          deadline: a.eventDate,
        ),
      );
    }

    if (_generatePlan) {
      final existing = ref.read(planListProvider);
      repo.deletePlansFrom(existing, dayOnly(now));
      final plan = PlanGenerator(l, profile, templates, repo.newId).generate(start: now, weeks: a.planWeeks);
      repo.savePlans(plan);
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
    return Scaffold(
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
          if (!widget.edit) IconButton(tooltip: l.logout, onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout)),
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
              child: PageView(
                controller: _pager,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final s in steps)
                    SingleChildScrollView(key: ValueKey(s.$1), padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), child: s.$2(l)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _page == 0 && widget.mode == SetupMode.setup && _name.text.trim().isEmpty ? null : _next,
                  child: Text(last ? (widget.edit ? l.save : l.letsGo) : l.next),
                ),
              ),
            ),
          ],
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

  Widget _label(String s, {String? hint}) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
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

  /// Duration input as "mm:ss" or "h:mm:ss".
  Widget _timeField(String label, int? seconds, ValueChanged<int?> onChanged, {String hint = 'mm:ss'}) => TextFormField(
    initialValue: seconds == null ? '' : clock(seconds),
    keyboardType: TextInputType.datetime,
    decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: const Icon(Icons.timer_outlined, size: 20)),
    onChanged: (v) => onChanged(parseClock(v)),
  );

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
        Text('BMI ${p.bmi.toStringAsFixed(1)}', style: Theme.of(context).textTheme.bodySmall),
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
              if (v == 'advanced' && a.dayPlan.values.every((x) => x.isEmpty)) _setA({'dayPlan': PlanGenerator.deriveSchedule(_profile)});
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

  String _dayName(int d) => DateFormat.E(context.localeName).format(startOfWeek(DateTime.now()).add(Duration(days: d - 1)));

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
        if (widget.mode == SetupMode.setup) ...[_label(l.units), _unitsSwitch(l)],
      ],
    );
  }

  static bool _listEq(List<int> x, List<int> y) => x.length == y.length && List.generate(x.length, (i) => x[i] == y[i]).every((v) => v);

  /// Max. training time per day (global) with optional per-day overrides.
  Widget _timeSection(AppLocalizations l, {required List<int> days}) {
    final profile = _advanced ? _profile : _quickProfile;
    final longDay = PlanGenerator.longDayOf(profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(l.timeTitle, hint: l.timeHint),
        _MinutesStepper(value: a.sessionMinutes, onChanged: (v) => _setA({'sessionMinutes': v}), big: true),
        if (longDay != null && !a.dayMinutes.containsKey(longDay))
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.timeLongDayHint, style: Theme.of(context).textTheme.bodySmall)),
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
              Expanded(child: Center(child: Text(s.label(l), style: TextStyle(fontSize: 11, color: s.color, fontWeight: FontWeight.w600)))),
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
            Expanded(child: _timeField('5 km', a.raceTimes['5k'], (v) => _setRace('5k', v))),
            const SizedBox(width: 12),
            Expanded(child: _timeField('10 km', a.raceTimes['10k'], (v) => _setRace('10k', v))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _timeField('21,1 km', a.raceTimes['hm'], (v) => _setRace('hm', v), hint: 'h:mm:ss')),
            const SizedBox(width: 12),
            Expanded(child: _timeField('42,2 km', a.raceTimes['m'], (v) => _setRace('m', v), hint: 'h:mm:ss')),
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
      _label(l.ftpTitle, hint: l.ftpHint),
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
    final css = SwimZones.fromTests(a.swim400Sec, a.swim200Sec);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h(l.swimSetupTitle, l.swimSetupSub, icon: Sport.swim.icon, color: Sport.swim.color),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.canSwim400),
          value: a.canSwim400,
          onChanged: (v) => _setA({'canSwim400': v}),
        ),
        _label(l.cssTitle, hint: l.cssHint),
        Row(
          children: [
            Expanded(child: _timeField('400 m', a.swim400Sec, (v) => _setA({'swim400Sec': v}))),
            const SizedBox(width: 12),
            Expanded(child: _timeField('200 m', a.swim200Sec, (v) => _setA({'swim200Sec': v}))),
          ],
        ),
        if (css != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.cssResult(fmtPace(css)), style: const TextStyle(color: AppColors.swim, fontWeight: FontWeight.w600)),
          ),
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
          sub: l.equipBodyweightSub,
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
      return Padding(padding: const EdgeInsets.only(top: 16), child: Text(l.splitHomeNote, style: Theme.of(context).textTheme.bodySmall));
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

  static double? _eventKm(String? d) => switch (d) {
    '5k' => 5,
    '10k' => 10,
    'hm' => 21.1,
    'm' => 42.2,
    'sprint' => 25.75,
    'olympic' => 51.5,
    '70.3' => 113,
    _ => null,
  };

  String _distanceLabel(AppLocalizations l, String? d) => switch (d) {
    '5k' => '5 km',
    '10k' => '10 km',
    'hm' => l.halfMarathon,
    'm' => l.marathon,
    'sprint' => 'Sprint-Triathlon',
    'olympic' => l.olympicTri,
    '70.3' => l.middleDistance,
    _ => l.eventTitle,
  };

  Widget _event(AppLocalizations l) {
    final df = DateFormat.yMMMd(context.localeName);
    final dists = [
      if (_sports.contains(Sport.run)) ...['5k', '10k', 'hm', 'm'],
      if (p.focus == TrainingFocus.triathlon) ...['sprint', 'olympic', '70.3'],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h(l.eventTitle, l.eventSub, icon: Icons.emoji_events_outlined, color: AppColors.warning),
        TextField(controller: _eventName, decoration: InputDecoration(labelText: l.eventName, prefixIcon: const Icon(Icons.flag_outlined))),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.event),
          label: Text(a.eventDate == null ? l.eventDate : df.format(a.eventDate!)),
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 730)),
              initialDate: a.eventDate ?? DateTime.now().add(const Duration(days: 90)),
            );
            if (d != null) _setA({'eventDate': d});
          },
        ),
        if (dists.isNotEmpty) ...[
          _label(l.eventDistance),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in dists)
                ChoiceChip(
                  label: Text(_distanceLabel(l, d)),
                  selected: a.eventDistance == d,
                  onSelected: (v) => _setA({'eventDistance': v ? d : null}),
                ),
            ],
          ),
        ],
        if (_advanced && a.eventDistance != null) ...[
          _label(l.targetTime, hint: l.targetTimeHint),
          _timeField(l.targetTime, a.targetTimeSec, (v) => _setA({'targetTimeSec': v}), hint: 'h:mm:ss'),
          if (Vdot.of(a) != null && Vdot.distances[a.eventDistance] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l.predictedTime(clock(Vdot.raceTime(Vdot.of(a)!, Vdot.distances[a.eventDistance]!))),
                style: const TextStyle(color: AppColors.run, fontWeight: FontWeight.w600),
              ),
            ),
        ],
        const SizedBox(height: 12),
        TextButton.icon(
          icon: const Icon(Icons.travel_explore_rounded),
          label: Text(l.raceSearch),
          onPressed: () async {
            // The setup saves the profile itself when finished.
            final r = await openRaceSearch(context, saveToProfile: false);
            if (r == null || !mounted) return;
            _eventName.text = r.name;
            _setA({'eventDate': r.date, if (r.distance != null && dists.contains(r.distance)) 'eventDistance': r.distance});
          },
        ),
      ],
    );
  }

  /// Recommended plan length (weeks) for the goal and level (training-science §1.8).
  (int, int) get _recommendedRange => switch ((a.eventDistance, p.level)) {
    ('5k', 'beginner') => (8, 10),
    ('5k', _) => (8, 12),
    ('10k', _) => (8, 12),
    ('hm', 'advanced') => (12, 16),
    ('hm', _) => (12, 14),
    ('m', 'beginner' || 'intermediate') => (16, 20),
    ('m', _) => (16, 18),
    ('sprint', _) => (8, 12),
    ('olympic', _) => (12, 16),
    ('70.3', _) => (16, 20),
    _ => (6, 12),
  };

  Widget _plan(AppLocalizations l) {
    final weeksToEvent =
        a.eventDate == null ? null : (startOfWeek(a.eventDate!).difference(startOfWeek(DateTime.now())).inDays / 7).floor() + 1;
    final rec = _recommendedRange;
    final options = [(4, l.plan4w), (8, l.plan8w), (12, l.plan12w), (16, l.plan16w), (20, l.plan20w)];
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
        if (weeksToEvent != null && weeksToEvent >= 2 && weeksToEvent <= 30)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded, color: AppColors.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    weeksToEvent < rec.$1 ? l.planToEventShort(weeksToEvent, rec.$1) : l.planToEvent(weeksToEvent),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (w, label) in options)
                ChoiceChip(
                  label: Text(label),
                  selected: a.planWeeks == w,
                  avatar: w >= rec.$1 && w <= rec.$2 ? const Icon(Icons.thumb_up_alt_outlined, size: 16) : null,
                  onSelected: (_) => _setA({'planWeeks': w}),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l.planLengthHint(rec.$1, rec.$2), style: Theme.of(context).textTheme.bodySmall),
        ],
        // Goal not realistic in the time left (§1.8): say why and what would work – the
        // plan is generated anyway.
        if (a.eventDate != null && a.eventDistance != null) ...[
          const SizedBox(height: 12),
          FeasibilityCard(_feasibility.of(_advanced ? _profile : _quickProfile, DateTime.now(), l), planAnyway: _generatePlan),
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
          Text('${l.yourPaceZones} · VDOT ${vdot.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w700)),
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
  });
  final Map<Sport, int> freq;
  final Map<Sport, int>? current;
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
                      Text(l.recPerWeek(e.value), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (current != null && current![e.key] != e.value) ...[
                        const SizedBox(width: 4),
                        Text('(${current![e.key] ?? 0})', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
            ],
          ),
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

  static String fmt(int m) => m < 60 || m % 60 != 0 && m < 90 ? '$m min' : (m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60}');

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
          onPressed: value > 20 ? () => onChanged(value <= 30 ? 20 : value - 15) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        big ? Expanded(child: text) : SizedBox(width: 74, child: text),
        IconButton.filledTonal(
          visualDensity: big ? VisualDensity.standard : VisualDensity.compact,
          onPressed: value < 240 ? () => onChanged(value < 30 ? 30 : value + 15) : null,
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
