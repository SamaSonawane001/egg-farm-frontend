import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../widgets/bill_upload_picker.dart';
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
const _routes = [
  MapEntry('Water', 'Water'),
  MapEntry('Feed', 'Feed'),
  MapEntry('Spray', 'Spray'),
  MapEntry('Injection', 'Injection'),
];

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  DateTimeRange? _dateRange;
  final TextEditingController _search = TextEditingController();
  String _searchTerm = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Map<String, String>? get _dateQuery => _dateRange == null
      ? null
      : {
          'from': _dateRange!.start.toIso8601String().substring(0, 10),
          'to': _dateRange!.end.toIso8601String().substring(0, 10),
        };

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait([
      ApiClient.instance.get('/medicines'),
      ApiClient.instance.get('/medicines/logs', query: _dateQuery),
      ApiClient.instance.get('/flock/batches'),
    ]);
    return {
      'medicines': List<Map<String, dynamic>>.from(results[0] as List),
      'logs': List<Map<String, dynamic>>.from(results[1] as List),
      'flocks': List<Map<String, dynamic>>.from(results[2] as List),
    };
  }

  Future<void> _medicineForm(BuildContext context,
      {Map<String, dynamic>? medicine}) async {
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
        FieldSpec('min_alert_level', 'Low-stock alert level',
            type: FieldType.number,
            required: false,
            validator: (value, _) =>
                decimalValueError(value, maxDecimalPlaces: 3)),
      ],
      onSubmit: (v) async {
        final body = {
          'name': v['name'],
          'category': v['category'],
          'unit': v['unit'],
          'min_alert_level': double.tryParse(v['min_alert_level'] ?? '') ?? 0,
        };
        if (medicine == null) {
          await ApiClient.instance.post('/medicines', body);
        } else {
          await ApiClient.instance.put('/medicines/${medicine['id']}', body);
        }
      },
    );
    if (saved && context.mounted) {
      toast(context, medicine == null ? 'Medicine added' : 'Medicine updated');
    }
  }

  Future<void> _deleteMedicine(
      BuildContext context, Map<String, dynamic> medicine) async {
    if (!await confirmDelete(context, 'medicine "${medicine['name']}"')) return;
    try {
      await ApiClient.instance.delete('/medicines/${medicine['id']}');
      if (context.mounted) toast(context, 'Medicine deleted');
    } catch (error) {
      if (context.mounted) toast(context, '$error', error: true);
    }
  }

  Future<void> _inwardForm(BuildContext context) async {
    final billUpload = BillUploadController();
    try {
      final saved = await showFormDialog(
        context,
        title: 'Add Medicine Stock',
        fields: [
          const FieldSpec('medicine_name', 'Medicine name'),
          FieldSpec('category', 'Category',
              type: FieldType.select, options: _medicineCategories),
          FieldSpec('unit', 'Unit',
              type: FieldType.select, options: _medicineUnits),
          FieldSpec('quantity', 'Purchased quantity',
              type: FieldType.number,
              validator: (value, _) => decimalValueError(value,
                  maxDecimalPlaces: 3, mustBePositive: true)),
          const FieldSpec('batch_number', 'Batch number'),
          const FieldSpec('expiry_date', 'Expiry date', type: FieldType.date),
          const FieldSpec('date', 'Purchase date', type: FieldType.date),
          const FieldSpec('bill_number', 'Bill number', required: false),
          const FieldSpec('vendor_name', 'Vendor / supplier'),
          FieldSpec('total_cost', 'Total cost',
              type: FieldType.number,
              validator: (value, _) =>
                  decimalValueError(value, maxDecimalPlaces: 2)),
          const FieldSpec('remarks', 'Notes',
              type: FieldType.multiline, required: false),
        ],
        extraContentBuilder: (_) =>
            BillUploadPicker(controller: billUpload, moduleName: 'medicines'),
        onSubmit: (v) async {
          final billImageUrl = await billUpload.upload(moduleName: 'medicines');
          await ApiClient.instance.post('/medicines/inward', {
            'medicine_name': v['medicine_name'],
            'category': v['category'],
            'unit': v['unit'],
            'quantity': double.parse(v['quantity']!),
            'batch_number': v['batch_number'],
            'expiry_date': v['expiry_date'],
            'date': v['date'],
            'total_cost': double.parse(v['total_cost']!),
            'bill_number': v['bill_number'],
            'vendor_name': v['vendor_name'],
            'bill_image_url': billImageUrl,
            'remarks': v['remarks'],
          });
        },
      );
      if (saved && context.mounted) toast(context, 'Medicine stock received');
    } finally {
      billUpload.dispose();
    }
  }

  Future<void> _usageForm(
    BuildContext context,
    List<Map<String, dynamic>> medicines,
    List<Map<String, dynamic>> flocks,
  ) async {
    if (medicines.isEmpty || flocks.isEmpty) {
      toast(
          context, 'Add medicine stock and a flock batch before logging usage.',
          error: true);
      return;
    }
    final saved = await showFormDialog(
      context,
      title: 'Log Daily Usage · औषध देणे',
      fields: [
        FieldSpec('medicine_id', 'Medicine', type: FieldType.select, options: [
          for (final m in medicines)
            MapEntry('${m['id']}', '${m['name']} (${m['unit']})')
        ]),
        FieldSpec('flock_id', 'Shed / flock', type: FieldType.select, options: [
          for (final flock in flocks)
            MapEntry('${flock['id']}', '${flock['batch_name']}')
        ]),
        FieldSpec('quantity', 'Quantity used',
            type: FieldType.number,
            validator: (value, _) => decimalValueError(value,
                maxDecimalPlaces: 3, mustBePositive: true)),
        const FieldSpec('admin_route', 'Administration route',
            type: FieldType.select, options: _routes),
        const FieldSpec('date', 'Date', type: FieldType.date),
        const FieldSpec('remarks', 'Notes',
            type: FieldType.multiline, required: false),
      ],
      onSubmit: (v) async {
        final selected =
            medicines.firstWhere((m) => '${m['id']}' == v['medicine_id']);
        await ApiClient.instance.post('/medicines/usage', {
          'medicine_id': int.parse(v['medicine_id']!),
          'flock_id': int.parse(v['flock_id']!),
          'quantity': double.parse(v['quantity']!),
          'unit': selected['unit'],
          'admin_route': v['admin_route'],
          'date': v['date'],
          'remarks': v['remarks'],
        });
      },
    );
    if (saved && context.mounted) toast(context, 'Medicine usage recorded');
  }

  Future<void> _dateFilter() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (range != null) setState(() => _dateRange = range);
  }

  @override
  Widget build(BuildContext context) => DataLoader<Map<String, dynamic>>(
        key: ValueKey(_dateRange?.toString()),
        load: _load,
        builder: (context, data, reload) {
          final medicines = data['medicines'] as List<Map<String, dynamic>>;
          final logs = data['logs'] as List<Map<String, dynamic>>;
          final flocks = data['flocks'] as List<Map<String, dynamic>>;
          final needle = _searchTerm.trim().toLowerCase();
          final visibleMedicines = medicines.where((medicine) =>
              '${medicine['name']} ${medicine['category']} ${medicine['unit']} ${medicine['batch_numbers']}'
                  .toLowerCase()
                  .contains(needle));
          final visibleLogs = logs.where((log) {
            final allocations =
                List<Map<String, dynamic>>.from(log['allocations'] ?? const []);
            final batches = allocations
                .map((allocation) => '${allocation['batch_number']}')
                .join(' ');
            return '${log['medicine_name']} ${log['medicine_category']} ${log['batch_number']} $batches ${log['vendor_name']} ${log['bill_number']} ${log['admin_route']} ${log['flock_name']} ${log['remarks']}'
                .toLowerCase()
                .contains(needle);
          });
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _search,
                onChanged: (value) => setState(() => _searchTerm = value),
                decoration: dec(
                        context, 'Search medicines, batches and suppliers',
                        icon: Icons.search)
                    .copyWith(
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
              child: ListView(padding: const EdgeInsets.all(16), children: [
                PageHeader(
                  title: 'Medicines & Health · औषधे व लस',
                  subtitle:
                      'Stock, batch expiry alerts and daily flock treatment records',
                  actions: [
                    FilledButton.icon(
                      onPressed: () => _inwardForm(context),
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: const Text('Add Stock / औषध आवक'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _usageForm(context, medicines, flocks),
                      icon: const Icon(Icons.medical_services_outlined),
                      label: const Text('Daily Dosage / वापर'),
                    ),
                  ],
                ),
                if (visibleMedicines.isEmpty && needle.isNotEmpty)
                  const EmptyState(
                      icon: Icons.search_off,
                      text: 'No medicines match your search.')
                else if (medicines.isEmpty)
                  const EmptyState(
                    icon: Icons.medication_outlined,
                    text:
                        'No medicines added yet. Create a medicine to receive and track stock.',
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
                              onEdit: () =>
                                  _medicineForm(context, medicine: medicine),
                              onDelete: () =>
                                  _deleteMedicine(context, medicine),
                            ),
                          ),
                      ],
                    );
                  }),
                const SizedBox(height: 24),
                PageHeader(
                  title: 'Medicine History',
                  actions: [
                    OutlinedButton.icon(
                      onPressed: _dateFilter,
                      icon: const Icon(Icons.date_range),
                      label: Text(_dateRange == null
                          ? 'Filter dates'
                          : '${fmtDate(_dateRange!.start)} – ${fmtDate(_dateRange!.end)}'),
                    ),
                    if (_dateRange != null)
                      IconButton(
                        tooltip: 'Clear date filter',
                        onPressed: () => setState(() => _dateRange = null),
                        icon: const Icon(Icons.clear),
                      ),
                  ],
                ),
                if (visibleLogs.isEmpty && logs.isNotEmpty && needle.isNotEmpty)
                  const EmptyState(
                      icon: Icons.search_off,
                      text: 'No medicine transactions match your search.')
                else if (logs.isEmpty)
                  const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      text: 'No medicine transactions for this period.')
                else
                  for (final log in visibleLogs) _MedicineLogTile(log: log),
              ]),
            ),
          ]);
        },
      );
}

