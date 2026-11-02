import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../widgets/bill_upload_picker.dart';
import '../widgets/common.dart';
import '../widgets/form_dialog.dart';

const _adminRoutes = [
  MapEntry('Water', 'Water'),
  MapEntry('Feed', 'Feed'),
  MapEntry('Spray', 'Spray'),
  MapEntry('Injection', 'Injection'),
];

class MedicineDetailScreen extends StatefulWidget {
  final int medicineId;
  final String? medicineName;
  final String? unit;

  const MedicineDetailScreen({
    super.key,
    required this.medicineId,
    this.medicineName,
    this.unit,
  });

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  DateTime _month = DateTime.now();
  int _tab = 0;

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait([
      ApiClient.instance.get(
        '/medicines/${widget.medicineId}/details',
        query: {
          'month': '${_month.month}',
          'year': '${_month.year}',
        },
      ),
      ApiClient.instance.get('/flock/batches'),
    ]);
    final result = results[0] as Map;
    return {
      'medicine': Map<String, dynamic>.from(result['medicine'] as Map),
      'purchases': List<Map<String, dynamic>>.from(result['purchases'] as List),
      'usage': List<Map<String, dynamic>>.from(result['usage'] as List),
      'flocks': List<Map<String, dynamic>>.from(results[1] as List),
    };
  }

  Future<void> _stockForm(
    Map<String, dynamic> medicine,
    VoidCallback reload, {
    Map<String, dynamic>? purchase,
  }) async {
    final billUpload = BillUploadController();
    try {
      final saved = await showFormDialog(
        context,
        title: purchase == null
            ? 'Add Stock / औषध आवक · ${medicine['name']}'
            : 'Edit Stock Batch · ${medicine['name']}',
        initial: purchase == null
            ? const {}
            : {
                ...purchase,
                'quantity': purchase['quantity'],
                'date': purchase['date'],
                'rate_per_unit': asD(purchase['quantity']) == 0
                    ? 0
                    : asD(purchase['total_cost']) / asD(purchase['quantity']),
              },
        fields: [
          const FieldSpec('date', 'Purchase date', type: FieldType.date),
          FieldSpec(
            'quantity',
            'Quantity purchased (${medicine['unit']})',
            type: FieldType.number,
            validator: _positiveQuantityValidator,
          ),
          FieldSpec(
            'rate_per_unit',
            'Rate / price per ${medicine['unit']} (₹)',
            type: FieldType.number,
            validator: _rateValidator,
          ),
          const FieldSpec('batch_number', 'Batch number'),
          const FieldSpec('expiry_date', 'Expiry date', type: FieldType.date),
          const FieldSpec(
            'vendor_name',
            'Vendor / supplier',
            required: false,
          ),
          const FieldSpec('bill_number', 'Bill number', required: false),
          const FieldSpec(
            'remarks',
            'Notes',
            type: FieldType.multiline,
            required: false,
          ),
        ],
        preview: (values) =>
            'Total amount: ${money(asD(values['quantity']) * asD(values['rate_per_unit']))}',
        extraContentBuilder: (_) => BillUploadPicker(
          controller: billUpload,
          moduleName: 'medicines',
        ),
        onSubmit: (values) async {
          final quantity = double.parse(values['quantity']!);
          final rate = double.parse(values['rate_per_unit']!);
          final billImageUrl = await billUpload.upload(moduleName: 'medicines');
          final body = {
            'unit': medicine['unit'],
            'quantity': quantity,
            'batch_number': values['batch_number'],
            'expiry_date': values['expiry_date'],
            'date': values['date'],
            'total_cost': double.parse((quantity * rate).toStringAsFixed(2)),
            'bill_number': values['bill_number'],
            'vendor_name': values['vendor_name'],
            'bill_image_url': billImageUrl ?? purchase?['bill_image_url'],
            'remarks': values['remarks'],
          };
          if (purchase == null) {
            await ApiClient.instance.post(
              '/medicines/${widget.medicineId}/stock',
              body,
            );
          } else {
            await ApiClient.instance.put(
              '/medicines/${widget.medicineId}/stock/${purchase['id']}',
              body,
            );
          }
        },
      );
      if (saved && mounted) {
        reload();
        toast(
            context,
            purchase == null
                ? 'Medicine stock received'
                : 'Medicine batch updated');
      }
    } finally {
      billUpload.dispose();
    }
  }

  Future<void> _deletePurchase(
    Map<String, dynamic> purchase,
    VoidCallback reload,
  ) async {
    if (!await confirmDelete(
        context, 'medicine batch "${purchase['batch_number']}"')) {
      return;
    }
    try {
      await ApiClient.instance.delete(
        '/medicines/${widget.medicineId}/stock/${purchase['id']}',
      );
      if (mounted) {
        reload();
        toast(context, 'Medicine batch deleted');
      }
    } catch (error) {
      if (mounted) toast(context, '$error', error: true);
    }
  }

  Future<void> _usageForm(
    Map<String, dynamic> medicine,
    List<Map<String, dynamic>> flocks,
    VoidCallback reload,
  ) async {
    if (flocks.isEmpty) {
      toast(context, 'Add a flock batch before logging medicine usage.',
          error: true);
      return;
    }
    final available = asD(medicine['available_stock']);
    final saved = await showFormDialog(
      context,
      title: 'Log Dosage / वापर · ${medicine['name']}',
      fields: [
        const FieldSpec('date', 'Date', type: FieldType.date),
        FieldSpec(
          'quantity',
          'Quantity used (${medicine['unit']})',
          type: FieldType.number,
          validator: (value, _) {
            final invalid = decimalValueError(
              value,
              maxDecimalPlaces: 3,
              mustBePositive: true,
            );
            if (invalid != null) return invalid;
            final quantity = double.tryParse(value ?? '');
            if (quantity != null && quantity > available + 0.0005) {
              return 'Only ${qty(available)} ${medicine['unit']} non-expired stock available';
            }
            return null;
          },
        ),
        FieldSpec('flock_id', 'Shed / flock', type: FieldType.select, options: [
          for (final flock in flocks)
            MapEntry('${flock['id']}', '${flock['batch_name']}'),
        ]),
        const FieldSpec(
          'admin_route',
          'Administration route',
          type: FieldType.select,
          options: _adminRoutes,
        ),
        const FieldSpec(
          'remarks',
          'Purpose / reason / disease notes',
          type: FieldType.multiline,
          required: false,
        ),
      ],
      preview: (_) =>
          'Available non-expired stock: ${qty(available)} ${medicine['unit']}',
      onSubmit: (values) async {
        await ApiClient.instance.post(
          '/medicines/${widget.medicineId}/usage',
          {
            'flock_id': int.parse(values['flock_id']!),
            'quantity': double.parse(values['quantity']!),
            'unit': medicine['unit'],
            'admin_route': values['admin_route'],
            'date': values['date'],
            'remarks': values['remarks'],
          },
        );
      },
    );
    if (saved && mounted) {
      reload();
      toast(context, 'Medicine usage recorded');
    }
  }

  static String? _positiveQuantityValidator(
    String? value,
    Map<String, String> _,
  ) =>
      decimalValueError(value, maxDecimalPlaces: 3, mustBePositive: true);

  static String? _rateValidator(String? value, Map<String, String> _) =>
      decimalValueError(value, maxDecimalPlaces: 3);

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Choose a date in the month to view',
    );
    if (picked != null) setState(() => _month = picked);
  }

  @override
  Widget build(BuildContext context) => DataLoader<Map<String, dynamic>>(
        key: ValueKey('${widget.medicineId}-${_month.year}-${_month.month}'),
        load: _load,
        builder: (context, data, reload) {
          final medicine = data['medicine'] as Map<String, dynamic>;
          final purchases = data['purchases'] as List<Map<String, dynamic>>;
          final allUsage = data['usage'] as List<Map<String, dynamic>>;
          final flocks = data['flocks'] as List<Map<String, dynamic>>;
          final usage = allUsage.where((row) {
            final date = DateTime.tryParse('${row['date']}');
            return date != null &&
                date.year == _month.year &&
                date.month == _month.month;
          }).toList();
          final unit = '${medicine['unit'] ?? widget.unit ?? ''}';
          final name =
              '${medicine['name'] ?? widget.medicineName ?? 'Medicine'}';
          final theme = Theme.of(context);

          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: PageHeader(
                  title: '$name Management',
                  subtitle:
                      'Medicine stock, batch expiry, and flock treatment history',
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
                    icon: Icons.medication_outlined,
                    label: 'Live remaining stock',
                    value: '${qty(medicine['current_stock'])} $unit',
                    sub: switch (unit) {
                      'L' => '${qty(asD(medicine['current_stock']) * 1000)} ml',
                      'kg' => '${qty(asD(medicine['current_stock']) * 1000)} g',
                      'ml' => '${qty(asD(medicine['current_stock']) / 1000)} L',
                      'g' => '${qty(asD(medicine['current_stock']) / 1000)} kg',
                      _ => null,
                    },
                    color: asD(medicine['current_stock']) <=
                            asD(medicine['min_alert_level'])
                        ? theme.colorScheme.error
                        : null,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StatCard(
                    icon: Icons.payments_outlined,
                    label: 'Total spent to date',
                    value: money(medicine['total_spent']),
                    color: AppColors.info,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StatCard(
                    icon: Icons.medical_services_outlined,
                    label:
                        'Used in ${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                    value: '${qty(medicine['monthly_used'])} $unit',
                  ),
                ),
              ]);
            }),
            const SizedBox(height: 18),
            ResponsiveHistoryTabs(
              tabs: const [
                ResponsiveHistoryTab(
                  label: 'Purchase & delivery history / आवक',
                  mobileLabel: 'Purchase & delivery history / आवक',
                  icon: Icons.local_shipping_outlined,
                ),
                ResponsiveHistoryTab(
                  label: 'Daily dosage & usage / वापर',
                  mobileLabel: 'Daily dosage & usage / वापर',
                  icon: Icons.medical_services_outlined,
                ),
              ],
              selected: _tab,
              onChanged: (value) => setState(() => _tab = value),
            ),
            const SizedBox(height: 14),
            if (_tab == 0) ...[
              PageHeader(
                title: 'Purchase & delivery history',
                actions: [
                  FilledButton.icon(
                    onPressed: () => _stockForm(medicine, reload),
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('Add Stock / औषध आवक'),
                  ),
                ],
              ),
              if (purchases.isEmpty)
                const EmptyState(
                  icon: Icons.local_shipping_outlined,
                  text: 'No stock deliveries for this medicine yet.',
                ),
              for (final purchase in purchases)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PurchaseTile(
                    purchase: purchase,
                    unit: unit,
                    onEdit: () => _stockForm(
                      medicine,
                      reload,
                      purchase: purchase,
                    ),
                    onDelete: () => _deletePurchase(purchase, reload),
                  ),
                ),
            ] else ...[
              ResponsiveSectionHeader(
                title: 'Daily dosage & usage',
                subtitle:
                    'Selected month: ${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                actions: [
                  TextButton.icon(
                    onPressed: _selectMonth,
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Change month'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _usageForm(medicine, flocks, reload),
                    icon: const Icon(Icons.add),
                    label: const Text('Log Dosage / वापर'),
                  ),
                ],
              ),
              AppCard(
                child: Row(children: [
                  const Icon(Icons.summarize_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Total dosage used this month',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    '${qty(medicine['monthly_used'])} $unit',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              if (usage.isEmpty)
                const EmptyState(
                  icon: Icons.medical_services_outlined,
                  text: 'No usage records for this month.',
                ),
              for (final record in usage)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _UsageTile(record: record, unit: unit),
                ),
            ],
          ]);
        },
      );
}

