import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/form_dialog.dart';

const _medicineUnits = [
  MapEntry('L', 'Litre (L)'),
  MapEntry('ml', 'Millilitre (ml)'),
  MapEntry('kg', 'Kilogram (kg)'),
  MapEntry('g', 'Gram (g)'),
];

const _medicineCategories = [
  MapEntry('Antibiotic', 'Antibiotic'),
  MapEntry('Vitamin', 'Vitamin'),
  MapEntry('Vaccine', 'Vaccine'),
  MapEntry('Sanitizer', 'Sanitizer'),
];

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  final TextEditingController _search = TextEditingController();
  String _searchTerm = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async =>
      List<Map<String, dynamic>>.from(
          await ApiClient.instance.get('/medicines') as List);

  Future<void> _medicineForm(
    BuildContext context, {
    Map<String, dynamic>? medicine,
    required VoidCallback reload,
  }) async {
    var duplicate = false;
    final saved = await showFormDialog(
      context,
      title: medicine == null ? 'Add Medicine' : 'Edit Medicine',
      initial: medicine ?? {},
      fields: [
        FieldSpec('name', 'Medicine name', hint: 'e.g. Vitamin supplement'),
        FieldSpec('category', 'Category',
            type: FieldType.select, options: _medicineCategories),
        FieldSpec('unit', 'Unit',
            type: FieldType.select, options: _medicineUnits),
        FieldSpec(
          'min_alert_level',
          'Low-stock alert level',
          type: FieldType.number,
          required: false,
          validator: (value, _) =>
              decimalValueError(value, maxDecimalPlaces: 3),
        ),
      ],
      onSubmit: (values) async {
        final body = {
          'name': values['name'],
          'category': values['category'],
          'unit': values['unit'],
          'min_alert_level':
              double.tryParse(values['min_alert_level'] ?? '') ?? 0,
        };
        if (medicine == null) {
          final result = await ApiClient.instance.post('/medicines', body);
          duplicate = result is Map && result['duplicate'] == true;
        } else {
          await ApiClient.instance.put('/medicines/${medicine['id']}', body);
        }
      },
    );
    if (saved && context.mounted) {
      reload();
      toast(
        context,
        duplicate
            ? 'Product already exists. Stock will be added to existing item.'
            : medicine == null
                ? 'Medicine added'
                : 'Medicine updated',
      );
    }
  }

  Future<void> _deleteMedicine(
    BuildContext context,
    Map<String, dynamic> medicine, {
    required VoidCallback reload,
  }) async {
    if (!await confirmDelete(context, 'medicine "${medicine['name']}"')) return;
    try {
      await ApiClient.instance.delete('/medicines/${medicine['id']}');
      if (context.mounted) {
        reload();
        toast(context, 'Medicine deleted');
      }
    } catch (error) {
      if (context.mounted) toast(context, '$error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => DataLoader<List<Map<String, dynamic>>>(
        load: _load,
        builder: (context, medicines, reload) {
          final needle = _searchTerm.trim().toLowerCase();
          final visibleMedicines = medicines.where((medicine) =>
              '${medicine['name']} ${medicine['category']} ${medicine['unit']} ${medicine['batch_numbers']}'
                  .toLowerCase()
                  .contains(needle));

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _search,
                onChanged: (value) => setState(() => _searchTerm = value),
                decoration: dec(
                  context,
                  'Search medicines, batches and categories',
                  icon: Icons.search,
                ).copyWith(
                  suffixIcon: _searchTerm.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() => _searchTerm = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageHeader(
                    title: 'Medicines & Health · औषधे व लस',
                    subtitle:
                        'Medicine stock, expiry alerts and flock treatment',
                    actions: [
                      FilledButton.icon(
                        onPressed: () => _medicineForm(context, reload: reload),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Medicine'),
                      ),
                    ],
                  ),
                  if (visibleMedicines.isEmpty && needle.isNotEmpty)
                    const EmptyState(
                      icon: Icons.search_off,
                      text: 'No medicines match your search.',
                    )
                  else if (medicines.isEmpty)
                    const EmptyState(
                      icon: Icons.medication_outlined,
                      text:
                          'No medicines added yet. Add a medicine to begin tracking stock.',
                    )
                  else
                    LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 900
                          ? 3
                          : constraints.maxWidth >= 580
                              ? 2
                              : 1;
                      final width =
                          (constraints.maxWidth - 14 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          for (final medicine in visibleMedicines)
                            SizedBox(
                              width: width,
                              child: _MedicineCard(
                                medicine: medicine,
                                onOpen: () => context.push(
                                  '/medicines/${medicine['id']}',
                                  extra: {
                                    'name': '${medicine['name']}',
                                    'unit': '${medicine['unit']}',
                                  },
                                ),
                                onEdit: () => _medicineForm(
                                  context,
                                  medicine: medicine,
                                  reload: reload,
                                ),
                                onDelete: () => _deleteMedicine(
                                  context,
                                  medicine,
                                  reload: reload,
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                ],
              ),
            ),
          ]);
        },
      );
}

class _MedicineCard extends StatelessWidget {
  final Map<String, dynamic> medicine;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedicineCard({
    required this.medicine,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final stock = asD(medicine['current_stock']);
    final purchased = asD(medicine['total_purchased']);
    final consumed = asD(medicine['total_consumed']);
    final low = stock <= asD(medicine['min_alert_level']);
    final expiryValue = medicine['nearest_expiry'] ?? medicine['expiry'];
    final expiry = DateTime.tryParse('$expiryValue');
    final daysLeft = expiry?.difference(DateTime.now()).inDays;
    final expired = daysLeft != null && daysLeft < 0;
    final nearExpiry = daysLeft != null && daysLeft >= 0 && daysLeft <= 60;
    final warning = low || expired || nearExpiry;
    final color =
        warning ? Theme.of(context).colorScheme.error : AppColors.primary;
    final unit = '${medicine['unit']}';
    final secondary = switch (unit) {
      'L' => '≈ ${qty(stock * 1000)} ml live stock',
      'kg' => '≈ ${qty(stock * 1000)} g live stock',
      'ml' => '≈ ${qty(stock / 1000)} L live stock',
      'g' => '≈ ${qty(stock / 1000)} kg live stock',
      _ => '≈ ${qty(stock)} $unit live stock',
    };
    final progress = purchased <= 0 ? 0.0 : (stock / purchased).clamp(0.0, 1.0);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          onTap: onOpen,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: .12),
                child: const Icon(Icons.medication_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${medicine['name']}',
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('${medicine['category']}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
        InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${qty(stock)} $unit in stock',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: color),
                ),
                Text(
                  secondary,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).hintColor),
                ),
                if (low || expired || nearExpiry) ...[
                  const SizedBox(height: 4),
                  Text(
                    low
                        ? 'Low stock · alert at ${qty(medicine['min_alert_level'])} $unit'
                        : expired
                            ? 'Expired · ${fmtDate(expiryValue)}'
                            : 'Expiring soon · ${fmtDate(expiryValue)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: progress,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: .2),
                    color: color,
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _MedicineMetric(
                      label: 'Purchased / आवक',
                      value: '${qty(purchased)} $unit',
                    ),
                  ),
                  Expanded(
                    child: _MedicineMetric(
                      label: 'Consumed / वापर',
                      value: '${qty(consumed)} $unit',
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            const Spacer(),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit name'),
            ),
            IconButton(
              tooltip: 'Delete medicine',
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _MedicineMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MedicineMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      );
}