class _MedicineCard extends StatelessWidget {
  final Map<String, dynamic> medicine;
  final VoidCallback onEdit, onDelete;
  const _MedicineCard(
      {required this.medicine, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final stock = asD(medicine['current_stock']);
    final low = stock <= asD(medicine['min_alert_level']);
    final expiryValue = medicine['nearest_expiry'] ?? medicine['expiry_date'];
    final expiry = DateTime.tryParse('$expiryValue');
    final daysLeft = expiry?.difference(DateTime.now()).inDays;
    final expired = daysLeft != null && daysLeft < 0;
    final nearExpiry = daysLeft != null && daysLeft >= 0 && daysLeft <= 60;
    final warning = low || expired || nearExpiry;
    final color = warning
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.medication_outlined, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text('${medicine['name']}',
                  style: Theme.of(context).textTheme.titleMedium)),
          IconButton(
              tooltip: 'Edit medicine',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined)),
          IconButton(
              tooltip: 'Delete medicine',
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error)),
        ]),
        Text('${medicine['category']}',
            style: Theme.of(context).textTheme.bodySmall),
        Text('${qty(stock)} ${medicine['unit']}',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: color)),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            label: Text('${medicine['unit']}'),
            visualDensity: VisualDensity.compact,
          ),
        ),
        if (low)
          Text(
              'Low stock · alert at ${qty(medicine['min_alert_level'])} ${medicine['unit']}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        if (expiry != null)
          Text(
            '${expired ? 'Expired' : nearExpiry ? 'Expiring soon' : 'Nearest expiry'} · ${fmtDate(expiryValue)}',
            style: TextStyle(
                color:
                    expired || nearExpiry ? color : Theme.of(context).hintColor,
                fontWeight: expired || nearExpiry
                    ? FontWeight.w600
                    : FontWeight.normal),
          ),
      ]),
    );
  }
}

