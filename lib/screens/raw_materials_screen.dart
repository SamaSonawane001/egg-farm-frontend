import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../widgets/bill_upload_picker.dart';
import '../widgets/common.dart';
import '../widgets/form_dialog.dart';

class RawMaterialsScreen extends StatefulWidget {
  const RawMaterialsScreen({super.key});

  @override
  State<RawMaterialsScreen> createState() => _RawMaterialsScreenState();
}

class _RawMaterialsScreenState extends State<RawMaterialsScreen> {
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
      ApiClient.instance.get('/raw-materials'),
      ApiClient.instance.get('/raw-materials/logs', query: _dateQuery),
      ApiClient.instance.get('/raw-materials/processing'),
      ApiClient.instance.get('/feed/stock'),
    ]);
    final operations = List<Map<String, dynamic>>.from(results[2] as List);
    final start = _dateRange?.start.toIso8601String().substring(0, 10);
    final end = _dateRange?.end.toIso8601String().substring(0, 10);
    final filteredOperations = _dateRange == null
        ? operations
        : operations.where((operation) {
            final date = '${operation['processing_date']}'.substring(0, 10);
            return date.compareTo(start!) >= 0 && date.compareTo(end!) <= 0;
          }).toList();
    return {
      'materials': List<Map<String, dynamic>>.from(results[0] as List),
      'logs': List<Map<String, dynamic>>.from(results[1] as List),
      'operations': filteredOperations,
      'kgPerBag': asD((results[3] as Map)['kg_per_bag']),
    };
  }

  Future<void> _materialForm(BuildContext context,
      {Map<String, dynamic>? material, required VoidCallback reload}) async {
    var duplicate = false;
    final saved = await showFormDialog(
      context,
      title: material == null ? 'Add Raw Material' : 'Edit Raw Material',
      initial: material ?? {},
      fields: [
        const FieldSpec('name', 'Material name'),
        FieldSpec('unit', 'Stock unit', type: FieldType.select, options: [
          MapEntry('kg', 'Kilogram (kg)'),
          MapEntry('quintal', 'Quintal'),
          MapEntry('bags', 'Bags'),
        ]),
        FieldSpec('min_alert_threshold', 'Low-stock alert threshold',
            type: FieldType.number,
            required: false,
            validator: (value, _) =>
                decimalValueError(value, maxDecimalPlaces: 3)),
      ],
      onSubmit: (v) async {
        final body = {
          'name': v['name'],
          'unit': v['unit'],
          'min_alert_threshold':
              double.tryParse(v['min_alert_threshold'] ?? '') ?? 0,
        };
        if (material == null) {
          final result = await ApiClient.instance.post('/raw-materials', body);
          duplicate = result is Map && result['duplicate'] == true;
        } else {
          await ApiClient.instance
              .put('/raw-materials/${material['id']}', body);
        }
      },
    );
    if (saved && context.mounted) {
      reload();
      toast(
        context,
        duplicate
            ? 'Product already exists. Stock will be added to existing item.'
            : material == null
                ? 'Raw material added'
                : 'Raw material updated',
      );
    }
  }

  Future<void> _deleteMaterial(
      BuildContext context, Map<String, dynamic> material,
      {required VoidCallback reload}) async {
    if (!await confirmDelete(context, 'raw material "${material['name']}"')) {
      return;
    }
    try {
      await ApiClient.instance.delete('/raw-materials/${material['id']}');
      if (context.mounted) {
        reload();
        toast(context, 'Raw material deleted');
      }
    } catch (error) {
      if (context.mounted) toast(context, '$error', error: true);
    }
  }

  Future<void> _inwardForm(BuildContext context, VoidCallback reload) async {
    final billUpload = BillUploadController();
    try {
      final saved = await showFormDialog(
        context,
        title: 'Add Inward Stock · आवक',
        fields: [
          const FieldSpec('material_name', 'Material name'),
          const FieldSpec('unit', 'Unit', type: FieldType.select, options: [
            MapEntry('kg', 'Kilogram (kg)'),
            MapEntry('quintal', 'Quintal'),
            MapEntry('bags', 'Bags'),
          ]),
          FieldSpec('quantity', 'Quantity',
              type: FieldType.number,
              validator: (value, _) => decimalValueError(value,
                  maxDecimalPlaces: 3, mustBePositive: true)),
          const FieldSpec('date', 'Received on', type: FieldType.date),
          const FieldSpec('vendor_name', 'Supplier / vendor'),
          const FieldSpec('bill_number', 'Bill number', required: false),
          FieldSpec('rate_per_unit', 'Rate per unit',
              type: FieldType.number,
              validator: (value, _) =>
                  decimalValueError(value, maxDecimalPlaces: 3)),
          const FieldSpec('remarks', 'Notes',
              type: FieldType.multiline, required: false),
        ],
        preview: (v) =>
            'Total amount: ${money(asD(v['quantity']) * asD(v['rate_per_unit']))}',
        extraContentBuilder: (_) => BillUploadPicker(
            controller: billUpload, moduleName: 'raw_materials'),
        onSubmit: (v) async {
          final quantity = double.parse(v['quantity']!);
          final rate = double.parse(v['rate_per_unit']!);
          final billImageUrl =
              await billUpload.upload(moduleName: 'raw_materials');
          await ApiClient.instance.post('/raw-materials/inward', {
            'material_name': v['material_name'],
            'quantity': quantity,
            'unit': v['unit'],
            'date': v['date'],
            'supplier': v['vendor_name'],
            'vendor_name': v['vendor_name'],
            'bill_number': v['bill_number'],
            'bill_image_url': billImageUrl,
            'rate_per_unit': rate,
            'total_amount': double.parse((quantity * rate).toStringAsFixed(2)),
            'remarks': v['remarks'],
          });
        },
      );
      if (saved && context.mounted) {
        reload();
        toast(context, 'Inward stock recorded');
      }
    } finally {
      billUpload.dispose();
    }
  }

  Future<void> _processingForm(
    BuildContext context,
    List<Map<String, dynamic>> materials,
    VoidCallback reload,
  ) async {
    if (materials.isEmpty) {
      toast(context, 'Add a raw material while recording inward stock first.',
          error: true);
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProcessingDialog(materials: materials),
    );
    if (saved == true && context.mounted) {
      reload();
      toast(context, 'Feed processing recorded');
    }
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
          final materials = data['materials'] as List<Map<String, dynamic>>;
          final logs = data['logs'] as List<Map<String, dynamic>>;
          final operations = data['operations'] as List<Map<String, dynamic>>;
          final kgPerBag =
              asD(data['kgPerBag']) > 0 ? asD(data['kgPerBag']) : 50.0;
          final needle = _searchTerm.trim().toLowerCase();
          final visibleMaterials = materials.where((material) =>
              '${material['name']} ${material['unit']}'
                  .toLowerCase()
                  .contains(needle));
          final visibleLogs = logs.where((log) =>
              '${log['material_name']} ${log['supplier']} ${log['vendor_name']} ${log['bill_number']} ${log['remarks']} ${log['transaction_type']}'
                  .toLowerCase()
                  .contains(needle));
          final visibleOperations = operations.where((operation) {
            final ingredients = List<Map<String, dynamic>>.from(
                operation['materials'] ?? const []);
            final sourceNames =
                ingredients.map((m) => '${m['name']}').join(' ');
            return '${operation['feed_product_name']} $sourceNames ${operation['remarks']}'
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
                        context, 'Search materials, suppliers and history',
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
                  title: 'Raw Material · कच्चा माल',
                  subtitle:
                      'Live ingredient stock, inward purchases and feed processing',
                  actions: [
                    FilledButton.icon(
                      onPressed: () => _materialForm(context, reload: reload),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Material'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _inwardForm(context, reload),
                      icon: const Icon(Icons.move_to_inbox_outlined),
                      label: const Text('Add Inward Stock · आवक'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          _processingForm(context, materials, reload),
                      icon: const Icon(Icons.blender_outlined),
                      label: const Text('Grind & Mix / दळण-वापर'),
                    ),
                  ],
                ),
                if (visibleMaterials.isEmpty && needle.isNotEmpty)
                  const EmptyState(
                      icon: Icons.search_off,
                      text: 'No raw materials match your search.')
                else if (materials.isEmpty)
                  const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    text:
                        'No raw materials yet. Add maize, soya, minerals or supplements to begin.',
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
                        for (final material in visibleMaterials)
                          SizedBox(
                            width: width,
                            child: _MaterialCard(
                              material: material,
                              kgPerBag: kgPerBag,
                              onEdit: () => _materialForm(context,
                                  material: material, reload: reload),
                              onDelete: () => _deleteMaterial(context, material,
                                  reload: reload),
                            ),
                          ),
                      ],
                    );
                  }),
                const SizedBox(height: 24),
                PageHeader(
                  title: 'Transaction History',
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
                if (visibleLogs.isEmpty &&
                    visibleOperations.isEmpty &&
                    (logs.isNotEmpty || operations.isNotEmpty))
                  const EmptyState(
                      icon: Icons.search_off,
                      text: 'No transactions match your search.')
                else if (logs.isEmpty && operations.isEmpty)
                  const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      text: 'No raw material transactions for this period.')
                else ...[
                  for (final operation in visibleOperations)
                    _ProcessingTile(operation: operation),
                  for (final log in visibleLogs) _RawLogTile(log: log),
                ],
              ]),
            ),
          ]);
        },
      );
}

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> material;
  final double kgPerBag;
  final VoidCallback onEdit, onDelete;
  const _MaterialCard(
      {required this.material,
      required this.kgPerBag,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final stock = asD(material['current_stock']);
    final purchased = asD(material['total_purchased']);
    final consumed = asD(material['total_consumed']);
    final low = stock <= asD(material['min_alert_threshold']);
    final progress = purchased <= 0 ? 0.0 : (stock / purchased).clamp(0.0, 1.0);
    final color = low ? Theme.of(context).colorScheme.error : AppColors.primary;
    final unit = '${material['unit']}';
    final secondary = unit == 'kg'
        ? '≈ ${qty(stock / 100)} quintals live stock'
        : unit == 'quintal'
            ? '≈ ${qty(stock * 100)} kg live stock'
            : unit == 'bags'
                ? '≈ ${qty(stock * kgPerBag)} kg live stock'
                : '≈ ${qty(stock)} $unit live stock';
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 8),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(.12),
              child: const Icon(Icons.grain_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${material['name']}',
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.chevron_right),
            IconButton(
                tooltip: 'Edit name',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 19)),
            IconButton(
                tooltip: 'Delete material',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${qty(stock)} $unit in stock',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: color)),
            Text(secondary,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).hintColor)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: progress,
                backgroundColor:
                    Theme.of(context).colorScheme.outline.withOpacity(.2),
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _StockMetric(
                      label: 'Purchased / आवक',
                      value: '${qty(purchased)} $unit')),
              Expanded(
                  child: _StockMetric(
                      label: 'Consumed / वापर',
                      value: '${qty(consumed)} $unit')),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _StockMetric extends StatelessWidget {
  final String label;
  final String value;
  const _StockMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Theme.of(context).hintColor)),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      );
}