class _PurchaseTile extends StatelessWidget {
  final Map<String, dynamic> purchase;
  final String unit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PurchaseTile({
    required this.purchase,
    required this.unit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final quantity = asD(purchase['quantity']);
    final totalCost = asD(purchase['total_cost']);
    final rate = quantity <= 0 ? 0 : totalCost / quantity;
    final expiry = purchase['expiry_date'];
    final expiryDate = DateTime.tryParse('$expiry');
    final nearExpiry = expiryDate != null &&
        expiryDate.difference(DateTime.now()).inDays <= 60;
    final color = nearExpiry ? Theme.of(context).colorScheme.error : null;

    return AppCard(
      child: Row(children: [
        CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: .12),
          child:
              const Icon(Icons.medication_outlined, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${qty(quantity)} $unit received',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                [
                  fmtDate(purchase['date']),
                  'Batch ${purchase['batch_number']}',
                  'Expiry ${fmtDate(expiry)}',
                  '${money(rate)} per $unit',
                  if (purchase['vendor_name'] != null &&
                      '${purchase['vendor_name']}'.isNotEmpty)
                    '${purchase['vendor_name']}',
                  if (purchase['bill_number'] != null &&
                      '${purchase['bill_number']}'.isNotEmpty)
                    'Bill ${purchase['bill_number']}',
                  if (purchase['remarks'] != null &&
                      '${purchase['remarks']}'.isNotEmpty)
                    '${purchase['remarks']}',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color ?? Theme.of(context).hintColor,
                    ),
              ),
            ],
          ),
        ),
        if (purchase['bill_image_url'] != null)
          IconButton(
            tooltip: 'View bill',
            onPressed: () =>
                showBillPreview(context, '${purchase['bill_image_url']}'),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        IconButton(
          tooltip: 'Edit batch',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Delete batch',
          onPressed: onDelete,
          icon: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        Text(
          money(totalCost),
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      ]),
    );
  }
}

class _UsageTile extends StatelessWidget {
  final Map<String, dynamic> record;
  final String unit;

  const _UsageTile({required this.record, required this.unit});

  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(children: [
          CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.tertiary.withValues(alpha: .12),
            child: Icon(
              Icons.medical_services_outlined,
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${qty(record['quantity'])} $unit used · ${record['flock_name']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  [
                    fmtDate(record['date']),
                    '${record['admin_route']}',
                    if (record['remarks'] != null &&
                        '${record['remarks']}'.isNotEmpty)
                      '${record['remarks']}',
                  ].join(' · '),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
        ]),
      );
}
