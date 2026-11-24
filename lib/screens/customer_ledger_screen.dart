import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/form_dialog.dart';

const _paymentModes = <MapEntry<String, String>>[
  MapEntry('Cash', 'Cash'),
  MapEntry('UPI / Online', 'UPI / Online'),
  MapEntry('Bank Transfer', 'Bank Transfer'),
];

class CustomerKhataList extends StatefulWidget {
  const CustomerKhataList({super.key});

  @override
  State<CustomerKhataList> createState() => _CustomerKhataListState();
}

class _CustomerKhataListState extends State<CustomerKhataList> {
  String _search = '';
  int _page = 1;

  Future<Map<String, dynamic>> _load() async =>
      Map<String, dynamic>.from(await ApiClient.instance.get(
        '/customers',
        query: {
          'search': _search,
          'page': '$_page',
          'limit': '10',
        },
      ) as Map);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          TextField(
            onChanged: (value) => setState(() {
              _search = value.trim();
              _page = 1;
            }),
            decoration: dec(
              context,
              'Search customer name or mobile number',
              icon: Icons.search,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: DataLoader<Map<String, dynamic>>(
              key: ValueKey('$_search-$_page'),
              load: _load,
              builder: (context, response, reload) {
                final customers =
                    List<Map<String, dynamic>>.from(response['data'] as List);
                final pagination =
                    Map<String, dynamic>.from(response['pagination'] as Map);
                final totalPages =
                    asI(pagination['totalPages']).clamp(1, 999999).toInt();
                if (_page > totalPages) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _page > totalPages) {
                      setState(() => _page = totalPages);
                    }
                  });
                }
                return Column(
                  children: [
                    Expanded(
                      child: customers.isEmpty
                          ? const EmptyState(
                              icon: Icons.people_outline,
                              text:
                                  'No customers found. Create an invoice to add one.',
                            )
                          : ListView(
                              children: [
                                for (final customer in customers)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _CustomerCard(customer: customer),
                                  ),
                              ],
                            ),
                    ),
                    if (totalPages > 1)
                      _CompactPager(
                        page: _page,
                        totalPages: totalPages,
                        onPageChanged: (page) => setState(() => _page = page),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      );
}

class _CustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _CustomerCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final pending = asD(customer['pending_balance']);
    final color = pending > 0.005 ? AppColors.danger : AppColors.primary;
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/customers/${customer['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${customer['name']}',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text('${customer['phone']}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Pill(
                        pending > 0.005
                            ? 'Balance ${money(pending)}'
                            : 'Settled',
                        color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Metric(
                      label: 'Eggs bought', value: qty(customer['total_eggs'])),
                  _Metric(
                      label: 'Billed', value: money(customer['total_billed'])),
                  _Metric(label: 'Paid', value: money(customer['total_paid'])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          SizedBox(
            width: 110,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: Theme.of(context).textTheme.titleSmall),
            ),
          ),
        ],
      );
}

class _CompactPager extends StatelessWidget {
  final int page;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const _CompactPager({
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 56),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text('$page / $totalPages'),
              ),
              IconButton(
                tooltip: 'Next page',
                onPressed:
                    page < totalPages ? () => onPageChanged(page + 1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      );
}

class CustomerLedgerScreen extends StatefulWidget {
  final String customerId;
  const CustomerLedgerScreen({super.key, required this.customerId});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  String _period = 'all';
  int _page = 1;

  Future<Map<String, dynamic>> _load() async {
    final response = Map<String, dynamic>.from(await ApiClient.instance.get(
      '/customers/${widget.customerId}/ledger',
      query: {'period': _period, 'page': '$_page', 'limit': '10'},
    ) as Map);
    return {
      ...Map<String, dynamic>.from(response['data'] as Map),
      'pagination': Map<String, dynamic>.from(response['pagination'] as Map),
    };
  }