class _RawLogTile extends StatelessWidget {
  final Map<String, dynamic> log;
  const _RawLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final inward = log['transaction_type'] == 'INWARD';
    final quantity = asD(log['quantity']);
    final color =
        inward ? Colors.green : Theme.of(context).colorScheme.tertiary;
    final detail = [
      if (log['vendor_name'] != null && '${log['vendor_name']}'.isNotEmpty)
        '${log['vendor_name']}',
      if (log['bill_number'] != null && '${log['bill_number']}'.isNotEmpty)
        'Bill ${log['bill_number']}',
      if (log['remarks'] != null && '${log['remarks']}'.isNotEmpty)
        '${log['remarks']}',
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(inward ? Icons.south_west : Icons.blender_outlined,
                color: color)),
        title: Text(
            '${log['material_name'] ?? 'Raw material'} · ${inward ? 'Inward' : 'Processing'}'),
        subtitle: Text(
            '${fmtDate(log['transaction_date'])}${detail.isEmpty ? '' : ' · $detail'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${inward ? '+' : '-'}${qty(quantity)} ${log['unit']}',
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

class _ProcessingTile extends StatelessWidget {
  final Map<String, dynamic> operation;
  const _ProcessingTile({required this.operation});

  @override
  Widget build(BuildContext context) {
    final materials =
        List<Map<String, dynamic>>.from(operation['materials'] ?? const []);
    final remarks = '${operation['remarks'] ?? ''}'.trim();
    final producedQuantity =
        operation['produced_quantity'] ?? operation['quantity_bags'];
    final producedUnit = operation['produced_unit'] ?? 'bags';
    final producedFrom = materials
        .map((material) =>
            '${qty(material['quantity'])} ${material['unit']} ${material['name']}')
        .join(', ');
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.blender_outlined)),
        title: Text(
            '${qty(producedQuantity)} $producedUnit of ${operation['feed_product_name']} produced${producedFrom.isEmpty ? '' : ' from $producedFrom'}'),
        subtitle: Text(
          [
            fmtDate(operation['processing_date']),
            if (remarks.isNotEmpty) remarks,
          ].join(' · '),
        ),
      ),
    );
  }
}

