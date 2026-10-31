import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_client.dart';
import '../core/auth_state.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

const kInvoiceTypes = {
  'egg_sale': 'Egg Sale',
  'spent_hen_sale': 'Spent Hen Sale',
  'feed_trade': 'Feed Trade'
};

double _roundCurrency(double value) =>
    ((value + 1e-10) * 100).roundToDouble() / 100;

String pdfUrl(Map<String, dynamic> inv) =>
    '$kApiBase/public/invoices/${inv['share_token']}/pdf';

Future<void> openPdf(BuildContext c, Map<String, dynamic> inv) async {
  if (!await launchUrl(Uri.parse(pdfUrl(inv)),
          mode: LaunchMode.externalApplication) &&
      c.mounted) {
    toast(c, 'Could not open the PDF', error: true);
  }
}

Future<void> sendWhatsApp(
    BuildContext c, Map<String, dynamic> inv, String farmName) async {
  var phone =
      '${inv['customer_mobile'] ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '');
  if (phone.length == 10) phone = '$kDefaultCountryCode$phone';
  final items = List<Map<String, dynamic>>.from(inv['items'] ?? const []);
  final itemLines = items.map(_whatsAppLine).join('\n');
  final msg = 'Hello ${inv['customer_name']},\n'
      'Invoice ${inv['invoice_no']} from $farmName\n'
      'Date: ${fmtDate(inv['invoice_date'])}\n'
      '${itemLines.isEmpty ? '' : '\n$itemLines\n'}'
      'Total: ${money(inv['grand_total'])}\n\n'
      'View / download your invoice: ${pdfUrl(inv)}';
  final uri =
      Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      c.mounted) {
    toast(c, 'Could not open WhatsApp', error: true);
  }
}

String _whatsAppLine(Map<String, dynamic> item) {
  final unit = '${item['egg_unit'] ?? ''}';
  if (unit != 'crate' && unit != 'tray') {
    return '${item['description']}: ${qty(item['quantity'])} @ ${money(item['unit_price'])} = ${money(item['amount'])}';
  }
  final unitName = unit == 'crate' ? 'Crates' : 'Trays';
  return '${qty(item['quantity'])} $unitName (${qty(item['egg_quantity'])} eggs) '
      '@ ${money(item['unit_price'])} / egg = ${money(item['amount'])}';
}

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  Future<void> _create(
      BuildContext context, VoidCallback reload, double availableEggs) async {
    final auth = context.read<AuthState>();
    final created = await Navigator.of(context, rootNavigator: true)
        .push<Map<String, dynamic>>(
      MaterialPageRoute(
          builder: (_) => NewInvoicePage(
              defaultTax: asD(auth.user?['default_tax_percent']),
              availableEggs: availableEggs)),
    );
    if (created == null) return;
    if (!context.mounted) return;
    toast(context, 'Invoice created successfully');
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${created['invoice_no']} created'),
        content: Text(
            'Total ${money(created['grand_total'])}. Share it with ${created['customer_name']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Later')),
          OutlinedButton.icon(
              onPressed: () => openPdf(c, created),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF')),
          FilledButton.icon(
            onPressed: () => sendWhatsApp(c, created, auth.farmName),
            icon: const Icon(Icons.send),
            label: const Text('WhatsApp'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return DataLoader<Map<String, dynamic>>(
      load: () async {
        final results = await Future.wait([
          ApiClient.instance.get('/invoices'),
          ApiClient.instance.get('/eggs/stock')
        ]);
        return {
          'invoices': List<Map<String, dynamic>>.from(results[0] as List),
          'eggStock': Map<String, dynamic>.from(results[1] as Map),
        };
      },
      builder: (context, data, reload) {
        final list = data['invoices'] as List<Map<String, dynamic>>;
        final eggStock = data['eggStock'] as Map<String, dynamic>;
        final t = Theme.of(context);
        return ListView(padding: const EdgeInsets.all(16), children: [
          PageHeader(
            title: 'Invoicing & Billing',
            subtitle:
                '${list.length} invoices  •  ${money(list.fold<double>(0, (s, i) => s + asD(i['grand_total'])))} billed',
            actions: [
              Pill('Egg stock: ${qty(eggStock['available_eggs'])}',
                  AppColors.primary),
              FilledButton.icon(
                  onPressed: () =>
                      _create(context, reload, asD(eggStock['available_eggs'])),
                  icon: const Icon(Icons.add),
                  label: const Text('New invoice')),
            ],
          ),
          if (list.isEmpty)
            const EmptyState(
                icon: Icons.receipt_long_outlined,
                text: 'No invoices yet. Create your first one.'),
          for (final i in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(
                                '${i['invoice_no']}  •  ${i['customer_name']}',
                                style: t.textTheme.titleMedium)),
                        Text(money(i['grand_total']),
                            style: t.textTheme.titleMedium
                                ?.copyWith(color: t.colorScheme.primary)),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        Pill(
                            kInvoiceTypes[i['invoice_type']] ??
                                '${i['invoice_type']}',
                            AppColors.yolk),
                        const SizedBox(width: 8),
                        Text(
                            '${fmtDate(i['invoice_date'])}  •  ${i['items_count']} items',
                            style: t.textTheme.bodySmall
                                ?.copyWith(color: t.hintColor)),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        OutlinedButton.icon(
                            onPressed: () => openPdf(context, i),
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text('PDF')),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white),
                          onPressed: () =>
                              sendWhatsApp(context, i, auth.farmName),
                          icon: const Icon(Icons.send, size: 18),
                          label: const Text('Send via WhatsApp'),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: t.colorScheme.error),
                          onPressed: () async {
                            if (!await confirmDelete(
                                context, 'invoice ${i['invoice_no']}')) return;
                            try {
                              await ApiClient.instance
                                  .delete('/invoices/${i['id']}');
                              if (context.mounted)
                                toast(context, 'Invoice deleted successfully');
                            } catch (e) {
                              if (context.mounted)
                                toast(context, '$e', error: true);
                            }
                          },
                        ),
                      ]),
                    ]),
              ),
            ),
        ]);
      },
    );
  }
}

