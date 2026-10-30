import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/auth_state.dart';
import '../widgets/common.dart';
import '../widgets/form_dialog.dart';

class EggsScreen extends StatefulWidget {
  const EggsScreen({super.key});

  @override
  State<EggsScreen> createState() => _EggsScreenState();
}

class _EggsScreenState extends State<EggsScreen> {
  late DateTime _selectedDate;
  bool _wholeMonth = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  Future<Map<String, dynamic>> _load() async {
    final api = ApiClient.instance;
    final month = DateFormat('yyyy-MM').format(_selectedDate);
    final dailyQuery = _wholeMonth
        ? <String, String>{'month': month}
        : <String, String>{
            'date': DateFormat('yyyy-MM-dd').format(_selectedDate)
          };
    final r = await Future.wait([
      api.get('/eggs/summary', query: {'today': today()}),
      api.get('/eggs', query: dailyQuery),
      api.get('/flock/batches'),
      api.get('/eggs/monthly', query: {'month': month}),
    ]);
    return {
      'summary': Map<String, dynamic>.from(r[0] as Map),
      'rows': List<Map<String, dynamic>>.from(r[1] as List),
      'batches': List<Map<String, dynamic>>.from(r[2] as List),
      'monthly': Map<String, dynamic>.from(r[3] as Map),
    };
  }

  Future<void> _form(
    BuildContext context,
    List<Map<String, dynamic>> batches,
    int configuredEggsPerTray, {
    Map<String, dynamic>? e,
    required VoidCallback reload,
  }) async {
    final api = ApiClient.instance;
    DateTime? savedDate;
    int numberOrZero(String? value) => int.tryParse((value ?? '').trim()) ?? 0;
    final eggsPerTray = e == null
        ? configuredEggsPerTray
        : int.tryParse('${e['eggs_per_tray_used']}') ?? configuredEggsPerTray;
    final ok = await showFormDialog(
      context,
      title: e == null ? 'Egg collection' : 'Edit collection',
      initial: {
        ...?e,
        if (e != null && e['batch_id'] == null) 'batch_id': '',
      },
      fields: [
        const FieldSpec('collection_date', 'Date', type: FieldType.date),
        FieldSpec('batch_id', 'Flock batch',
            type: FieldType.select,
            required: false,
            options: [
              const MapEntry('', 'All / not specified'),
              for (final b in batches)
                MapEntry('${b['id']}', '${b['batch_name']}'),
            ]),
        const FieldSpec(
          'trays_count',
          'Trays collected',
          type: FieldType.integer,
          required: false,
          hint: '0',
          clearZeroOnFocus: true,
          normalizeLeadingZeros: true,
        ),
        const FieldSpec(
          'loose_eggs',
          'Loose / Extra eggs',
          type: FieldType.integer,
          required: false,
          hint: '0',
          clearZeroOnFocus: true,
          normalizeLeadingZeros: true,
        ),
        FieldSpec(
          'damaged_eggs',
          'Damaged / Broken eggs',
          type: FieldType.integer,
          required: false,
          hint: '0',
          clearZeroOnFocus: true,
          normalizeLeadingZeros: true,
          validator: (value, values) {
            final damaged = numberOrZero(value);
            final trays = numberOrZero(values['trays_count']);
            final loose = numberOrZero(values['loose_eggs']);
            return damaged > trays * eggsPerTray + loose
                ? 'Cannot exceed total eggs'
                : null;
          },
        ),
      ],
      preview: (values) {
        final trays = numberOrZero(values['trays_count']);
        final loose = numberOrZero(values['loose_eggs']);
        final damaged = numberOrZero(values['damaged_eggs']);
        final total = trays * eggsPerTray + loose;
        final net = total - damaged;
        return 'Total Eggs: $total | Net Eggs: $net | Damaged: $damaged';
      },
      onSubmit: (v) async {
        savedDate = DateTime.parse(v['collection_date']!);
        final body = {
          'collection_date': v['collection_date'],
          'batch_id': v['batch_id']!.isEmpty ? null : int.parse(v['batch_id']!),
          'trays_count': numberOrZero(v['trays_count']),
          'loose_eggs': numberOrZero(v['loose_eggs']),
          'damaged_eggs': numberOrZero(v['damaged_eggs']),
        };
        if (e == null) {
          await api.post('/eggs', body);
        } else {
          await api.put('/eggs/${e['id']}', body);
        }
      },
    );
    if (ok && context.mounted) {
      setState(() {
        _selectedDate = savedDate!;
        _wholeMonth = false;
      });
      reload();
      toast(
          context,
          e == null
              ? 'Egg collection added successfully'
              : 'Egg collection updated successfully');
    }
  }

