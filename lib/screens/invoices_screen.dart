import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_client.dart';
import '../core/auth_state.dart';
import '../core/config.dart';
import '../core/invoice_pdf_file.dart';
import '../core/theme.dart';
import 'customer_ledger_screen.dart';
import '../widgets/common.dart';
import '../widgets/subscription_widgets.dart';

const kInvoiceTypes = {
  'egg_sale': 'Egg Sale • अंडी विक्री',
  'spent_hen_sale':
      'Spent Hen / Cull Birds • कोंबडी विक्री (अंडी क्षमता संपलेले पक्षी)',
  'poultry_manure_sale': 'Poultry Manure Sale • कोंबडी खत विक्री',
  'feed_trade': 'Feed / Raw Material Sale • फीड / कच्चा माल विक्री',
};
const _manureSaleUnits = {
  'bag': 'Bags / पोती',
  'tractor_trolley': 'Tractor Trolley / ट्रॉली',
  'ton': 'Ton / टन',
};
const _whatsAppChannel = MethodChannel('egg_farm/invoice_share');

double _roundCurrency(double value) =>
    ((value + 1e-10) * 100).roundToDouble() / 100;

String pdfUrl(Map<String, dynamic> inv) => publicInvoicePdfUrl('${inv['id']}');

Future<void> openPdf(BuildContext c, Map<String, dynamic> inv) async {
  if (!await launchUrl(Uri.parse(pdfUrl(inv)),
          mode: LaunchMode.externalApplication) &&
      c.mounted) {
    toast(c, 'Could not open the PDF', error: true);
  }
}

String? _whatsAppPhone(dynamic value) {
  var phone = '$value'.replaceAll(RegExp(r'[^0-9]'), '');
  while (phone.startsWith('0')) {
    phone = phone.substring(1);
  }
  if (RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
    return '$kDefaultCountryCode$phone';
  }
  if (phone.length == 12 &&
      phone.startsWith(kDefaultCountryCode) &&
      RegExp(r'^91[6-9]\d{9}$').hasMatch(phone)) {
    return phone;
  }
  return null;
}

String _invoiceShareMessage(Map<String, dynamic> inv, String farmName) {
  final farm = farmName.trim().isEmpty ? 'Egg Invoice' : farmName.trim();
  final rawCustomer = '${inv['customer_name'] ?? ''}'.trim();
  final customer = rawCustomer.isEmpty ? 'Walk-in Customer' : rawCustomer;
  final status = inv['payment_status'] == 'paid' ? 'Paid' : 'Unpaid';
  return '*$farm*\n'
      'Customer: *$customer*\n'
      'Total Amount: *${money(inv['grand_total'])}*\n'
      'Status: *$status*\n\n'
      'View / Download Invoice PDF:\n'
      '${pdfUrl(inv)}';
}

