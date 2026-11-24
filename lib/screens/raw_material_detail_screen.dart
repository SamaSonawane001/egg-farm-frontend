import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/form_dialog.dart';

class RawMaterialDetailScreen extends StatefulWidget {
  final String materialId;
  final String? materialName;
  final String? unit;

  const RawMaterialDetailScreen({
    super.key,
    required this.materialId,
    this.materialName,
    this.unit,
  });

  @override
  State<RawMaterialDetailScreen> createState() =>
      _RawMaterialDetailScreenState();
}

class _RawMaterialDetailScreenState extends State<RawMaterialDetailScreen> {
  String _month = DateTime.now().toIso8601String().substring(0, 7);
  int _tab = 0;
  static const _stockUnits = [
    MapEntry('kg', 'Kilogram (kg)'),
    MapEntry('quintal', 'Quintal'),
    MapEntry('bags', 'Bags'),
  ];

  double _toKg(double quantity, String unit, double kgPerBag) => switch (unit) {
        'quintal' => quantity * 100,
        'bags' => quantity * kgPerBag,
        _ => quantity,
      };

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait([
      ApiClient.instance.get(
        '/raw-materials/${widget.materialId}',
        query: {'month': _month},
      ),
      ApiClient.instance.get('/feed/stock'),
    ]);
    final result = results[0] as Map;
    return {
      'material': Map<String, dynamic>.from(result['material'] as Map),
      'transactions':
          List<Map<String, dynamic>>.from(result['transactions'] as List),
      'kgPerBag': asD((results[1] as Map)['kg_per_bag']),
    };
  }

  Future<void> _inwardForm(
    Map<String, dynamic> material,
    double kgPerBag,
    VoidCallback reload,
  ) async {
    final saved = await showFormDialog(
      context,
      title: 'Add Inward Stock · आवक · ${material['name']}',
      initial: {'kg_per_bag': kgPerBag},
      fields: [
        const FieldSpec(
          'quantity',
          'Quantity received',
          type: FieldType.number,
          validator: _positiveQuantityValidator,
        ),
        const FieldSpec(
          'unit',
          'Unit',
          type: FieldType.select,
          options: _stockUnits,
        ),
        const FieldSpec('date', 'Received on', type: FieldType.date),
        const FieldSpec(
          'vendor_name',
          'Supplier / vendor',
          required: false,
        ),
        const FieldSpec('bill_number', 'Bill number', required: false),
        FieldSpec(
          'kg_per_bag',
          'Bag weight in kg',
          type: FieldType.number,
          readOnly: true,
          visibleWhen: (values) => values['unit'] == 'bags',
        ),
        const FieldSpec(
          'rate_per_unit',
          'Rate per 1 kg (₹)',
          type: FieldType.number,
          validator: _rateValidator,
          labelForValues: _rateLabel,
        ),
        const FieldSpec(
          'remarks',
          'Notes',
          type: FieldType.multiline,
          required: false,
        ),
      ],
      preview: (values) =>
          'Total amount: ${money(asD(values['quantity']) * asD(values['rate_per_unit']))} · Stock added: ${qty(_toKg(asD(values['quantity']), values['unit'] ?? 'kg', kgPerBag))} kg',
      onSubmit: (values) async {
        final quantity = double.parse(values['quantity']!);
        final rate = double.parse(values['rate_per_unit']!);
        await ApiClient.instance.post('/raw-materials/inward', {
          'material_id': widget.materialId,
          'quantity': quantity,
          'unit': values['unit'],
          'date': values['date'],
          'supplier': values['vendor_name'],
          'vendor_name': values['vendor_name'],
          'bill_number': values['bill_number'],
          'rate_per_unit': rate,
          'total_amount': double.parse((quantity * rate).toStringAsFixed(2)),
          'kg_per_bag': asD(values['kg_per_bag']) > 0
              ? asD(values['kg_per_bag'])
              : kgPerBag,
          'remarks': values['remarks'],
        });
      },
    );
    if (saved && mounted) {
      reload();
      toast(context, 'Inward stock recorded');
    }
  }

  Future<void> _processingForm(
    Map<String, dynamic> material,
    double kgPerBag,
    VoidCallback reload,
  ) async {
    final availableKg = asD(material['current_stock']);
    final saved = await showFormDialog(
      context,
      title: 'Grind & Mix / दळण-वापर · ${material['name']}',
      fields: [
        const FieldSpec('date', 'Processing date', type: FieldType.date),
        FieldSpec(
          'quantity',
          'Consumed quantity / दळण केलेले प्रमाण',
          type: FieldType.number,
          validator: (value, values) {
            final invalid = decimalValueError(
              value,
              maxDecimalPlaces: 3,
              mustBePositive: true,
            );
            if (invalid != null) return invalid;
            final amount = double.tryParse(value ?? '');
            if (amount != null &&
                _toKg(amount, values['unit'] ?? 'kg', kgPerBag) >
                    availableKg + 0.0005) {
              return 'Only ${qty(availableKg)} kg available';
            }
            return null;
          },
        ),
        const FieldSpec(
          'unit',
          'Unit',
          type: FieldType.select,
          options: _stockUnits,
        ),
        const FieldSpec(
          'remarks',
          'Notes / Shed (optional)',
          type: FieldType.multiline,
          required: false,
        ),
      ],
      preview: (values) =>
          'Available: ${qty(availableKg)} kg (${qty(availableKg / 100)} quintals) · Finished feed product: ${material['name']}',
      onSubmit: (values) async {
        await ApiClient.instance.post('/raw-materials/processing', {
          'date': values['date'],
          'material_id': widget.materialId,
          'quantity': double.parse(values['quantity']!),
          'unit': values['unit'],
          'remarks': values['remarks'],
        });
      },
    );
    if (saved && mounted) {
      reload();
      toast(context, 'Feed processing recorded');
    }
  }

  Future<void> _editTransaction(
    Map<String, dynamic> transaction,
    double kgPerBag,
    VoidCallback reload,
  ) async {
    final isInward = transaction['transaction_type'] == 'INWARD';
    final enteredUnit = '${transaction['entered_unit'] ?? 'kg'}';
    final quantity =
        asD(transaction['entered_quantity'] ?? transaction['quantity']);
    final saved = await showFormDialog(
      context,
      title: isInward ? 'Edit inward stock · आवक' : 'Edit usage · दळण',
      initial: {
        'date': '${transaction['transaction_date']}'.substring(0, 10),
        'quantity': quantity.toString(),
        'unit': enteredUnit,
        'supplier':
            '${transaction['supplier'] ?? transaction['vendor_name'] ?? ''}',
        'vendor_name':
            '${transaction['vendor_name'] ?? transaction['supplier'] ?? ''}',
        'rate_per_unit': '${transaction['rate_per_unit'] ?? 0}',
        'kg_per_bag': '${transaction['entered_kg_per_unit'] ?? kgPerBag}',
        'remarks': '${transaction['remarks'] ?? ''}',
      },
      fields: [
        const FieldSpec('date', 'Date', type: FieldType.date),
        const FieldSpec('quantity', 'Quantity',
            type: FieldType.number, validator: _positiveQuantityValidator),
        const FieldSpec('unit', 'Unit',
            type: FieldType.select, options: _stockUnits),
        if (isInward) ...[
          const FieldSpec('vendor_name', 'Supplier / notes', required: false),
          FieldSpec(
            'kg_per_bag',
            'Bag weight in kg',
            type: FieldType.number,
            readOnly: true,
            visibleWhen: (values) => values['unit'] == 'bags',
          ),
          FieldSpec(
            'rate_per_unit',
            'Rate per 1 kg (₹)',
            type: FieldType.number,
            validator: _rateValidator,
            labelForValues: _rateLabel,
          ),
        ],
        const FieldSpec('remarks', 'Notes',
            type: FieldType.multiline, required: false),
      ],
      onSubmit: (values) async {
        final body = <String, dynamic>{
          'date': values['date'],
          'quantity': double.parse(values['quantity']!),
          'unit': values['unit'],
          'remarks': values['remarks'],
        };
        if (isInward) {
          final quantityValue = double.parse(values['quantity']!);
          final rate = double.parse(values['rate_per_unit'] ?? '0');
          body.addAll({
            'supplier': values['vendor_name'],
            'vendor_name': values['vendor_name'],
            'rate_per_unit': rate,
            'total_amount':
                double.parse((quantityValue * rate).toStringAsFixed(2)),
            'kg_per_bag': asD(values['kg_per_bag']) > 0
                ? asD(values['kg_per_bag'])
                : kgPerBag,
          });
          await ApiClient.instance
              .put('/raw-materials/inward/${transaction['id']}', body);
        } else {
          await ApiClient.instance
              .put('/raw-materials/usage/${transaction['id']}', body);
        }
      },
    );
    if (saved && mounted) {
      reload();
      toast(context, 'Raw material entry updated');
    }
  }

  Future<void> _deleteTransaction(
      Map<String, dynamic> transaction, VoidCallback reload) async {
    final isInward = transaction['transaction_type'] == 'INWARD';
    if (!await confirmDelete(
        context,
        isInward
            ? 'this inward stock entry'
            : 'this usage record${transaction['processing_id'] == null ? '' : ' and its feed mix batch'}')) {
      return;
    }
    try {
      await ApiClient.instance.delete(
        isInward
            ? '/raw-materials/inward/${transaction['id']}'
            : '/raw-materials/usage/${transaction['id']}',
      );
      if (mounted) {
        reload();
        toast(context, 'Raw material entry deleted');
      }
    } catch (error) {
      if (mounted) toast(context, '$error', error: true);
    }
  }

  static String? _positiveQuantityValidator(
    String? value,
    Map<String, String> _,
  ) =>
      decimalValueError(
        value,
        maxDecimalPlaces: 3,
        mustBePositive: true,
      );

  static String? _rateValidator(String? value, Map<String, String> _) =>
      decimalValueError(value, maxDecimalPlaces: 3);

  static String _rateLabel(Map<String, String> values) =>
      switch (values['unit']) {
        'quintal' => 'Rate per 1 Quintal (₹)',
        'bags' => 'Rate per 1 Bag (₹)',
        _ => 'Rate per 1 kg (₹)',
      };

  Future<void> _selectMonth() async {
    final current = DateTime.tryParse('$_month-01') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Choose a date in the month to view',
    );
    if (picked != null) {
      setState(() {
        _month =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) => DataLoader<Map<String, dynamic>>(
        key: ValueKey('${widget.materialId}-$_month'),
        load: _load,
        builder: (context, data, reload) {
          final material = data['material'] as Map<String, dynamic>;
          final transactions =
              data['transactions'] as List<Map<String, dynamic>>;
          final unit = '${material['unit'] ?? widget.unit ?? ''}';
          final materialName =
              '${material['name'] ?? widget.materialName ?? 'Raw Material'}';
          final kgPerBag =
              asD(data['kgPerBag']) > 0 ? asD(data['kgPerBag']) : 50.0;
          final inward = transactions
              .where((row) => row['transaction_type'] == 'INWARD')
              .toList();
          final consumed = transactions
              .where((row) => row['transaction_type'] == 'OUTWARD_PROCESSING')
              .where((row) => '${row['transaction_date']}'.startsWith(_month))
              .toList();
          final theme = Theme.of(context);

          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back)),
              Expanded(
                child: PageHeader(
                  title: '$materialName Inventory',
                  subtitle: 'Material-wise inward and processing history',
                ),
              ),
            ]),
            LayoutBuilder(builder: (context, box) {
              final columns = box.maxWidth >= 760 ? 3 : 1;
              final width =
                  columns == 1 ? box.maxWidth : (box.maxWidth - 24) / 3;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(
                  width: width,
                  child: StatCard(
                    icon: Icons.inventory_2_outlined,
                    label: 'Live remaining stock',
                    value: '${qty(material['current_stock'])} $unit',
                    sub: unit == 'bags'
                        ? '${qty(asD(material['current_stock']) * kgPerBag)} kg'
                        : null,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StatCard(
                    icon: Icons.payments_outlined,
                    label: 'Total spent to date',
                    value: money(material['total_spent']),
                    color: AppColors.info,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StatCard(
                    icon: Icons.blender_outlined,
                    label: 'Used in $_month',
                    value: '${qty(material['monthly_consumed'])} $unit',
                  ),
                ),
              ]);
            }),
            const SizedBox(height: 18),
            ResponsiveHistoryTabs(
              tabs: const [
                ResponsiveHistoryTab(
                  label: 'Purchase & delivery history · आवक',
                  mobileLabel: 'Purchase & delivery history · आवक',
                  icon: Icons.local_shipping_outlined,
                ),
                ResponsiveHistoryTab(
                  label: 'Usage & consumption · दळण',
                  mobileLabel: 'Usage & consumption · दळण',
                  icon: Icons.blender_outlined,
                ),
              ],
              selected: _tab,
              onChanged: (value) => setState(() => _tab = value),
            ),
            const SizedBox(height: 14),
            if (_tab == 0) ...[
              PageHeader(
                title: 'Inward stock',
                actions: [
                  FilledButton.icon(
                    onPressed: () => _inwardForm(material, kgPerBag, reload),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Inward Stock · आवक'),
                  ),
                ],
              ),
              if (inward.isEmpty)
                const EmptyState(
                  icon: Icons.local_shipping_outlined,
                  text: 'No inward stock records for this material yet.',
                ),
              for (final row in inward)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MaterialTransactionCard(
                    transaction: row,
                    materialName: materialName,
                    unit: unit,
                    onEdit: () => _editTransaction(row, kgPerBag, reload),
                    onDelete: () => _deleteTransaction(row, reload),
                  ),
                ),
            ] else ...[
              ResponsiveSectionHeader(
                title: 'Processing history',
                subtitle: 'Selected month: $_month',
                actions: [
                  FilledButton.icon(
                    onPressed: () =>
                        _processingForm(material, kgPerBag, reload),
                    icon: const Icon(Icons.blender_outlined),
                    label: const Text('Grind & Mix / दळण-वापर'),
                  ),
                  TextButton.icon(
                    onPressed: _selectMonth,
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Change month'),
                  ),
                ],
              ),
              AppCard(
                child: Row(children: [
                  const Icon(Icons.summarize_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Total consumed in $_month',
                        style: theme.textTheme.titleSmall),
                  ),
                  Text(
                    '${qty(material['monthly_consumed'])} $unit',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              if (consumed.isEmpty)
                const EmptyState(
                  icon: Icons.blender_outlined,
                  text: 'No processing records for this material yet.',
                ),
              for (final row in consumed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MaterialTransactionCard(
                    transaction: row,
                    materialName: materialName,
                    unit: unit,
                    onEdit: () => _editTransaction(row, kgPerBag, reload),
                    onDelete: () => _deleteTransaction(row, reload),
                  ),
                ),
            ],
          ]);
        },
      );
}

