import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../services/coach_service.dart';
import '../calendar/plan_editor.dart';
import '../goals/goals_page.dart';

class _Msg {
  _Msg(this.user, this.text);
  final bool user;
  String text;
  bool error = false;
}

class CoachPage extends ConsumerStatefulWidget {
  const CoachPage({super.key});
  @override
  ConsumerState<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends ConsumerState<CoachPage> with AutomaticKeepAliveClientMixin {
  final _msgs = <_Msg>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  CoachService? _coach;
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  CoachService _service() =>
      _coach ??= CoachService(
        profile: ref.read(profileOrDefaultProvider),
        sessions: ref.read(sessionListProvider),
        plans: ref.read(planListProvider),
        lang: Localizations.localeOf(context).languageCode,
      );

  Future<void> _send(String text) async {
    final l = context.l10n;
    if (text.trim().isEmpty || _busy) return;
    _input.clear();
    final answer = _Msg(false, '');
    setState(() {
      _msgs.add(_Msg(true, text.trim()));
      _msgs.add(answer);
      _busy = true;
    });
    _toBottom();
    try {
      await for (final chunk in _service().ask(text.trim())) {
        setState(() => answer.text += chunk);
        _toBottom();
      }
      if (answer.text.isEmpty) answer.text = '…';
    } catch (e) {
      setState(() {
        answer.error = true;
        answer.text = '${l.aiUnavailable}\n\n$e';
      });
      _coach = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // A question handed over from another page ("Ask the coach") goes into the input field.
    ref.listen(coachDraftProvider, (_, q) {
      if (q == null) return;
      _input.value = TextEditingValue(text: q, selection: TextSelection.collapsed(offset: q.length));
      ref.read(coachDraftProvider.notifier).set(null);
    });
    final l = context.l10n;
    final suggestions = [l.coachQ1, l.coachQ2, l.coachQ3, l.coachQ4, l.coachQ5];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                  onPressed: () => showPlanGenerator(context, ref),
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: Text(l.generatePlan),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsPage())),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: Text(l.goals),
                ),
              ),
              if (_msgs.isNotEmpty)
                IconButton(
                  tooltip: l.newChat,
                  onPressed:
                      () => setState(() {
                        _msgs.clear();
                        _coach = null;
                      }),
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
        ),
        Expanded(
          child:
              _msgs.isEmpty
                  ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [AppColors.brand, AppColors.brand.withValues(alpha: 0.4)]),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 34),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.coachTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(l.coachSub, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 24),
                      for (final q in suggestions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(14)),
                            onPressed: () => _send(q),
                            child: Text(q),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        l.coachDisclaimer,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  )
                  : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _msgs.length,
                    itemBuilder: (_, i) => _Bubble(msg: _msgs[i], typing: _busy && i == _msgs.length - 1),
                  ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(hintText: l.askCoach),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _busy ? null : () => _send(_input.text), icon: const Icon(Icons.arrow_upward_rounded)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, required this.typing});
  final _Msg msg;
  final bool typing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: msg.user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.user ? AppColors.brand : (msg.error ? AppColors.danger.withValues(alpha: 0.15) : scheme.surfaceContainer),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(msg.user ? 18 : 4),
            bottomRight: Radius.circular(msg.user ? 4 : 18),
          ),
        ),
        child:
            msg.text.isEmpty && typing
                ? const SizedBox(width: 36, height: 18, child: LinearProgressIndicator())
                : _RichText(text: msg.text, color: msg.user ? Colors.white : null),
      ),
    );
  }
}

/// Minimal markdown: **bold**, bullet lines.
class _RichText extends StatelessWidget {
  const _RichText({required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(color: color, height: 1.4, fontSize: 14);
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final raw in lines)
          Builder(
            builder: (_) {
              var line = raw;
              var bullet = false;
              final m = RegExp(r'^\s*([*\-•]|\d+\.)\s+').firstMatch(line);
              if (m != null) {
                bullet = true;
                line = line.substring(m.end);
              }
              final heading = line.startsWith('#');
              if (heading) line = line.replaceFirst(RegExp(r'^#+\s*'), '');
              final spans = <TextSpan>[];
              final parts = line.split('**');
              for (var i = 0; i < parts.length; i++) {
                spans.add(TextSpan(text: parts[i], style: i.isOdd || heading ? const TextStyle(fontWeight: FontWeight.w700) : null));
              }
              final rt = RichText(text: TextSpan(style: base, children: spans));
              return Padding(
                padding: EdgeInsets.only(left: bullet ? 6 : 0, bottom: line.isEmpty ? 4 : 0),
                child:
                    bullet
                        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('•  ', style: base), Expanded(child: rt)])
                        : rt,
              );
            },
          ),
      ],
    );
  }
}
