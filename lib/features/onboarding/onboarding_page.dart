import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/sport.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import '../../services/plan_generator.dart';
import '../../services/zones.dart';
import '../../widgets/common.dart';

/// First-time setup (and profile editing).
///
/// Two paths: **Quick** (general questions, ~2 min) and **Detailed** (sport-specific
/// data such as race times, weekly volume, FTP, CSS, 1RMs and a per-weekday plan).
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, this.edit = false});

  /// When true the page edits an existing profile instead of first-time setup.
  final bool edit;

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

  @override
  void initState() {
    super.initState();
    p =
        ref.read(profileProvider).value ??
        UserProfile(name: FirebaseAuth.instance.currentUser?.displayName ?? '', birthYear: DateTime.now().year - 28);
    a = p.athlete;
    _name.text = p.name;
    _imperial = p.imperial;
    _generatePlan = !widget.edit;
  }

  bool get _advanced => a.setupMode == 'advanced';
  Set<Sport> get _sports => {...p.focus.sports, if (p.goals.contains('strength') || p.goals.contains('muscle')) Sport.gym};

  void _setA(Map<String, dynamic> changes) => setState(() => a = a.merge(changes));

  List<_Step> get _steps => [
    ('welcome', _welcome),
    ('body', _body),
    ('fitness', _fitness),
    ('focus', _focus),
    if (_advanced) ('week', _weekPlan) else ('schedule', _schedule),
    if (_advanced && _sports.contains(Sport.run)) ('run', _running),
    if (_advanced && _sports.contains(Sport.ride)) ('ride', _cycling),
    if (_advanced && _sports.contains(Sport.swim)) ('swim', _swimming),
    if (_advanced && _sports.contains(Sport.gym)) ('gym', _strength),
    if (_advanced) ('health', _health),
    ('event', _event),
    ('plan', _plan),
  ];

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
    var days = p.trainingDays;
    if (_advanced && a.dayPlan.values.any((v) => v.isNotEmpty)) {
      days = (a.dayPlan.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toList()..sort());
    }
    final profile = p.copyWith(
      name: _name.text.trim(),
      imperial: _imperial,
      onboarded: true,
      athlete: a,
      trainingDays: days,
    );
    repo.saveProfile(profile);
    final now = DateTime.now();

    if (!widget.edit) {
      repo.saveBody(
        BodyEntry(id: repo.newId(), date: now, weightKg: profile.weightKg, fatPct: profile.fatPct, musclePct: profile.musclePct),
      );
    }

    var templates = ref.read(templateListProvider);
    if (templates.isEmpty) {
      templates = defaultTemplates(repo.newId);
      for (final t in templates) {
        repo.saveTemplate(t);
      }
    }

    if (a.eventDate != null && (a.eventDistance != null || _eventName.text.trim().isNotEmpty)) {
      final km = _eventKm(a.eventDistance);
      repo.saveGoal(
        Goal(
          id: repo.newId(),
          type: GoalType.event,
          title: _eventName.text.trim().isEmpty ? _distanceLabel(l, a.eventDistance) : _eventName.text.trim(),
          sport: profile.focus.sports.last,
          target: km ?? 0,
          eventKm: km,
          created: now,
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
        title: Text(widget.edit ? l.editProfile : l.onboardingTitle),
        actions: [
          if (!widget.edit)
            IconButton(tooltip: l.logout, onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout)),
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
                  onPressed: _page == 0 && _name.text.trim().isEmpty ? null : _next,
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
          if (a.dayPlan.values.every((v) => v.isEmpty)) _setA({'dayPlan': PlanGenerator.deriveSchedule(p)});
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
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'm', label: Text(l.male)),
            ButtonSegment(value: 'f', label: Text(l.female)),
            ButtonSegment(value: 'd', label: Text(l.diverse)),
          ],
          selected: {p.gender},
          onSelectionChanged: (s) => setState(() => p = p.copyWith(gender: s.first)),
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
                onTap: () => setState(() => p = p.copyWith(focus: f)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: p.focus == f ? AppColors.brand.withValues(alpha: 0.2) : Theme.of(context).colorScheme.surfaceContainer,
                    border: Border.all(color: p.focus == f ? AppColors.brand : Theme.of(context).colorScheme.outlineVariant, width: p.focus == f ? 2 : 1),
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
                onSelected:
                    (v) => setState(() {
                      final list = [...p.goals];
                      v ? list.add(g.key) : list.remove(g.key);
                      p = p.copyWith(goals: list);
                    }),
              ),
          ],
        ),
      ],
    );
  }

  String _dayName(int d) => DateFormat.E(context.localeName).format(startOfWeek(DateTime.now()).add(Duration(days: d - 1)));

  /// Quick setup: training days + long day + units.
  Widget _schedule(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _h(l.scheduleTitle, l.scheduleSub, icon: Icons.calendar_month_rounded),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              ChoiceChip(
                showCheckmark: false,
                label: SizedBox(width: 30, child: Text(_dayName(d), textAlign: TextAlign.center)),
                selected: p.trainingDays.contains(d),
                onSelected:
                    (v) => setState(() {
                      final days = [...p.trainingDays];
                      v ? days.add(d) : days.remove(d);
                      days.sort();
                      p = p.copyWith(trainingDays: days);
                    }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l.daysPerWeek(p.trainingDays.length), style: Theme.of(context).textTheme.bodySmall),
        if (p.focus != TrainingFocus.gym) ...[
          _label(l.longSessionDay),
          DropdownButtonFormField<int?>(
            value: p.trainingDays.contains(p.longDay) ? p.longDay : null,
            items: [
              DropdownMenuItem(value: null, child: Text(l.automatic)),
              for (final d in p.trainingDays) DropdownMenuItem(value: d, child: Text(_dayName(d))),
            ],
            onChanged: (v) => setState(() => p = UserProfile.fromMap({...p.toMap(), 'longDay': v})),
          ),
        ],
        _label(l.sessionLength),
        _sessionMinutes(l),
        _label(l.units),
        _unitsSwitch(l),
      ],
    );
  }

  Widget _sessionMinutes(AppLocalizations l) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final m in const [30, 45, 60, 75, 90, 120])
        ChoiceChip(label: Text('$m min'), selected: a.sessionMinutes == m, onSelected: (_) => _setA({'sessionMinutes': m})),
    ],
  );

  Widget _unitsSwitch(AppLocalizations l) => SegmentedButton<bool>(
    segments: [ButtonSegment(value: false, label: Text(l.metric)), ButtonSegment(value: true, label: Text(l.imperial))],
    selected: {_imperial},
    onSelectionChanged: (s) => setState(() => _imperial = s.first),
  );

  /// Detailed setup: which sport on which weekday (1–2 sessions per day).
  Widget _weekPlan(AppLocalizations l) {
    final sports = _sports.toList()..sort((x, y) => x.index.compareTo(y.index));
    final plan = {for (final e in a.dayPlan.entries) e.key: [...e.value]};
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
        SegmentedButton<int>(
          segments: [ButtonSegment(value: 1, label: Text(l.oncePerDay)), ButtonSegment(value: 2, label: Text(l.twicePerDay))],
          selected: {a.sessionsPerDay},
          onSelectionChanged: (s) {
            final n = s.first;
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
                  Expanded(
                    child: Center(
                      child: _SportToggle(sport: s, selected: (plan[d] ?? []).contains(s), onTap: () => toggle(d, s)),
                    ),
                  ),
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
                            onPressed: () => setState(() => p = UserProfile.fromMap({...p.toMap(), 'longDay': d})),
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
        _label(l.sessionLength),
        _sessionMinutes(l),
        _label(l.preferredTime),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'morning', label: Text(l.morning)),
            ButtonSegment(value: 'midday', label: Text(l.midday)),
            ButtonSegment(value: 'evening', label: Text(l.evening)),
          ],
          selected: {a.preferredTime},
          onSelectionChanged: (s) => _setA({'preferredTime': s.first}),
        ),
        _label(l.units),
        _unitsSwitch(l),
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
      _numField('FTP', a.ftp, (v) => a = a.merge({'ftp': v?.round()}), suffix: 'W', hint: a.hasPowerMeter ? '${PowerZones.estimate(p.level, p.weightKg)}' : null, decimal: false),
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
        SegmentedButton<int>(
          segments: [
            const ButtonSegment(value: 25, label: Text('25 m')),
            const ButtonSegment(value: 50, label: Text('50 m')),
            ButtonSegment(value: 0, label: Text(l.openWater)),
          ],
          selected: {a.poolLength},
          onSelectionChanged: (s) => _setA({'poolLength': s.first}),
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
        _label(l.gymGoalTitle),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'strength', label: Text(l.goalStrength)),
            ButtonSegment(value: 'hypertrophy', label: Text(l.goalMuscle)),
            ButtonSegment(value: 'general', label: Text(l.general)),
          ],
          selected: {a.gymGoal},
          onSelectionChanged: (s) => _setA({'gymGoal': s.first}),
        ),
        _label(l.oneRmTitle, hint: l.oneRmHint),
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
        TextField(
          controller: _eventName,
          decoration: InputDecoration(labelText: l.eventName, prefixIcon: const Icon(Icons.flag_outlined)),
        ),
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
          icon: const Icon(Icons.search),
          label: Text(l.searchMarathonDe),
          onPressed: () => launchUrl(Uri.parse('https://www.marathon.de/laufkalender'), mode: LaunchMode.externalApplication),
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
    final weeksToEvent = a.eventDate == null ? null : (startOfWeek(a.eventDate!).difference(startOfWeek(DateTime.now())).inDays / 7).floor() + 1;
    final rec = _recommendedRange;
    final options = [
      (4, l.plan4w),
      (8, l.plan8w),
      (12, l.plan12w),
      (16, l.plan16w),
      (20, l.plan20w),
    ];
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