class _Item {
  final desc = TextEditingController();
  final qtyC = TextEditingController(text: '1');
  final price = TextEditingController();
  String eggUnit = 'eggs';
  double amountFor(String invoiceType) => _roundCurrency(
        asD(qtyC.text) *
            asD(price.text) *
            (invoiceType == 'egg_sale' && eggUnit != 'eggs' ? 30 : 1),
      );
  void dispose() {
    desc.dispose();
    qtyC.dispose();
    price.dispose();
  }
}

class NewInvoicePage extends StatefulWidget {
  final double defaultTax;
  final double availableEggs;
  const NewInvoicePage(
      {super.key, required this.defaultTax, required this.availableEggs});
  @override
  State<NewInvoicePage> createState() => _NewInvoicePageState();
}

class _NewInvoicePageState extends State<NewInvoicePage> {
  final _form = GlobalKey<FormState>();
  String _type = 'egg_sale';
  String _date = today();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _notes = TextEditingController();
  late final TextEditingController _tax = TextEditingController(
      text: widget.defaultTax == 0 ? '' : '${widget.defaultTax}');
  final List<_Item> _items = [_Item()];
  bool _saving = false;

  double get _eggQuantity => _type != 'egg_sale'
      ? 0
      : _items.fold<double>(
          0,
          (total, item) =>
              total + asD(item.qtyC.text) * (item.eggUnit == 'eggs' ? 1 : 30),
        );
  bool get _exceedsEggStock => _eggQuantity > widget.availableEggs;

  double get _subtotal =>
      _roundCurrency(_items.fold(0, (s, i) => s + i.amountFor(_type)));
  double get _taxAmt => _roundCurrency(_subtotal * asD(_tax.text) / 100);