class _MedicineLogTile extends StatelessWidget {
  final Map<String, dynamic> log;
  const _MedicineLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final inward = log['transaction_type'] == 'INWARD';
    final color =
        inward ? Colors.green : Theme.of(context).colorScheme.tertiary;
    final extra = [
      if (log['batch_number'] != null && '${log['batch_number']}'.isNotEmpty)
        'Batch ${log['batch_number']}',
      if (log['bill_number'] != null && '${log['bill_number']}'.isNotEmpty)
        'Bill ${log['bill_number']}',
      if (log['vendor_name'] != null && '${log['vendor_name']}'.isNotEmpty)
        '${log['vendor_name']}',
      if (log['flock_name'] != null)
        '${log['flock_name']}'
      else if (log['flock_id'] != null)
        'Flock #${log['flock_id']}',
      if (log['admin_route'] != null) '${log['admin_route']}',
      if (log['expiry_date'] != null) 'Expiry ${fmtDate(log['expiry_date'])}',
      if (log['remarks'] != null && '${log['remarks']}'.isNotEmpty)
        '${log['remarks']}',
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(
                inward ? Icons.south_west : Icons.medical_services_outlined,
                color: color)),
        title: Text(
            '${log['medicine_name'] ?? 'Medicine'} · ${inward ? 'Stock received' : 'Used'}'),
        subtitle: Text(
            '${fmtDate(log['transaction_date'])}${extra.isEmpty ? '' : ' · $extra'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${inward ? '+' : '-'}${qty(log['quantity'])} ${log['unit']}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            if (log['bill_image_url'] != null)
              IconButton(
                tooltip: 'View bill',
                onPressed: () =>
                    showBillPreview(context, '${log['bill_image_url']}'),
                icon: const Icon(Icons.receipt_long_outlined),
              ),
          ],
        ),
      ),
    );
  }
}
