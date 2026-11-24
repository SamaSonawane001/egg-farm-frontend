import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/form_dialog.dart';

const _expenseCategories = <MapEntry<String, String>>[
  MapEntry('farm_labour_salary', 'Farm Labour / Salary · फार्म मजूर पगार'),
  MapEntry(
      'feed_truck_unloading_hamali', 'Feed Truck Unloading / Hamali · हमाली'),
  MapEntry('feed_mill_expense', 'Feed Mill Expense · फीड मिल खर्च'),
  MapEntry('electricity_water', 'Electricity & Water · वीज व पाणी'),
  MapEntry('transport_diesel', 'Transport & Diesel · वाहतूक व डिझेल'),
  MapEntry('other_farm_expense', 'Other Farm Expense · इतर खर्च'),
];

const _paymentModes = <MapEntry<String, String>>[
  MapEntry('Cash', 'Cash'),
  MapEntry('UPI / Online', 'UPI / Online'),
  MapEntry('Bank Transfer', 'Bank Transfer'),
];

const _expenseFilters = <MapEntry<String, String>>[
  MapEntry('All', 'All'),
  MapEntry('farm_labour_salary', 'Regular Labour · कायम मजूर'),
  MapEntry('feed_truck_unloading_hamali', 'Feed Unloading · हमाली'),
  MapEntry('feed_mill_expense', 'Feed Mill Maintenance · फीड मिल'),
  MapEntry('electricity_transport', 'Electricity / Diesel · वीज / डिझेल'),
  MapEntry('other_farm_expense', 'Miscellaneous · इतर खर्च'),
];

class FarmExpensesScreen extends StatefulWidget {
  const FarmExpensesScreen({super.key});

  @override
  State<FarmExpensesScreen> createState() => _FarmExpensesScreenState();
}

