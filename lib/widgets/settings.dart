import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// One settings style for the profile and every settings-like list: a section header and a
/// card of equal rows (tinted icon, title, a short subtitle of at most two lines, an optional
/// ⓘ for the long explanation and a trailing value / switch / chevron in one size).

/// Section header + card holding [children] (usually [SettingsTile]s), with inset dividers.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) SettingsHeader(title!) else const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(height: 1, indent: 66, endIndent: 16), children[i]],
            ],
          ),
        ),
      ],
    );
  }
}

/// The header above a settings card.
class SettingsHeader extends StatelessWidget {
  const SettingsHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.brand, fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

/// One settings row. [value] is a current setting shown at the end in the title's size
/// (time, unit, language); [trailing] a control (switch). [info] adds an ⓘ next to the title
/// that opens the long explanation. Tappable rows ([onTap]) without a control get a chevron
/// unless [chevron] is false.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.info,
    this.iconColor,
    this.danger = false,
    this.chevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? info;
  final Color? iconColor;
  final bool danger;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final tint = danger ? AppColors.danger : (iconColor ?? scheme.primary);
    final titleStyle = text.bodyLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w500, color: danger ? AppColors.danger : null);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, trailing != null ? 8 : 12, 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: tint),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The ⓘ follows the title's last word (also when the title wraps).
                    Text.rich(
                      TextSpan(
                        text: title,
                        children: [
                          if (info != null)
                            WidgetSpan(alignment: PlaceholderAlignment.middle, child: _InfoButton(title: title, body: info!)),
                        ],
                      ),
                      style: titleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    value!,
                    style: titleStyle?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (trailing == null && onTap != null && chevron) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A [SettingsTile] with a switch; the whole row toggles it.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.info,
    this.iconColor,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? info;
  final Color? iconColor;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      info: info,
      iconColor: iconColor,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    ),
  );
}

/// A row with the current choice as its value; tapping opens [showSettingsChoice].
class SettingsChoiceTile<T> extends StatelessWidget {
  const SettingsChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Value → label, in display order.
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SettingsTile(
    icon: icon,
    title: title,
    subtitle: subtitle,
    value: options[selected],
    onTap: () async {
      final (picked, chosen) = await showSettingsChoice<T>(context, title: title, options: options, selected: selected);
      if (picked && chosen != selected) onChanged(chosen as T);
    },
  );
}

/// A sheet listing [options] with the [selected] one checked. Returns (picked, value) – the
/// value may be null as an option (e.g. "System").
Future<(bool, T?)> showSettingsChoice<T>(
  BuildContext context, {
  required String title,
  required Map<T, String> options,
  required T selected,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final r = await showModalBottomSheet<(T?,)>(
    context: context,
    builder:
        (c) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(title, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                for (final e in options.entries)
                  ListTile(
                    title: Text(e.value),
                    selected: e.key == selected,
                    trailing: e.key == selected ? Icon(Icons.check_rounded, color: scheme.primary) : null,
                    onTap: () => Navigator.pop(c, (e.key,)),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
  );
  return r == null ? (false, null) : (true, r.$1);
}

/// Bottom sheet with the long explanation of a setting.
Future<void> showSettingInfo(BuildContext context, String title, String body) {
  final t = Theme.of(context).textTheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder:
        (c) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(body, style: t.bodyLarge?.copyWith(height: 1.45)),
              ],
            ),
          ),
        ),
  );
}

class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.infoAbout(title),
    child: InkResponse(
      onTap: () => showSettingInfo(context, title, body),
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(Icons.info_outline_rounded, size: 18, color: Theme.of(context).colorScheme.outline),
      ),
    ),
  );
}
