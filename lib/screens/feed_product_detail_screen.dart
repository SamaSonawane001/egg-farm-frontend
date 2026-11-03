import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/form_dialog.dart';

class FeedProductDetailScreen extends StatefulWidget {
  final String productId;
  const FeedProductDetailScreen({super.key, required this.productId});

  @override
  State<FeedProductDetailScreen> createState() =>
      _FeedProductDetailScreenState();
}

class _FeedProductDetailScreenState extends State<FeedProductDetailScreen> {
  String _month = DateTime.now().toIso8601String().substring(0, 7);
  int _tab = 0;
  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait([
      _api.get('/feed/products/${widget.productId}', query: {'month': _month}),
      _api.get('/feed/stock'),
      _api.get('/flock/batches'),
    ]);
    return {
      'product': Map<String, dynamic>.from(results[0] as Map),
      'stock': Map<String, dynamic>.from(results[1] as Map),
      'batches': List<Map<String, dynamic>>.from(results[2] as List),
    };
  }

  Future<void> _purchaseForm(Map<String, dynamic> product,
      {Map<String, dynamic>? purchase}) async {
    final saved = await showFormDialog(
      context,
      title: purchase == null
          ? 'Add delivery • ${product['name']}'
          : 'Edit delivery',
      initial: purchase ?? {},
      fields: const [
        FieldSpec('delivery_date', 'Delivery date', type: FieldType.date),
        FieldSpec('bags', 'Bags received', type: FieldType.number),
        FieldSpec('cost_per_bag', 'Rate per bag', type: FieldType.number),
      ],
      preview: (values) =>
          'Total cost: ${money(asD(values['bags']) * asD(values['cost_per_bag']))}',
      onSubmit: (values) async {
        final body = {
          'feed_product_id': widget.productId,
          'delivery_date': values['delivery_date'],
          'bags': double.parse(values['bags']!),
          'cost_per_bag': double.parse(values['cost_per_bag']!),
        };
        if (purchase == null) {
          await _api.post('/feed/purchases', body);
        } else {
          await _api.put('/feed/purchases/${purchase['id']}', body);
        }
      },
    );
    if (saved && mounted)
      toast(context, purchase == null ? 'Delivery added' : 'Delivery updated');
  }

  Future<void> _usageForm(
    Map<String, dynamic> product,
    Map<String, dynamic> stock,
    List<Map<String, dynamic>> batches, {
    Map<String, dynamic>? usage,
  }) async {
    final kgPerBag =
        asD(stock['kg_per_bag']) > 0 ? asD(stock['kg_per_bag']) : 50.0;
    final available = asD(product['remaining_bags']) +
        (usage == null ? 0 : asD(usage['bags_equivalent']));
    final saved = await showFormDialog(
      context,
      title: usage == null ? 'Log usage • ${product['name']}' : 'Edit usage',
      initial: {
        ...?usage,
        'feed_product_id': widget.productId,
        if (usage != null && usage['batch_id'] == null) 'batch_id': ''
      },
      fields: [
        const FieldSpec('usage_date', 'Date', type: FieldType.date),
        FieldSpec('batch_id', 'Flock batch',
            type: FieldType.select,
            required: false,
            options: [
              const MapEntry('', 'All / not specified'),
              for (final batch in batches)
                MapEntry('${batch['id']}', '${batch['batch_name']}'),
            ]),
        FieldSpec('quantity', 'Quantity used', type: FieldType.number,
            validator: (value, values) {
          final quantity = double.tryParse((value ?? '').trim());
          if (quantity == null) return null;
          final bags = values['unit'] == 'kg' ? quantity / kgPerBag : quantity;
          return bags > available + 0.0005
              ? 'Only ${qty(available)} bags (${qty(available * kgPerBag)} kg) available'
              : null;
        }),
        const FieldSpec('unit', 'Unit',
            type: FieldType.select,
            options: [MapEntry('bags', 'Bags'), MapEntry('kg', 'Kilograms')]),
      ],
      preview: (values) =>
          'Available: ${qty(available)} bags  •  ${qty(available * kgPerBag)} kg',
      onSubmit: (values) async {
        final body = {
          'feed_product_id': widget.productId,
          'usage_date': values['usage_date'],
          'batch_id': values['batch_id']!.isEmpty ? null : values['batch_id']!,
          'quantity': double.parse(values['quantity']!),
          'unit': values['unit'],
        };
        if (usage == null) {
          await _api.post('/feed/usage', body);
        } else {
          await _api.put('/feed/usage/${usage['id']}', body);
        }
      },
    );
    if (saved && mounted)
      toast(
          context, usage == null ? 'Feed usage logged' : 'Feed usage updated');
  }

  Future<void> _delete(String path, String description) async {
    if (!await confirmDelete(context, description)) return;
    try {
      await _api.delete(path);
      if (mounted) toast(context, 'Record deleted');
    } catch (error) {
      if (mounted) toast(context, '$error', error: true);
    }
  }

  Future<void> _selectMonth() async {
    final current = DateTime.tryParse('$_month-01') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Choose a date in the month to view',
    );
    if (picked != null)
      setState(() => _month =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}');
  }

  @override
  Widget build(BuildContext context) => DataLoader<Map<String, dynamic>>(
        key: ValueKey('${widget.productId}-$_month'),
        load: _load,
        builder: (context, data, reload) {
          final product = data['product'] as Map<String, dynamic>;
          final stock = data['stock'] as Map<String, dynamic>;
          final batches = data['batches'] as List<Map<String, dynamic>>;
          final purchases =
              List<Map<String, dynamic>>.from(product['purchases'] as List);
          final allUsage =
              List<Map<String, dynamic>>.from(product['usage'] as List);
          final usage = allUsage
              .where((row) => '${row['usage_date']}'.startsWith(_month))
              .toList();
          var purchasesHaveMore = product['purchases_has_more'] == true;
          var usageHasMore = product['usage_has_more'] == true;
          var loadingMore = false;
          final kgPerBag =
              asD(stock['kg_per_bag']) > 0 ? asD(stock['kg_per_bag']) : 50.0;
          final theme = Theme.of(context);
          return StatefulBuilder(
              builder: (context, setLocalState) =>
                  ListView(padding: const EdgeInsets.all(16), children: [
                    Row(children: [
                      IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back)),
                      Expanded(
                          child: PageHeader(
                              title: '${product['name']} Inventory',
                              subtitle:
                                  'Product-wise purchase and consumption history')),
                    ]),
                    LayoutBuilder(builder: (context, box) {
                      final columns = box.maxWidth >= 760 ? 3 : 1;
                      final width = columns == 1
                          ? box.maxWidth
                          : (box.maxWidth - 24) / columns;
                      return Wrap(spacing: 12, runSpacing: 12, children: [
                        SizedBox(
                            width: width,
                            child: StatCard(
                                icon: Icons.inventory_2_outlined,
                                label: 'Live remaining stock',
                                value: '${qty(product['remaining_bags'])} bags',
                                sub:
                                    '${qty(asD(product['remaining_bags']) * kgPerBag)} kg')),
                        SizedBox(
                            width: width,
                            child: StatCard(
                                icon: Icons.payments_outlined,
                                label: 'Total spent to date',
                                value: money(product['total_spent']),
                                color: AppColors.info)),
                        SizedBox(
                            width: width,
                            child: StatCard(
                                icon: Icons.restaurant_outlined,
                                label: 'Used in $_month',
                                value:
                                    '${qty(product['monthly_used_bags'])} bags')),
                      ]);
                    }),
                    const SizedBox(height: 18),
                    ResponsiveHistoryTabs(
                      tabs: const [
                        ResponsiveHistoryTab(
                          label: 'Purchase & delivery history',
                          mobileLabel: 'Purchases & deliveries',
                          icon: Icons.local_shipping_outlined,
                        ),
                        ResponsiveHistoryTab(
                          label: 'Usage & consumption',
                          mobileLabel: 'Usage & consumption',
                          icon: Icons.restaurant_outlined,
                        ),
                      ],
                      selected: _tab,
                      onChanged: (value) => setState(() => _tab = value),
                    ),
                    const SizedBox(height: 14),
                    if (_tab == 0) ...[
                      PageHeader(title: 'Deliveries', actions: [
                        FilledButton.icon(
                            onPressed: () => _purchaseForm(product),
                            icon: const Icon(Icons.add),
                            label: const Text('Add delivery'))
                      ]),
                      if (purchases.isEmpty)
                        const EmptyState(
                            icon: Icons.local_shipping_outlined,
                            text: 'No deliveries for this product yet.'),
                      for (final purchase in purchases)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                              child: Row(children: [
                            const Icon(Icons.inventory_2_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('${qty(purchase['bags'])} bags received',
                                      style: theme.textTheme.titleMedium),
                                  Text(
                                      '${fmtDate(purchase['delivery_date'])} • ${money(purchase['cost_per_bag'])} per bag',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: theme.hintColor)),
                                ])),
                            Text(money(purchase['total_cost']),
                                style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.primary)),
                            IconButton(
                                onPressed: () =>
                                    _purchaseForm(product, purchase: purchase),
                                icon: const Icon(Icons.edit_outlined)),
                            IconButton(
                                onPressed: () => _delete(
                                    '/feed/purchases/${purchase['id']}',
                                    'this delivery'),
                                icon: Icon(Icons.delete_outline,
                                    color: theme.colorScheme.error)),
                          ])),
                        ),
                      if (purchasesHaveMore)
                        Center(
                          child: TextButton.icon(
                            onPressed: loadingMore
                                ? null
                                : () async {
                                    setLocalState(() => loadingMore = true);
                                    try {
                                      final response =
                                          Map<String, dynamic>.from(
                                        await _api.get(
                                          '/feed/products/${widget.productId}',
                                          query: {
                                            'month': _month,
                                            'purchase_offset':
                                                '${purchases.length}',
                                            'usage_offset':
                                                '${allUsage.length}',
                                          },
                                        ) as Map,
                                      );
                                      final page = response;
                                      purchases.addAll(
                                        List<Map<String, dynamic>>.from(
                                            page['purchases'] as List),
                                      );
                                      setLocalState(() {
                                        purchasesHaveMore =
                                            page['purchases_has_more'] == true;
                                        loadingMore = false;
                                      });
                                    } catch (error) {
                                      setLocalState(() => loadingMore = false);
                                      if (context.mounted) {
                                        toast(context, '$error', error: true);
                                      }
                                    }
                                  },
                            icon: loadingMore
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.expand_more),
                            label: Text(loadingMore
                                ? 'Loading...'
                                : 'Load more deliveries'),
                          ),
                        ),
                    ] else ...[
                      ResponsiveSectionHeader(
                        title: 'Usage history',
                        subtitle: 'Selected month: $_month',
                        actions: [
                          TextButton.icon(
                            onPressed: _selectMonth,
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('Change month'),
                          ),
                          FilledButton.icon(
                            onPressed: () =>
                                _usageForm(product, stock, batches),
                            icon: const Icon(Icons.add),
                            label: const Text('Log usage'),
                          ),
                        ],
                      ),
                      AppCard(
                          child: Row(children: [
                        const Icon(Icons.summarize_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text('Total consumed in $_month',
                                style: theme.textTheme.titleSmall)),
                        Text('${qty(product['monthly_used_bags'])} bags',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: theme.colorScheme.primary)),
                      ])),
                      const SizedBox(height: 12),
                      if (usage.isEmpty)
                        const EmptyState(
                            icon: Icons.restaurant_outlined,
                            text: 'No usage records for this month.'),
                      for (final row in usage)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                              child: Row(children: [
                            const Icon(Icons.restaurant_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      '${qty(row['bags_equivalent'])} bags used',
                                      style: theme.textTheme.titleMedium),
                                  Text(
                                      '${fmtDate(row['usage_date'])} • ${row['batch_name'] ?? 'All batches'}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: theme.hintColor)),
                                ])),
                            IconButton(
                                onPressed: () => _usageForm(
                                    product, stock, batches,
                                    usage: row),
                                icon: const Icon(Icons.edit_outlined)),
                            IconButton(
                                onPressed: () => _delete(
                                    '/feed/usage/${row['id']}',
                                    'this usage record'),
                                icon: Icon(Icons.delete_outline,
                                    color: theme.colorScheme.error)),
                          ])),
                        ),
                      if (usageHasMore)
                        Center(
                          child: TextButton.icon(
                            onPressed: loadingMore
                                ? null
                                : () async {
                                    setLocalState(() => loadingMore = true);
                                    try {
                                      final response =
                                          Map<String, dynamic>.from(
                                        await _api.get(
                                          '/feed/products/${widget.productId}',
                                          query: {
                                            'month': _month,
                                            'purchase_offset':
                                                '${purchases.length}',
                                            'usage_offset':
                                                '${allUsage.length}',
                                          },
                                        ) as Map,
                                      );
                                      final page = response;
                                      final usagePage =
                                          List<Map<String, dynamic>>.from(
                                              page['usage'] as List);
                                      allUsage.addAll(usagePage);
                                      usage.addAll(usagePage);
                                      setLocalState(() {
                                        usageHasMore =
                                            page['usage_has_more'] == true;
                                        loadingMore = false;
                                      });
                                    } catch (error) {
                                      setLocalState(() => loadingMore = false);
                                      if (context.mounted) {
                                        toast(context, '$error', error: true);
                                      }
                                    }
                                  },
                            icon: loadingMore
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.expand_more),
                            label: Text(
                                loadingMore ? 'Loading...' : 'Load more usage'),
                          ),
                        ),
                    ],
                  ]));
        },
      );
}