  Future<void> _receivePayment(
    Map<String, dynamic> data,
    VoidCallback reload,
  ) async {
    final customer = data['customer'] as Map<String, dynamic>;
    final summary = data['summary'] as Map<String, dynamic>;
    final openInvoices =
        List<Map<String, dynamic>>.from(data['open_invoices'] as List);
    final balance = asD(summary['pending_balance']);
    if (balance <= 0.005) {
      toast(context, 'This customer has no pending balance.');
      return;
    }
    final options = [
      const MapEntry('', 'General customer balance'),
      for (final invoice in openInvoices)
        MapEntry(
          '${invoice['id']}',
          '${invoice['invoice_no']} · Due ${money(invoice['balance'])}',
        ),
    ];
    final saved = await showFormDialog(
      context,
      title: 'Receive Payment · पैसे जमा करा',
      fields: [
        FieldSpec(
          'amount_paid',
          'Amount received (₹)',
          type: FieldType.number,
          validator: (value, _) {
            final invalid = decimalValueError(value,
                maxDecimalPlaces: 2, mustBePositive: true);
            if (invalid != null) return invalid;
            final amount = double.tryParse(value ?? '');
            if (amount != null && amount > balance + 0.005) {
              return 'Amount exceeds pending balance ${money(balance)}';
            }
            return null;
          },
        ),
        FieldSpec(
          'invoice_id',
          'Apply to invoice (optional)',
          type: FieldType.select,
          required: false,
          options: options,
        ),
        const FieldSpec(
          'payment_date',
          'Payment date',
          type: FieldType.date,
        ),
        const FieldSpec(
          'payment_mode',
          'Payment mode',
          type: FieldType.select,
          options: _paymentModes,
        ),
        const FieldSpec('note', 'Note (optional)',
            type: FieldType.multiline, required: false),
      ],
      onSubmit: (values) async {
        await ApiClient.instance.post(
          '/customers/${customer['id']}/payments',
          {
            'amount_paid': double.parse(values['amount_paid']!),
            'invoice_id': values['invoice_id']?.isEmpty == true
                ? null
                : values['invoice_id'],
            'payment_date': values['payment_date'],
            'payment_mode': values['payment_mode'],
            'note': values['note'],
          },
        );
      },
    );
    if (saved && mounted) {
      reload();
      toast(context, 'Payment received');
    }
  }

  Future<void> _deletePayment(
    Map<String, dynamic> entry,
    VoidCallback reload,
  ) async {
    if (!await confirmDelete(context, 'this payment')) return;
    try {
      await ApiClient.instance.delete(
        '/customers/${widget.customerId}/payments/${entry['id']}',
      );
      if (mounted) {
        reload();
        toast(context, 'Payment deleted');
      }
    } catch (error) {
      if (mounted) toast(context, '$error', error: true);
    }
  }

  Future<void> _sendSummary(
    Map<String, dynamic> customer,
    Map<String, dynamic> summary,
    Map<String, dynamic>? latestInvoice,
  ) async {
    var phone = '${customer['phone']}'.replaceAll(RegExp(r'\D'), '');
    if (phone.length == 10) phone = '91$phone';
    final balance = asD(summary['pending_balance']);
    final invoicePdf = latestInvoice == null
        ? ''
        : '\nLatest invoice (${latestInvoice['invoice_no']}):\n'
            '${publicInvoicePdfUrl('${latestInvoice['id']}')}';
    final message = '*${customer['name']} · Customer Khata*\n'
        'Mobile: ${customer['phone']}\n'
        'Total eggs: ${qty(summary['total_eggs'])}\n'
        'Total billed: ${money(summary['total_billed'])}\n'
        'Total received: ${money(summary['total_paid'])}\n'
        'Pending balance: ${money(balance)}$invoicePdf';
    try {
      final uri = Uri.https('api.whatsapp.com', '/send', {
        'phone': phone,
        'text': message,
      });
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('WhatsApp could not be opened');
      }
    } catch (error) {
      if (mounted) toast(context, '$error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => DataLoader<Map<String, dynamic>>(
        key: ValueKey('${widget.customerId}-$_period-$_page'),
        load: _load,
        builder: (context, data, reload) {
          final customer = data['customer'] as Map<String, dynamic>;
          final summary = data['summary'] as Map<String, dynamic>;
          final pagination = data['pagination'] as Map<String, dynamic>;
          final totalPages =
              asI(pagination['totalPages']).clamp(1, 999999).toInt();
          if (_page > totalPages) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _page > totalPages) {
                setState(() => _page = totalPages);
              }
            });
          }
          final entries =
              List<Map<String, dynamic>>.from(data['entries'] as List);
          final balance = asD(summary['pending_balance']);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${customer['name']} • Khata Book',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                '${customer['phone']}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context).hintColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _CompactSummaryCard(
                            icon: Icons.receipt_long_outlined,
                            label:
                                'Billed · ${qty(summary['total_eggs'])} eggs',
                            value: money(summary['total_billed']),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CompactSummaryCard(
                            icon: Icons.payments_outlined,
                            label: 'Received',
                            value: money(summary['total_paid']),
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CompactSummaryCard(
                            icon: Icons.pending_actions_outlined,
                            label: 'Pending',
                            value: money(balance),
                            color: balance > 0.005
                                ? AppColors.danger
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8)),
                            onPressed: () => _receivePayment(data, reload),
                            icon: const Icon(Icons.add_card, size: 18),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Receive Payment'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8)),
                            onPressed: () => _sendSummary(
                                customer,
                                summary,
                                data['latest_invoice'] == null
                                    ? null
                                    : Map<String, dynamic>.from(
                                        data['latest_invoice'] as Map)),
                            icon: const Icon(Icons.send_outlined, size: 18),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('WhatsApp Summary'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'daily', label: Text('Daily')),
                        ButtonSegment(value: 'weekly', label: Text('Weekly')),
                        ButtonSegment(value: 'monthly', label: Text('Monthly')),
                      ],
                      selected: {_period},
                      onSelectionChanged: (values) => setState(() {
                        _period = values.first;
                        _page = 1;
                      }),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Row(
                        children: [
                          const Expanded(child: Text('Date · Details')),
                          Text(
                            'Bill / Paid',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (entries.isEmpty)
                      const EmptyState(
                        icon: Icons.menu_book_outlined,
                        text: 'No bills or payments in this period.',
                      ),
                    for (final entry in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _LedgerEntry(
                          entry: entry,
                          onDelete: entry['entry_type'] == 'payment'
                              ? () => _deletePayment(entry, reload)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
              if (totalPages > 1)
                _CompactPager(
                  page: _page,
                  totalPages: totalPages,
                  onPageChanged: (page) => setState(() => _page = page),
                ),
            ],
          );
        },
      );
}