class _MaterialTransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final String materialName;
  final String unit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MaterialTransactionCard({
    required this.transaction,
    required this.materialName,
    required this.unit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isInward = transaction['transaction_type'] == 'INWARD';
    final color =
        isInward ? Colors.green : Theme.of(context).colorScheme.tertiary;
    final enteredQuantity =
        transaction['entered_quantity'] ?? transaction['quantity'];
    final enteredUnit = '${transaction['entered_unit'] ?? unit}';
    final quantity = qty(enteredQuantity);
    final detail = [
      if (isInward &&
          transaction['vendor_name'] != null &&
          '${transaction['vendor_name']}'.isNotEmpty)
        '${transaction['vendor_name']}',
      if (isInward &&
          transaction['bill_number'] != null &&
          '${transaction['bill_number']}'.isNotEmpty)
        'Bill ${transaction['bill_number']}',
      if (transaction['remarks'] != null &&
          '${transaction['remarks']}'.isNotEmpty)
        '${transaction['remarks']}',
    ].join(' · ');
    final title = isInward
        ? '$quantity $enteredUnit received'
        : '$quantity $enteredUnit of $materialName used${transaction['feed_product_name'] == null ? '' : ' · ${qty(transaction['quantity_bags'])} bags of ${transaction['feed_product_name']} added to Feed'}';

    return AppCard(
      child: Row(children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(
            isInward ? Icons.south_west : Icons.blender_outlined,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(
                [
                  fmtDate(transaction['transaction_date']),
                  if (isInward && transaction['total_amount'] != null)
                    money(transaction['total_amount']),
                  if (detail.isNotEmpty) detail,
                ].join(' · '),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).hintColor),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Edit',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Delete',
          onPressed: onDelete,
          icon: Icon(Icons.delete_outline,
              color: Theme.of(context).colorScheme.error),
        ),
        Text(
          '${isInward ? '+' : '-'}$quantity $enteredUnit',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }
}