  Future<void> _pickDate(BuildContext context, VoidCallback reload) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Select egg collection date',
    );
    if (picked == null || !context.mounted) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _wholeMonth = false;
    });
    reload();
  }

  void _selectDate(DateTime date, VoidCallback reload) {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
      _wholeMonth = false;
    });
    reload();
  }

  @override
  Widget build(BuildContext context) {
    final configuredEggsPerTray =
        int.tryParse('${context.watch<AuthState>().user?['eggs_per_tray']}') ??
            30;
    return DataLoader<Map<String, dynamic>>(
      load: _load,
      builder: (context, data, reload) {
        final s = data['summary'] as Map<String, dynamic>;
        final rows = data['rows'] as List<Map<String, dynamic>>;
        final batches = data['batches'] as List<Map<String, dynamic>>;
        final monthly = data['monthly'] as Map<String, dynamic>;
        final t = Theme.of(context);
        return ListView(padding: const EdgeInsets.all(16), children: [
          PageHeader(
            title: 'Egg Production & Sales Matrix',
            subtitle:
                'Tray-based daily production tracking and available stock',
            actions: [
              FilledButton.icon(
                onPressed: () => _form(
                  context,
                  batches,
                  configuredEggsPerTray,
                  reload: reload,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add entry'),
              ),
            ],
          ),
          AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Eggs Produced', style: t.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(qty(s['all_time_eggs']),
                  style: t.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Chip(
                  avatar: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text('Net Good Eggs: ${qty(s['all_time_net'])}'),
                ),
                Chip(
                  avatar: Icon(Icons.broken_image_outlined,
                      size: 18, color: t.colorScheme.error),
                  label: Text('Damaged Eggs: ${qty(s['all_time_damaged'])}'),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Collection date',
                    style: t.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(context, reload),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label:
                          Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.today_outlined, size: 18),
                      label: const Text('Today'),
                      onPressed: () => _selectDate(DateTime.now(), reload),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.history_outlined, size: 18),
                      label: const Text('Yesterday'),
                      onPressed: () => _selectDate(
                        DateTime.now().subtract(const Duration(days: 1)),
                        reload,
                      ),
                    ),
                    FilterChip(
                      avatar: const Icon(Icons.calendar_view_month, size: 18),
                      label: const Text('View Whole Month'),
                      selected: _wholeMonth,
                      onSelected: (selected) {
                        setState(() => _wholeMonth = selected);
                        reload();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_wholeMonth) ...[
            const SizedBox(height: 12),
            _MonthSubtotal(month: monthly),
          ],
          const SizedBox(height: 16),
          if (rows.isEmpty)
            EmptyState(
                icon: Icons.egg_outlined,
                text: _wholeMonth
                    ? 'No egg collection records for ${DateFormat('MMMM yyyy').format(_selectedDate)}.'
                    : 'No egg collection recorded on ${DateFormat('dd MMM yyyy').format(_selectedDate)}. Click "+ Add entry" to log collection.')
          else
            for (final e in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('dd MMM yyyy').format(
                                  DateTime.parse('${e['collection_date']}')),
                              style: t.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _form(
                              context,
                              batches,
                              configuredEggsPerTray,
                              e: e,
                              reload: reload,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: Icon(Icons.delete_outline,
                                size: 20, color: t.colorScheme.error),
                            onPressed: () async {
                              if (!await confirmDelete(
                                  context, 'this egg record')) {
                                return;
                              }
                              try {
                                await ApiClient.instance
                                    .delete('/eggs/${e['id']}');
                                if (context.mounted) {
                                  toast(context,
                                      'Egg record deleted successfully');
                                }
                              } catch (err) {
                                if (context.mounted) {
                                  toast(context, '$err', error: true);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      Text(
                        '${qty(e['trays_count'])} trays + ${qty(e['loose_eggs'])} loose',
                        style: t.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _EggMetric(
                              label: 'Total collected',
                              value: qty(e['total_eggs'])),
                          _EggMetric(
                            label: 'Damaged',
                            value: qty(e['damaged_eggs']),
                            damaged: true,
                          ),
                          _EggMetric(
                            label: 'Net saleable',
                            value: qty(e['net_eggs']),
                            prominent: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ]);
      },
    );
  }
}

class _EggMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool damaged;
  final bool prominent;

  const _EggMetric({
    required this.label,
    required this.value,
    this.damaged = false,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = damaged ? theme.colorScheme.error : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: damaged
            ? color.withValues(alpha: .10)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: damaged ? color : null),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: damaged ? color : null,
                fontWeight: prominent ? FontWeight.w800 : FontWeight.w600,
                fontSize: prominent ? 16 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthSubtotal extends StatelessWidget {
  final Map<String, dynamic> month;

  const _MonthSubtotal({required this.month});

  @override
  Widget build(BuildContext context) {
    final label =
        DateFormat('MMMM yyyy').format(DateTime.parse('${month['month']}-01'));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label subtotal',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('Trays: ${qty(month['trays_count'])}'),
              Text('Total: ${qty(month['total_eggs'])}'),
              Text('Damaged: ${qty(month['damaged_eggs'])}'),
              Text('Net: ${qty(month['net_eggs'])}'),
            ],
          ),
        ],
      ),
    );
  }
}