class _CompactSummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _CompactSummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: accent),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: theme.textTheme.titleSmall),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerEntry extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback? onDelete;
  const _LedgerEntry({required this.entry, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final payment = entry['entry_type'] == 'payment';
    final t = Theme.of(context);
    final paid = asD(entry['paid_amount']);
    final billed = asD(entry['billed_amount']);
    final isPaid = paid >= billed - 0.005;
    final isPartial = paid > 0.005 && !isPaid;
    final invoiceType = switch ('${entry['invoice_type']}') {
      'egg_sale' => 'Egg Sale',
      'spent_hen_sale' => 'Spent Hen Sale',
      'feed_trade' => 'Feed Trade',
      _ => 'Invoice',
    };
    final eggCount = asD(entry['egg_quantity']);
    final itemCount = asD(entry['item_quantity']);
    final rate = asD(entry['unit_rate']);
    final billTitle = '${entry['invoice_type']}' == 'egg_sale'
        ? 'EGGS TAKEN • ${qty(eggCount)} Eggs${rate > 0 ? ' @ ${money(rate)}' : ''}'
        : '$invoiceType${itemCount > 0 ? ' • ${qty(itemCount)}${rate > 0 ? ' @ ${money(rate)}' : ''}' : ''}';
    final accent = payment ? AppColors.primary : AppColors.yolk;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 56,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .75),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          CircleAvatar(
            backgroundColor: accent.withValues(alpha: .12),
            child: Icon(
              payment ? Icons.payments_outlined : Icons.receipt_long_outlined,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment
                      ? 'PAYMENT RECEIVED • ${entry['payment_mode'] ?? 'Cash'}'
                      : billTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.titleSmall,
                ),
                Text(
                  '${fmtDate(entry['entry_date'])}'
                  '${payment && entry['note'] != null && '${entry['note']}'.isNotEmpty ? ' · ${entry['note']}' : ''}',
                  style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (payment)
                SizedBox(
                  width: 118,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '- ${money(paid)} Paid',
                      style: t.textTheme.titleSmall
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ),
                )
              else ...[
                SizedBox(
                  width: 118,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '+ ${money(billed)} Bill',
                      style: t.textTheme.titleSmall
                          ?.copyWith(color: AppColors.yolk),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Pill(
                    isPaid
                        ? 'Paid (जमा)'
                        : isPartial
                            ? 'Partial'
                            : 'Unpaid (बाकी)',
                    isPaid
                        ? AppColors.primary
                        : isPartial
                            ? AppColors.yolk
                            : AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
          if (payment && onDelete != null)
            IconButton(
              tooltip: 'Delete payment',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline, color: t.colorScheme.error),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