class _ProcessingDialog extends StatefulWidget {
  final List<Map<String, dynamic>> materials;
  const _ProcessingDialog({required this.materials});

  @override
  State<_ProcessingDialog> createState() => _ProcessingDialogState();
}

class _ProcessingDialogState extends State<_ProcessingDialog> {
  final _form = GlobalKey<FormState>();
  final _output = TextEditingController();
  final _feedName = TextEditingController();
  final _notes = TextEditingController();
  final List<({String? id, TextEditingController quantity})> _inputs = [];
  String _outputUnit = 'bags';
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _addInput();
  }

  void _addInput() => setState(
      () => _inputs.add((id: null, quantity: TextEditingController())));

  @override
  void dispose() {
    _output.dispose();
    _feedName.dispose();
    _notes.dispose();
    for (final input in _inputs) {
      input.quantity.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final inputs = <Map<String, dynamic>>[];
    final selectedMaterials = <String>{};
    for (final input in _inputs) {
      if (input.id == null || double.tryParse(input.quantity.text) == null) {
        setState(() => _error = 'Choose a material and enter its quantity.');
        return;
      }
      if (!selectedMaterials.add(input.id!)) {
        setState(() => _error = 'Each material can only be added once.');
        return;
      }
      inputs.add({
        'material_id': int.parse(input.id!),
        'quantity': double.parse(input.quantity.text),
      });
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post('/raw-materials/processing', {
        'date': _date.toIso8601String().substring(0, 10),
        'feed_product_name': _feedName.text.trim(),
        'output_quantity': double.parse(_output.text),
        'output_unit': _outputUnit,
        'materials': inputs,
        'remarks': _notes.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Record Grinding / Feed Mixing · दळण'),
        content: SizedBox(
          width: (MediaQuery.of(context).size.width - 80).clamp(280.0, 520.0),
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: _feedName,
                  decoration: dec(context, 'Finished feed name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the produced feed name'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _output,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: dec(context, 'Produced quantity'),
                      validator: (value) => decimalValueError(value,
                          maxDecimalPlaces: 3, mustBePositive: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _outputUnit,
                      decoration: dec(context, 'Unit'),
                      items: const [
                        DropdownMenuItem(value: 'bags', child: Text('Bags')),
                        DropdownMenuItem(value: 'kg', child: Text('Kg')),
                      ],
                      onChanged: (value) =>
                          setState(() => _outputUnit = value ?? 'bags'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Processing date'),
                  subtitle: Text(fmtDate(_date)),
                  onTap: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (value != null) setState(() => _date = value);
                  },
                ),
                for (var i = 0; i < _inputs.length; i++) ...[
                  Row(children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: _inputs[i].id,
                        isExpanded: true,
                        decoration: dec(context, 'Raw material'),
                        items: [
                          for (final material in widget.materials)
                            DropdownMenuItem(
                                value: '${material['id']}',
                                child: Text(
                                    '${material['name']} (${material['unit']})',
                                    overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: (value) => setState(() => _inputs[i] =
                            (id: value, quantity: _inputs[i].quantity)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _inputs[i].quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: dec(context, 'Qty'),
                        validator: (value) => decimalValueError(value,
                            maxDecimalPlaces: 3, mustBePositive: true),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove ingredient',
                      onPressed: _inputs.length == 1
                          ? null
                          : () => setState(() {
                                _inputs.removeAt(i).quantity.dispose();
                              }),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ]),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addInput,
                    icon: const Icon(Icons.add),
                    label: const Text('Add ingredient'),
                  ),
                ),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 3,
                  decoration: dec(context, 'Notes (optional)'),
                ),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Processing')),
        ],
      );
}
