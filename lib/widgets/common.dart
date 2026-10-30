import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/config.dart';

double asD(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);
int asI(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);

final NumberFormat _nf = NumberFormat.decimalPattern('en_IN')..maximumFractionDigits = 2;
String qty(dynamic v) => _nf.format(asD(v));
String money(dynamic v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: kCurrencySymbol, decimalDigits: 2).format(asD(v));
String today() => DateFormat('yyyy-MM-dd').format(DateTime.now());
String fmtDate(dynamic s) {
  try {
    return DateFormat('dd MMM yyyy').format(DateTime.parse('$s'));
  } catch (_) {
    return '$s';
  }
}

InputDecoration dec(BuildContext c, String label, {String? hint, IconData? icon, String? prefix}) {
  final cs = Theme.of(c).colorScheme;
  OutlineInputBorder b(Color col, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: col, width: w));
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    prefixText: prefix,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: b(cs.outline),
    enabledBorder: b(cs.outline),
    focusedBorder: b(cs.primary, 1.6),
    errorBorder: b(cs.error),
    focusedErrorBorder: b(cs.error, 1.6),
  );
}

void toast(BuildContext c, String m, {bool error = false}) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: error ? Theme.of(c).colorScheme.error : null,
    ));
}

Future<bool> confirmDelete(BuildContext c, String what) async {
  final r = await showDialog<bool>(
    context: c,
    useRootNavigator: true,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete?'),
      content: Text('This will permanently delete $what.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
          onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return r == true;
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: child,
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final String? sub;
  final Color? color;
  const StatCard({super.key, required this.icon, required this.label, required this.value, this.sub, this.color});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = color ?? t.colorScheme.primary;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: t.textTheme.bodySmall?.copyWith(color: t.hintColor), maxLines: 2)),
        ]),
        const SizedBox(height: 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: t.textTheme.headlineSmall),
        ),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub!, style: t.textTheme.bodySmall?.copyWith(color: c, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.textTheme.headlineSmall),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!, style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor)),
              ),
          ]),
        ),
        Wrap(spacing: 8, children: actions),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(children: [
          Icon(icon, size: 40, color: t.hintColor),
          const SizedBox(height: 10),
          Text(text, style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

/// Loads data once, shows spinner / error+retry, and hands a reload callback to the builder.
class DataLoader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) builder;
  const DataLoader({super.key, required this.load, required this.builder});
  @override
  State<DataLoader<T>> createState() => _DataLoaderState<T>();
}

class _DataLoaderState<T> extends State<DataLoader<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    ApiClient.instance.mutationVersion.addListener(_onMutation);
    _reload();
  }

  @override
  void dispose() {
    ApiClient.instance.mutationVersion.removeListener(_onMutation);
    super.dispose();
  }

  void _onMutation() => _reload();

  Future<void> _reload() async {
    final requestId = ++_requestId;
    if (_data == null && mounted) setState(() => _loading = true);
    try {
      final result = await widget.load();
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _data = result;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error;
        _loading = false;
      });
      if (_data != null) toast(context, '$error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data != null) return widget.builder(context, _data as T, _reload);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined, size: 40),
        const SizedBox(height: 8),
        Text('$_error', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ]),
    );
  }
}

class FarmAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;
  const FarmAvatar({super.key, this.url, required this.name, this.radius = 20});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final full = (url == null || url!.isEmpty) ? null : (url!.startsWith('http') ? url! : '$kApiBase$url');
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: cs.primary.withOpacity(.14),
      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: radius * .8)),
    );
    if (full == null) return fallback;
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Image.network(
          full,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Stack(fit: StackFit.expand, children: [
              fallback,
              Center(
                child: SizedBox(
                  width: radius,
                  height: radius,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.expectedTotalBytes == null
                        ? null
                        : progress.cumulativeBytesLoaded / progress.expectedTotalBytes!,
                  ),
                ),
              ),
            ]);
          },
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

class DatePickerField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const DatePickerField({super.key, required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: DateTime.tryParse(value) ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null) onChanged(DateFormat('yyyy-MM-dd').format(d));
        },
        child: InputDecorator(
          decoration: dec(context, label, icon: Icons.calendar_today_outlined),
          child: Text(fmtDate(value)),
        ),
      );
}