  @override
  void dispose() {
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final res = await ApiClient.instance.post('/invoices', {
        'invoice_type': _type,
        'customer_name': _name.text.trim(),
        'customer_mobile': _mobile.text.trim(),
        'invoice_date': _date,
        'tax_percent': asD(_tax.text),
        'notes': _notes.text.trim(),
        'items': [
          for (final i in _items)
            {
              'description': i.desc.text.trim(),
              'quantity': asD(i.qtyC.text),
              'unit_price': asD(i.price.text),
              'egg_unit': _type == 'egg_sale' ? i.eggUnit : null,
              'egg_quantity': _type == 'egg_sale'
                  ? (asD(i.qtyC.text) * (i.eggUnit == 'eggs' ? 1 : 30)).round()
                  : null,
            }
        ],
      });
      if (mounted) Navigator.pop(context, Map<String, dynamic>.from(res));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        toast(context, '$e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    String? req(String? s) => (s ?? '').trim().isEmpty ? 'Required' : null;
    String? posNum(String? s) => asD(s) > 0 ? null : 'Must be > 0';
    return Scaffold(
      appBar: AppBar(title: const Text('New invoice')),
      body: Form(
        key: _form,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              AppCard(
                color: _exceedsEggStock
                    ? t.colorScheme.errorContainer
                    : t.colorScheme.primaryContainer,
                child: Row(children: [
                  Icon(Icons.egg_outlined,
                      color: _exceedsEggStock
                          ? t.colorScheme.error
                          : t.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          'Current In-Stock Eggs: ${qty(widget.availableEggs)}',
                          style: t.textTheme.titleMedium)),
                ]),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: dec(context, 'Invoice type'),
                items: [
                  for (final e in kInvoiceTypes.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value))
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _name,
                  decoration:
                      dec(context, 'Customer name', icon: Icons.person_outline),
                  validator: req),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                decoration: dec(context, 'Customer WhatsApp number',
                    hint: '10 digits or with country code',
                    icon: Icons.phone_outlined),
              ),
              const SizedBox(height: 12),
              DatePickerField(
                  label: 'Invoice date',
                  value: _date,
                  onChanged: (v) => setState(() => _date = v)),
              const SizedBox(height: 18),
              Text('Line items', style: t.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_type == 'egg_sale')
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                      'Available after this invoice: ${qty(widget.availableEggs - _eggQuantity)} eggs',
                      style: TextStyle(
                          color: _exceedsEggStock
                              ? t.colorScheme.error
                              : t.colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                ),
              if (_type == 'egg_sale' && _exceedsEggStock)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                      'Cannot bill more than available stock (Max available: ${qty(widget.availableEggs)})',
                      style: TextStyle(
                          color: t.colorScheme.error,
                          fontWeight: FontWeight.w700)),
                ),
              for (var idx = 0; idx < _items.length; idx++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Column(children: [
                      TextFormField(
                          controller: _items[idx].desc,
                          decoration: dec(context, 'Description (e.g. Eggs)'),
                          validator: req),
                      const SizedBox(height: 10),
                      if (_type == 'egg_sale') ...[
                        DropdownButtonFormField<String>(
                          value: _items[idx].eggUnit,
                          decoration: dec(context, 'Egg billing unit'),
                          items: const [
                            DropdownMenuItem(
                                value: 'eggs', child: Text('Individual eggs')),
                            DropdownMenuItem(
                                value: 'crate',
                                child: Text('Crates (30 eggs each)')),
                            DropdownMenuItem(
                                value: 'tray', child: Text('Tray (30 eggs)')),
                          ],
                          onChanged: (value) => setState(
                              () => _items[idx].eggUnit = value ?? 'eggs'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _items[idx].qtyC,
                            keyboardType: TextInputType.numberWithOptions(
                                decimal: _type != 'egg_sale'),
                            decoration: dec(
                                context,
                                _type == 'egg_sale'
                                    ? (_items[idx].eggUnit == 'eggs'
                                        ? 'Eggs'
                                        : _items[idx].eggUnit == 'crate'
                                            ? 'Crates'
                                            : 'Trays')
                                    : 'Qty'),
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              final basic = posNum(value);
                              if (basic != null) return basic;
                              if (_type == 'egg_sale' &&
                                  asD(value) != asD(value).roundToDouble())
                                return 'Enter a whole number';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _items[idx].price,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: dec(
                                context,
                                _type == 'egg_sale'
                                    ? 'Rate / egg (₹)'
                                    : 'Rate'),
                            onChanged: (_) => setState(() {}),
                            validator: (s) => (s ?? '').trim().isEmpty
                                ? 'Required'
                                : decimalValueError(s, maxDecimalPlaces: 2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                            width: 90,
                            child: Text(money(_items[idx].amountFor(_type)),
                                textAlign: TextAlign.right,
                                style: t.textTheme.titleSmall)),
                        IconButton(
                          icon: Icon(Icons.close, color: t.colorScheme.error),
                          onPressed: _items.length == 1
                              ? null
                              : () => setState(() {
                                    _items.removeAt(idx).dispose();
                                  }),
                        ),
                      ]),
                      if (_type == 'egg_sale' &&
                          _items[idx].eggUnit != 'eggs') ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Total: ${qty(asD(_items[idx].qtyC.text) * 30)} eggs @ ${money(_items[idx].price.text)}/egg '
                            '(${money(asD(_items[idx].price.text) * 30)}/${_items[idx].eggUnit == 'crate' ? 'crate' : 'tray'})',
                            style: t.textTheme.bodySmall?.copyWith(
                              color: t.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              OutlinedButton.icon(
                  onPressed: () => setState(() => _items.add(_Item())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add line item')),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tax,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: dec(context, 'Tax % (optional)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: dec(context, 'Notes (optional)')),
              const SizedBox(height: 16),
              AppCard(
                color: t.colorScheme.primary.withOpacity(.08),
                child: Column(children: [
                  _sumRow(context, 'Subtotal', money(_subtotal)),
                  if (asD(_tax.text) > 0)
                    _sumRow(context, 'Tax (${_tax.text}%)', money(_taxAmt)),
                  const Divider(),
                  _sumRow(context, 'Grand total', money(_subtotal + _taxAmt),
                      bold: true),
                ]),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving || _exceedsEggStock ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Generate invoice'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sumRow(BuildContext c, String l, String v, {bool bold = false}) {
    final s = bold
        ? Theme.of(c).textTheme.titleMedium
        : Theme.of(c).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(l, style: s), Text(v, style: s)]),
    );
  }
}