class _FarmExpensesScreenState extends State<FarmExpensesScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _category = 'All';

  Future<Map<String, dynamic>> _load() async {
    final response = Map<String, dynamic>.from(await ApiClient.instance.get(
      '/farm-expenses',
      query: {
        'month': '${_month.month}',
        'year': '${_month.year}',
        if (_category != 'All') 'category': _category,
      },
    ) as Map);
    return {
      'expenses': List<Map<String, dynamic>>.from(response['expenses'] as List),
      'summary': Map<String, dynamic>.from(response['summary'] as Map),
    };
  }

  void _shiftMonth(int amount) {
    setState(() {
      _month = DateTime(_month.year, _month.month + amount);
    });
  }

  Future<void> _expenseForm(
    VoidCallback reload, {
    Map<String, dynamic>? expense,
  }) async {
    final saved = await showFormDialog(
      context,
      title: expense == null ? 'Add Farm Expense' : 'Edit Farm Expense',
      initial: {
        if (expense != null) ...expense,
        if (expense == null) 'expense_date': today(),
        'unit_rate': '',
      },
      fields: [
        FieldSpec(
          'category',
          'Expense category',
          type: FieldType.select,
          options: _expenseCategories,
        ),
        const FieldSpec('expense_date', 'Date', type: FieldType.date),
        const FieldSpec(
          'person_or_vendor',
          'Person / worker / vendor',
          required: false,
        ),
        const FieldSpec(
          'description',
          'Work / expense description',
          hint: 'e.g. Unloaded maize truck · 200 bags',
        ),
        const FieldSpec(
          'workers_count',
          'Workers / quantity (optional)',
          type: FieldType.integer,
          required: false,
        ),
        const FieldSpec(
          'unit_rate',
          'Rate per worker / unit (optional)',
          type: FieldType.number,
          required: false,
        ),
        FieldSpec(
          'amount',
          'Total amount (₹)',
          type: FieldType.number,
          validator: (value, values) {
            final entered = double.tryParse(value ?? '');
            final count = double.tryParse(values['workers_count'] ?? '');
            final rate = double.tryParse(values['unit_rate'] ?? '');
            if (count != null && rate != null) {
              if (count <= 0 || rate <= 0) {
                return 'Worker count and rate must be greater than zero';
              }
              return null;
            }
            if (entered == null || entered <= 0) {
              return 'Enter an amount or provide both quantity and rate';
            }
            return decimalValueError(value, maxDecimalPlaces: 2);
          },
        ),
        const FieldSpec(
          'payment_mode',
          'Payment mode',
          type: FieldType.select,
          options: _paymentModes,
        ),
      ],
      preview: (values) {
        final count = double.tryParse(values['workers_count'] ?? '');
        final rate = double.tryParse(values['unit_rate'] ?? '');
        final directAmount = double.tryParse(values['amount'] ?? '');
        final computed =
            count != null && rate != null ? count * rate : directAmount ?? 0;
        if (count != null && rate != null) {
          return '${qty(count)} × ${money(rate)} = ${money(computed)}';
        }
        return 'Expense amount: ${money(computed)}';
      },
      onSubmit: (values) async {
        final count = int.tryParse(values['workers_count'] ?? '');
        final rate = double.tryParse(values['unit_rate'] ?? '');
        final enteredAmount = double.tryParse(values['amount'] ?? '');
        final amount =
            count != null && rate != null ? count * rate : enteredAmount!;
        final body = <String, dynamic>{
          'category': values['category'],
          'person_or_vendor': values['person_or_vendor'],
          'description': values['description'],
          'workers_count': count,
          'amount': double.parse(amount.toStringAsFixed(2)),
          'payment_mode': values['payment_mode'],
          'expense_date': values['expense_date'],
        };
        if (expense == null) {
          await ApiClient.instance.post('/farm-expenses', body);
        } else {
          await ApiClient.instance.put('/farm-expenses/${expense['id']}', body);
        }
      },
    );
    if (saved && mounted) {
      reload();
      toast(context,
          expense == null ? 'Farm expense added' : 'Farm expense updated');
    }
  }

  Future<void> _delete(
    Map<String, dynamic> expense,
    VoidCallback reload,
  ) async {
    if (!await confirmDelete(context, 'this farm expense')) return;
    try {
      await ApiClient.instance.delete('/farm-expenses/${expense['id']}');
      if (mounted) {
        reload();
        toast(context, 'Farm expense deleted');
      }
    } catch (error) {
      if (mounted) toast(context, '$error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => DataLoader<Map<String, dynamic>>(
        key: ValueKey('${_month.year}-${_month.month}-$_category'),
        load: _load,
        builder: (context, data, reload) {
          final summary = data['summary'] as Map<String, dynamic>;
          final expenses = data['expenses'] as List<Map<String, dynamic>>;
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PageHeader(
                title: 'Farm Expenses · फार्म खर्च',
                subtitle:
                    'Track labour, feed operations, utilities, and other costs',
                actions: [
                  FilledButton.icon(
                    onPressed: () => _expenseForm(reload),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Farm Expense'),
                  ),
                ],
              ),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760 ? 3 : 1;
                final width = columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 24) / 3;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(
                    width: width,
                    child: StatCard(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Total Farm Expenses (This Month)',
                      value: money(summary['month_total']),
                      color: AppColors.danger,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatCard(
                      icon: Icons.groups_outlined,
                      label: 'Labour & Unloading Wages',
                      value: money(summary['labour_total']),
                      color: AppColors.yolk,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: StatCard(
                      icon: Icons.factory_outlined,
                      label: 'Feed Mill & Other Operations',
                      value: money(summary['operations_total']),
                      color: AppColors.info,
                    ),
                  ),
                ]);
              }),
              const SizedBox(height: 16),
              AppCard(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => _shiftMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                      style: theme.textTheme.titleSmall,
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: () => _shiftMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    const SizedBox(width: 8),
                    for (final item in _expenseFilters)
                      ChoiceChip(
                        label: Text(item.value),
                        selected: _category == item.key,
                        onSelected: (_) => setState(() => _category = item.key),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (expenses.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  text: 'No farm expenses for this month and category.',
                ),
              for (final expense in expenses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ExpenseTile(
                    expense: expense,
                    onEdit: () => _expenseForm(reload, expense: expense),
                    onDelete: () => _delete(expense, reload),
                  ),
                ),
            ],
          );
        },
      );
}

class _ExpenseTile extends StatelessWidget {
  final Map<String, dynamic> expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseTile({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = _expenseCategories
        .firstWhere((item) => item.key == expense['category'])
        .value;
    final person = '${expense['person_or_vendor'] ?? ''}'.trim();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: .12),
                child: const Icon(Icons.receipt_long_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Pill(category, AppColors.info),
                        Text(
                          fmtDate(expense['expense_date']),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${expense['description']}',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      [
                        if (person.isNotEmpty) person,
                        if (expense['workers_count'] != null)
                          '${qty(expense['workers_count'])} workers / units',
                        '${expense['payment_mode']}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                money(expense['amount']),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit expense',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete expense',
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
