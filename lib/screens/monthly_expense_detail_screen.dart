import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../widgets/bill_upload_picker.dart';
import '../widgets/common.dart';

const _expenseCategories = [
  'Feed',
  'Raw Materials',
  'Medicines & Health',
  'Birds / Chicks',
];

class MonthlyExpenseDetailScreen extends StatefulWidget {
  final int month;
  final int year;

  const MonthlyExpenseDetailScreen({
    super.key,
    required this.month,
    required this.year,
  });

  @override
  State<MonthlyExpenseDetailScreen> createState() =>
      _MonthlyExpenseDetailScreenState();
}

class _MonthlyExpenseDetailScreenState
    extends State<MonthlyExpenseDetailScreen> {
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  late int _month = widget.month.clamp(1, 12);
  late int _year = widget.year.clamp(2000, 2100);
  final _search = TextEditingController();
  String _searchTerm = '';
  String _categoryFilter = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async =>
      Map<String, dynamic>.from(await ApiClient.instance.get(
        '/expenses/monthly-breakdown',
        query: {'month': '$_month', 'year': '$_year'},
      ));

  void _selectMonth(String value) {
    final parts = value.split('-');
    setState(() {
      _year = int.parse(parts[0]);
      _month = int.parse(parts[1]);
    });
  }

  @override
  Widget build(BuildContext context) => DataLoader<Map<String, dynamic>>(
        key: ValueKey('$_year-$_month'),
        load: _load,
        builder: (context, data, reload) {
          final categories =
              List<Map<String, dynamic>>.from(data['categories'] ?? const []);
          final transactions = List<Map<String, dynamic>>.from(
              data['itemized_transactions'] ?? const []);
          final needle = _searchTerm.trim().toLowerCase();
          final filtered = transactions.where((transaction) {
            final category = '${transaction['category']}';
            return (_categoryFilter == 'All' || category == _categoryFilter) &&
                '${transaction['title']} $category ${transaction['vendor']} ${transaction['date']}'
                    .toLowerCase()
                    .contains(needle);
          }).toList();
          final total = asD(data['total_monthly_expense']);
          final monthOptions = <String>[
            for (var year = _year - 4; year <= _year + 1; year++)
              for (var month = 1; month <= 12; month++)
                '$year-${month.toString().padLeft(2, '0')}',
          ];
          final selectedMonth = '$_year-${_month.toString().padLeft(2, '0')}';
          if (!monthOptions.contains(selectedMonth)) {
            monthOptions.add(selectedMonth);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    'Monthly Expense Breakdown & Analytics',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    value: selectedMonth,
                    isExpanded: true,
                    decoration: dec(context, 'Month'),
                    items: [
                      for (final option in monthOptions)
                        DropdownMenuItem(
                          value: option,
                          child: Text(
                            '${_monthNames[int.parse(option.substring(5)) - 1]} ${option.substring(0, 4)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) _selectMonth(value);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              AppCard(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.trending_down, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Total expenses · ${_monthNames[_month - 1]} $_year',
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(money(total),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(color: AppColors.danger)),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Text('Category Breakdown',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              for (final category in categories)
                _CategoryBreakdownCard(
                  category: category,
                  total: total,
                  selected: _categoryFilter == category['category'],
                  onTap: () => setState(() {
                    _categoryFilter = _categoryFilter == category['category']
                        ? 'All'
                        : '${category['category']}';
                  }),
                ),
              const SizedBox(height: 18),
              Text('Itemized Expenses',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              TextField(
                controller: _search,
                onChanged: (value) => setState(() => _searchTerm = value),
                decoration: dec(context, 'Search items, vendors and categories',
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
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final category in ['All', ..._expenseCategories])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _categoryFilter == category,
                        onSelected: (_) =>
                            setState(() => _categoryFilter = category),
                      ),
                    ),
                ]),
              ),
              if (filtered.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  text: 'No expenses match this month and filter.',
                )
              else
                for (final transaction in filtered)
                  _ExpenseTransactionTile(transaction: transaction),
            ],
          );
        },
      );
}

class _CategoryBreakdownCard extends StatelessWidget {
  final Map<String, dynamic> category;
  final double total;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryBreakdownCard({
    required this.category,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final amount = asD(category['amount']);
    final percentage = asD(category['percentage']);
    final color = category['category'] == 'Birds / Chicks'
        ? AppColors.yolk
        : category['category'] == 'Medicines & Health'
            ? AppColors.info
            : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: selected
            ? color.withValues(alpha: .08)
            : Theme.of(context).colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('${category['category']}',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(money(amount),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('${percentage.toStringAsFixed(1)}%'),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: total <= 0 ? 0 : (amount / total).clamp(0.0, 1.0),
                  color: color,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: .2),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ExpenseTransactionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  const _ExpenseTransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final billUrl = transaction['bill_image_url'] as String?;
    final category = '${transaction['category']}';
    return Card(
      child: ListTile(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${transaction['title']}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Category: $category'),
                  Text('Date: ${fmtDate(transaction['date'])}'),
                  Text('Vendor: ${transaction['vendor'] ?? 'Not recorded'}'),
                  Text('Amount: ${money(transaction['amount'])}'),
                  if (billUrl != null && billUrl.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => showBillPreview(context, billUrl),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('View bill'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        title: Text('${transaction['title']}',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(spacing: 8, runSpacing: 4, children: [
            Text(fmtDate(transaction['date'])),
            Chip(
              label: Text(category),
              visualDensity: VisualDensity.compact,
            ),
            Text('${transaction['vendor'] ?? 'Vendor not recorded'}'),
          ]),
        ),
        trailing: Text(
          money(transaction['amount']),
          style: const TextStyle(
              color: AppColors.danger, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
