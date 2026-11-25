import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/form_dialog.dart';

class FlockScreen extends StatefulWidget {
  const FlockScreen({super.key});
  @override
  State<FlockScreen> createState() => _FlockScreenState();
}

class _FlockScreenState extends State<FlockScreen> {
  final api = ApiClient.instance;
  int tab = 0;

  Future<Map<String, List<Map<String, dynamic>>>> _load() async {
    final r = await Future.wait(
        [api.get('/flock/batches'), api.get('/flock/mortality')]);
    return {
      'batches': List<Map<String, dynamic>>.from(r[0] as List),
      'mortality': List<Map<String, dynamic>>.from(r[1] as List),
    };
  }

  Future<void> _batchForm(VoidCallback reload,
      {Map<String, dynamic>? b}) async {
    final ok = await showFormDialog(
      context,
      title: b == null ? 'New bird batch' : 'Edit batch',
      initial: b ?? {},
      fields: const [
        FieldSpec('batch_name', 'Batch name',
            hint: 'e.g. Layer batch Oct-2026'),
        FieldSpec('arrival_date', 'Arrival date', type: FieldType.date),
        FieldSpec('quantity', 'Quantity of birds purchased',
            type: FieldType.integer),
        FieldSpec('unit_price', 'Unit purchase price', type: FieldType.number),
        FieldSpec('notes', 'Notes', type: FieldType.multiline, required: false),
      ],
      preview: (v) =>
          'Total batch cost: ${money(asD(v['quantity']) * asD(v['unit_price']))}',
      onSubmit: (v) async {
        final body = {
          'batch_name': v['batch_name'],
          'arrival_date': v['arrival_date'],
          'quantity': int.parse(v['quantity']!),
          'unit_price': double.parse(v['unit_price']!),
          'notes': v['notes'],
        };
        if (b == null) {
          await api.post('/flock/batches', body);
        } else {
          await api.put('/flock/batches/${b['id']}', body);
        }
      },
    );
    if (ok && mounted)
      toast(
          context,
          b == null
              ? 'Bird batch added successfully'
              : 'Bird batch updated successfully');
  }

  Future<void> _mortalityForm(
      VoidCallback reload, List<Map<String, dynamic>> batches,
      {Map<String, dynamic>? m}) async {
    if (batches.isEmpty) {
      toast(context, 'Add a bird batch first', error: true);
      return;
    }
    final ok = await showFormDialog(
      context,
      title: m == null ? 'Log mortality' : 'Edit mortality log',
      initial: m ?? {},
      fields: [
        FieldSpec('batch_id', 'Flock batch', type: FieldType.select, options: [
          for (final b in batches)
            MapEntry('${b['id']}',
                '${b['batch_name']} (${qty(b['active_birds'])} live)')
        ]),
        const FieldSpec('log_date', 'Date', type: FieldType.date),
        const FieldSpec('dead_count', 'Dead birds', type: FieldType.integer),
        const FieldSpec('cause', 'Cause / notes',
            type: FieldType.multiline, required: false),
      ],
      onSubmit: (v) async {
        final body = {
          'batch_id': v['batch_id']!,
          'log_date': v['log_date'],
          'dead_count': int.parse(v['dead_count']!),
          'cause': v['cause'],
        };
        if (m == null) {
          await api.post('/flock/mortality', body);
        } else {
          await api.put('/flock/mortality/${m['id']}', body);
        }
      },
    );
    if (ok && mounted)
      toast(
          context,
          m == null
              ? 'Mortality record added successfully'
              : 'Mortality record updated successfully');
  }

  Future<void> _delete(String path, String what, VoidCallback reload) async {
    if (!await confirmDelete(context, what)) return;
    try {
      await api.delete(path);
      if (mounted) toast(context, 'Record deleted successfully');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DataLoader<Map<String, List<Map<String, dynamic>>>>(
      load: _load,
      builder: (context, data, reload) {
        final batches = data['batches']!;
        final mortality = data['mortality']!;
        final t = Theme.of(context);
        final rows = tab == 0 ? batches : mortality;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 3 + (rows.isEmpty ? 1 : rows.length),
          itemBuilder: (context, index) {
            if (index == 0) {
              return PageHeader(
                title: 'Flock & Mortality',
                subtitle:
                    '${qty(batches.fold<double>(0, (s, b) => s + asD(b['active_birds'])))} live birds across ${batches.length} batches',
                actions: [
                  FilledButton.icon(
                    onPressed: () => tab == 0
                        ? _batchForm(reload)
                        : _mortalityForm(reload, batches),
                    icon: const Icon(Icons.add),
                    label: Text(tab == 0 ? 'New batch' : 'Log mortality'),
                  ),
                ],
              );
            }
            if (index == 1) {
              return SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                      value: 0, label: Text('Batches'), icon: Icon(Icons.pets)),
                  ButtonSegment(
                      value: 1,
                      label: Text('Mortality'),
                      icon: Icon(Icons.heart_broken_outlined)),
                ],
                selected: {tab},
                onSelectionChanged: (s) => setState(() => tab = s.first),
              );
            }
            if (index == 2) return const SizedBox(height: 14);
            final rowIndex = index - 3;
            if (rows.isEmpty) {
              return EmptyState(
                icon: tab == 0 ? Icons.pets_outlined : Icons.favorite_outline,
                text: tab == 0
                    ? 'No batches yet. Add your first bird batch.'
                    : 'No mortality recorded. Great!',
              );
            }
            final row = rows[rowIndex];
            if (tab == 0) {
              final batch = row;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text('${batch['batch_name']}',
                                  style: t.textTheme.titleMedium)),
                          IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _batchForm(reload, b: batch)),
                          IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 20, color: t.colorScheme.error),
                              onPressed: () => _delete(
                                  '/flock/batches/${batch['id']}',
                                  'batch "${batch['batch_name']}" and its mortality logs',
                                  reload)),
                        ]),
                        Text('Arrived ${fmtDate(batch['arrival_date'])}',
                            style: t.textTheme.bodySmall
                                ?.copyWith(color: t.hintColor)),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          Pill('Purchased ${qty(batch['quantity'])}',
                              AppColors.info),
                          Pill('Dead ${qty(batch['total_mortality'])}',
                              AppColors.danger),
                          Pill('Live ${qty(batch['active_birds'])}',
                              AppColors.primary),
                          Pill('@ ${money(batch['unit_price'])}',
                              AppColors.yolk),
                        ]),
                        const SizedBox(height: 10),
                        Text('Total batch cost: ${money(batch['total_cost'])}',
                            style: t.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        if ('${batch['notes'] ?? ''}'.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('${batch['notes']}',
                                  style: t.textTheme.bodySmall)),
                      ]),
                ),
              );
            }
            final log = row;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: AppColors.danger.withOpacity(.12),
                    child: Text('${log['dead_count']}',
                        style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${log['batch_name']}',
                              style: t.textTheme.titleMedium),
                          Text(
                              '${fmtDate(log['log_date'])}${'${log['cause'] ?? ''}'.isEmpty ? '' : '  •  ${log['cause']}'}',
                              style: t.textTheme.bodySmall
                                  ?.copyWith(color: t.hintColor)),
                        ]),
                  ),
                  IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _mortalityForm(reload, batches, m: log)),
                  IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 20, color: t.colorScheme.error),
                      onPressed: () => _delete('/flock/mortality/${log['id']}',
                          'this mortality log', reload)),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}