Future<void> sendWhatsApp(
    BuildContext c, Map<String, dynamic> inv, String farmName) async {
  final phone = _whatsAppPhone(inv['customer_mobile']);
  if (phone == null) {
    if (c.mounted) {
      toast(c, 'Enter a valid customer WhatsApp number to continue.',
          error: true);
    }
    return;
  }

  final message = _invoiceShareMessage(inv, farmName);
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    final whatsappUri = Uri.https('api.whatsapp.com', '/send', {
      'phone': phone,
      'text': message,
    });
    try {
      if (!await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('WhatsApp could not be opened');
      }
    } catch (error) {
      debugPrint('Could not open WhatsApp Web: $error');
      if (c.mounted) {
        toast(c, 'Could not open WhatsApp.', error: true);
      }
    }
    return;
  }

  XFile pdfFile;
  try {
    final response = await http
        .get(Uri.parse(pdfUrl(inv)))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('PDF download failed (${response.statusCode})');
    }
    if (response.bodyBytes.length < 5 ||
        String.fromCharCodes(response.bodyBytes.take(5)) != '%PDF-') {
      throw Exception('The server did not return a valid PDF');
    }
    pdfFile = await createInvoicePdfFile(
      response.bodyBytes,
      '${farmName.trim().isEmpty ? 'Egg_Invoice' : farmName}_${inv['customer_name'] ?? 'Customer'}',
      fileNamePrefix: '',
    );
  } catch (error) {
    debugPrint('Could not prepare invoice PDF for WhatsApp: $error');
    if (c.mounted) {
      toast(c, 'Could not prepare the invoice PDF. Please try again.',
          error: true);
    }
    return;
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      final shared = await _whatsAppChannel.invokeMethod<bool>(
        'shareInvoiceToWhatsApp',
        {
          'filePath': pdfFile.path,
          'phone': phone,
          'text': message,
        },
      );
      if (shared == true) return;
    } catch (error) {
      debugPrint('Direct WhatsApp PDF share failed: $error');
    }
  }

  try {
    await Share.shareXFiles(
      [pdfFile],
      text: message,
      subject:
          '${farmName.trim().isEmpty ? 'Egg Invoice' : farmName} — Invoice',
    );
  } catch (error) {
    debugPrint('Invoice PDF fallback share failed: $error');
    if (c.mounted) {
      toast(
        c,
        'Could not share the invoice PDF. Please try again.',
        error: true,
      );
    }
  }
}

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  static const _pageSize = 10;
  final ScrollController _scrollController = ScrollController();
  int _page = 1;
  int _section = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _changePage(int page) {
    setState(() => _page = page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _togglePaymentStatus(
    BuildContext context,
    Map<String, dynamic> invoice,
    VoidCallback reload,
  ) async {
    final wasPaid = invoice['payment_status'] == 'paid';
    try {
      await ApiClient.instance.patch(
        '/invoices/${invoice['id']}/payment-status',
        {'payment_status': wasPaid ? 'unpaid' : 'paid'},
      );
      if (context.mounted) {
        reload();
        toast(
            context, wasPaid ? 'Invoice marked unpaid' : 'Invoice marked paid');
      }
    } catch (error) {
      if (context.mounted) toast(context, '$error', error: true);
    }
  }

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
        title: Text(
          '${auth.farmName.trim().isEmpty ? 'Egg Invoice' : auth.farmName.trim()} — Invoice Created',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Total ${money(created['grand_total'])}. Share it with ${created['customer_name']}?'),
            const SizedBox(height: 8),
          ],
        ),
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
      key: ValueKey('invoices-page-$_page'),
      load: () async {
        final results = await Future.wait([
          ApiClient.instance.get('/invoices', query: {
            'page': '$_page',
            'limit': '$_pageSize',
          }),
          ApiClient.instance.get('/eggs/stock'),
          ApiClient.instance.get('/invoices/payment-summary'),
        ]);
        final invoiceResponse = Map<String, dynamic>.from(results[0] as Map);
        return {
          'invoices':
              List<Map<String, dynamic>>.from(invoiceResponse['data'] as List),
          'pagination':
              Map<String, dynamic>.from(invoiceResponse['pagination'] as Map),
          'eggStock': Map<String, dynamic>.from(results[1] as Map),
          'paymentSummary': Map<String, dynamic>.from(results[2] as Map),
        };
      },
      builder: (context, data, reload) {
        final list = data['invoices'] as List<Map<String, dynamic>>;
        final pagination = data['pagination'] as Map<String, dynamic>;
        final total = asI(pagination['total']);
        final totalPages =
            asI(pagination['totalPages']).clamp(1, 999999).toInt();
        if (_page > totalPages) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _page > totalPages) _changePage(totalPages);
          });
        }
        final eggStock = data['eggStock'] as Map<String, dynamic>;
        final paymentSummary = data['paymentSummary'] as Map<String, dynamic>;
        final t = Theme.of(context);
        return Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  PageHeader(
                    title: 'Invoicing & Billing',
                    subtitle: _section == 0
                        ? 'Manage customer invoices'
                        : 'Customer balances and payment history',
                    actions: [
                      if (_section == 0) ...[
                        Pill('Egg stock: ${qty(eggStock['available_eggs'])}',
                            AppColors.primary),
                        Pill(
                          'Pending / Unpaid: ${money(paymentSummary['pending_amount'])}',
                          AppColors.yolk,
                        ),
                        FilledButton.icon(
                          onPressed: () => _create(
                              context, reload, asD(eggStock['available_eggs'])),
                          icon: const Icon(Icons.add),
                          label: const Text('New invoice'),
                        ),
                      ],
                    ],
                  ),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('All Bills'),
                        icon: Icon(Icons.receipt_long_outlined),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Customers Khata'),
                        icon: Icon(Icons.menu_book_outlined),
                      ),
                    ],
                    selected: {_section},
                    onSelectionChanged: (value) => setState(() {
                      _section = value.first;
                    }),
                  ),
                  const SizedBox(height: 14),
                  if (_section == 1)
                    const SizedBox(
                      height: 600,
                      child: CustomerKhataList(),
                    )
                  else ...[
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
                                      (i['customer_name'] == null ||
                                              '${i['customer_name']}'
                                                  .trim()
                                                  .isEmpty
                                          ? 'Walk-in Customer'
                                          : '${i['customer_name']}'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.textTheme.titleMedium,
                                    ),
                                  ),
                                  Text(money(i['grand_total']),
                                      style: t.textTheme.titleMedium?.copyWith(
                                          color: t.colorScheme.primary)),
                                ]),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Pill(
                                        kInvoiceTypes[i['invoice_type']] ??
                                            '${i['invoice_type']}',
                                        AppColors.yolk),
                                    Pill(
                                      i['payment_status'] == 'paid'
                                          ? 'Paid'
                                          : 'Unpaid (Pending)',
                                      i['payment_status'] == 'paid'
                                          ? AppColors.primary
                                          : AppColors.yolk,
                                    ),
                                    Text(
                                        '${fmtDate(i['invoice_date'])}  •  ${i['items_count']} items',
                                        style: t.textTheme.bodySmall
                                            ?.copyWith(color: t.hintColor)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(spacing: 8, runSpacing: 4, children: [
                                  OutlinedButton.icon(
                                      onPressed: () => openPdf(context, i),
                                      icon: const Icon(Icons.picture_as_pdf,
                                          size: 18),
                                      label: const Text('PDF')),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF25D366),
                                        foregroundColor: Colors.white),
                                    onPressed: () =>
                                        sendWhatsApp(context, i, auth.farmName),
                                    icon: const Icon(Icons.send, size: 18),
                                    label: const Text('Send via WhatsApp'),
                                  ),
                                  if (i['payment_status'] != 'paid')
                                    OutlinedButton.icon(
                                      onPressed: () => _togglePaymentStatus(
                                          context, i, reload),
                                      icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 18),
                                      label: const Text('Mark Paid'),
                                    )
                                  else
                                    TextButton.icon(
                                      onPressed: () => _togglePaymentStatus(
                                          context, i, reload),
                                      icon: const Icon(Icons.undo_outlined,
                                          size: 18),
                                      label: const Text('Mark Unpaid'),
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: t.colorScheme.error),
                                    onPressed: () async {
                                      if (!await confirmDelete(context,
                                          'invoice ${i['invoice_no']}')) {
                                        return;
                                      }
                                      try {
                                        await ApiClient.instance
                                            .delete('/invoices/${i['id']}');
                                        if (context.mounted) {
                                          toast(context,
                                              'Invoice deleted successfully');
                                          reload();
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          toast(context, '$e', error: true);
                                        }
                                      }
                                    },
                                  ),
                                ]),
                              ]),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (_section == 0 && total > 0)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Previous page',
                        onPressed:
                            _page > 1 ? () => _changePage(_page - 1) : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 56),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Text('$_page / $totalPages'),
                      ),
                      IconButton(
                        tooltip: 'Next page',
                        onPressed: _page < totalPages
                            ? () => _changePage(_page + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Item {
  final desc = TextEditingController();
  final qtyC = TextEditingController(text: '1');
  final price = TextEditingController();
  String eggUnit = 'tray';
  String saleUnit = 'bag';
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
  String _paymentStatus = 'unpaid';
  String _date = today();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _notes = TextEditingController();
  late final TextEditingController _tax = TextEditingController(
      text: widget.defaultTax == 0 ? '' : '${widget.defaultTax}');
  final List<_Item> _items = [_Item()];
  bool _saving = false;
  bool _customerLookupLoading = false;
  Map<String, dynamic>? _matchedCustomer;
  String? _customerLookupError;
  String? _autoFilledCustomerName;
  Timer? _customerLookupTimer;
  int _customerLookupRequest = 0;

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
    _customerLookupTimer?.cancel();
    _name.dispose();
    _mobile.dispose();
    _notes.dispose();
    _tax.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  String _normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits.length == 10 ? digits : '';
  }

  void _onCustomerMobileChanged(String value) {
    _customerLookupTimer?.cancel();
    final request = ++_customerLookupRequest;
    final phone = _normalizePhone(value);
    if (phone.isEmpty) {
      final previousSuggestion = _autoFilledCustomerName;
      setState(() {
        _matchedCustomer = null;
        _customerLookupError = null;
        _customerLookupLoading = false;
      });
      if (previousSuggestion != null &&
          _name.text.trim() == previousSuggestion) {
        _name.clear();
      }
      _autoFilledCustomerName = null;
      return;
    }

    setState(() {
      _matchedCustomer = null;
      _customerLookupError = null;
      _customerLookupLoading = true;
    });
    _customerLookupTimer = Timer(
      const Duration(milliseconds: 300),
      () => _lookupCustomer(phone, request),
    );
  }

  Future<void> _lookupCustomer(String phone, int request) async {
    try {
      final response = Map<String, dynamic>.from(
        await ApiClient.instance.get(
          '/customers',
          query: {'search': phone, 'page': '1', 'limit': '50'},
        ) as Map,
      );
      final customers = List<Map<String, dynamic>>.from(
        (response['data'] as List).map(
          (customer) => Map<String, dynamic>.from(customer as Map),
        ),
      );
      Map<String, dynamic>? match;
      for (final customer in customers) {
        final savedPhone = _normalizePhone(
          '${customer['normalized_phone'] ?? customer['phone'] ?? ''}',
        );
        if (savedPhone == phone) {
          match = customer;
          break;
        }
      }
      if (!mounted ||
          request != _customerLookupRequest ||
          _normalizePhone(_mobile.text) != phone) {
        return;
      }
      final savedName = '${match?['name'] ?? ''}'.trim();
      setState(() {
        _matchedCustomer = match;
        _customerLookupLoading = false;
        if (savedName.isNotEmpty) {
          _name.value = TextEditingValue(
            text: savedName,
            selection: TextSelection.collapsed(offset: savedName.length),
          );
          _autoFilledCustomerName = savedName;
        }
      });
    } catch (error) {
      if (!mounted ||
          request != _customerLookupRequest ||
          _normalizePhone(_mobile.text) != phone) {
        return;
      }
      setState(() {
        _customerLookupLoading = false;
        _customerLookupError = 'Could not check existing Khata: $error';
      });
    }
  }

  void _useMatchedCustomerName() {
    final name = '${_matchedCustomer?['name'] ?? ''}'.trim();
    if (name.isEmpty) return;
    _name.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    _autoFilledCustomerName = name;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final request = {
        'invoice_type': _type,
        'customer_name': _name.text.trim(),
        'customer_mobile': _mobile.text.trim(),
        'invoice_date': _date,
        'payment_status': _paymentStatus,
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
              'sale_unit': _type == 'poultry_manure_sale' ? i.saleUnit : null,
            }
        ],
      };
      dynamic res;
      try {
        res = await ApiClient.instance.post('/invoices', request);
      } on ApiException catch (error) {
        if (error.code != 'SUBSCRIPTION_REQUIRED' &&
            error.code != 'PAYMENT_PENDING') {
          rethrow;
        }
        if (!mounted) return;
        if (mounted) setState(() => _saving = false);
        final activated = await showSubscriptionPaywall(
          context,
          paymentPending: error.code == 'PAYMENT_PENDING',
        );
        if (!activated || !mounted) return;
        setState(() => _saving = true);
        res = await ApiClient.instance.post('/invoices', request);
      }
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
                initialValue: _type,
                isExpanded: true,
                itemHeight: null,
                decoration: dec(context, 'Invoice type'),
                items: [
                  for (final e in kInvoiceTypes.entries)
                    DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, softWrap: true, maxLines: 3),
                    )
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
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: dec(context, 'Customer WhatsApp number',
                    hint: '9876543210', icon: Icons.phone_outlined),
                onChanged: _onCustomerMobileChanged,
                validator: (value) => RegExp(r'^[6-9]\d{9}$')
                        .hasMatch(value ?? '')
                    ? null
                    : 'कृपया वैध १० अंकी मोबाईल नंबर टाका (उदा. 9876543210) / Please enter a valid 10-digit mobile number',
              ),
              if (_customerLookupLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_matchedCustomer != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: InputChip(
                      avatar: const Icon(Icons.link, size: 18),
                      label: Text(
                        'Existing Khata: ${_matchedCustomer!['name']}',
                      ),
                      onPressed: _useMatchedCustomerName,
                    ),
                  ),
                ),
              if (_customerLookupError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _customerLookupError!,
                    style: TextStyle(color: t.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              DatePickerField(
                  label: 'Invoice date',
                  value: _date,
                  onChanged: (v) => setState(() => _date = v)),
              const SizedBox(height: 12),
              Text('Payment status', style: t.textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _paymentStatus == 'unpaid'
                            ? AppColors.yolk
                            : t.colorScheme.surfaceContainerHighest,
                        foregroundColor: _paymentStatus == 'unpaid'
                            ? Colors.white
                            : t.colorScheme.onSurface,
                      ),
                      onPressed: () =>
                          setState(() => _paymentStatus = 'unpaid'),
                      icon: const Icon(Icons.schedule_outlined),
                      label: const Text('Unpaid'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _paymentStatus == 'paid'
                            ? AppColors.primary
                            : t.colorScheme.surfaceContainerHighest,
                        foregroundColor: _paymentStatus == 'paid'
                            ? Colors.white
                            : t.colorScheme.onSurface,
                      ),
                      onPressed: () => setState(() => _paymentStatus = 'paid'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Paid'),
                    ),
                  ),
                ],
              ),
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
                          initialValue: _items[idx].eggUnit,
                          decoration: dec(context, 'Egg billing unit'),
                          items: const [
                            DropdownMenuItem(
                                value: 'eggs', child: Text('Individual eggs')),
                            DropdownMenuItem(
                                value: 'tray', child: Text('Tray (30 eggs)')),
                          ],
                          onChanged: (value) => setState(
                              () => _items[idx].eggUnit = value ?? 'tray'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_type == 'poultry_manure_sale') ...[
                        DropdownButtonFormField<String>(
                          initialValue: _items[idx].saleUnit,
                          isExpanded: true,
                          decoration: dec(context, 'Sale unit'),
                          items: [
                            for (final unit in _manureSaleUnits.entries)
                              DropdownMenuItem(
                                value: unit.key,
                                child: Text(unit.value),
                              ),
                          ],
                          onChanged: (value) => setState(
                            () => _items[idx].saleUnit = value ?? 'bag',
                          ),
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
                                        : 'Trays')
                                    : _type == 'poultry_manure_sale'
                                        ? 'Quantity'
                                        : 'Qty'),
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              final basic = posNum(value);
                              if (basic != null) return basic;
                              if (_type == 'egg_sale' &&
                                  asD(value) != asD(value).roundToDouble()) {
                                return 'Enter a whole number';
                              }
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
                                    : _type == 'poultry_manure_sale'
                                        ? 'Rate / unit (₹)'
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
                            '(${money(asD(_items[idx].price.text) * 30)}/tray)',
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
                color: t.colorScheme.primary.withValues(alpha: .08),
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
