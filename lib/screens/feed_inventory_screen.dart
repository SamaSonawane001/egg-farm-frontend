import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/form_dialog.dart';

class FeedInventoryScreen extends StatelessWidget {
  const FeedInventoryScreen({super.key});

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait([
      ApiClient.instance.get('/feed/products'),
      ApiClient.instance.get('/feed/stock'),
    ]);
    return {
      'products': List<Map<String, dynamic>>.from(results[0] as List),
      'stock': Map<String, dynamic>.from(results[1] as Map),
    };
  }

  Future<void> _productForm(BuildContext context, {Map<String, dynamic>? product}) async {
    final saved = await showFormDialog(
      context,
      title: product == null ? 'Add Feed Product' : 'Edit feed product',
      initial: product == null ? {} : {'name': product['name']},
      fields: const [FieldSpec('name', 'Product / feed name', hint: 'e.g. Soya, Maka, Layer Mash')],
      onSubmit: (values) async {
        final body = {'name': values['name']};
        if (product == null) {
          await ApiClient.instance.post('/feed/products', body);
        } else {
          await ApiClient.instance.put('/feed/products/${product['id']}', body);
        }
      },
    );
    if (saved && context.mounted) toast(context, product == null ? 'Feed product added' : 'Product name updated');
  }

  Future<void> _deleteProduct(BuildContext context, Map<String, dynamic> product) async {
    if (!await confirmDelete(context, 'feed product "${product['name']}" and its delivery and usage history')) return;
    try {
      await ApiClient.instance.delete('/feed/products/${product['id']}');
      if (context.mounted) toast(context, 'Feed product deleted');
    } catch (error) {
      if (context.mounted) toast(context, '$error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => DataLoader<Map<String, dynamic>>(
        load: _load,
        builder: (context, data, reload) {
          final products = data['products'] as List<Map<String, dynamic>>;
          final stock = data['stock'] as Map<String, dynamic>;
          final kgPerBag = asD(stock['kg_per_bag']) > 0 ? asD(stock['kg_per_bag']) : 50.0;
          final theme = Theme.of(context);
          return ListView(padding: const EdgeInsets.all(16), children: [
            PageHeader(
              title: 'Feed Inventory',
              subtitle: 'Product-wise live stock, purchase and consumption tracking',
              actions: [FilledButton.icon(onPressed: () => _productForm(context), icon: const Icon(Icons.add), label: const Text('Add Feed Product'))],
            ),
            if (products.isEmpty)
              const EmptyState(
                icon: Icons.inventory_2_outlined,
                text: "No feed products added yet. Click '+ Add Feed Product' to begin.",
              )
            else
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 580 ? 2 : 1;
                final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final product in products)
                      SizedBox(
                        width: width,
                        child: AppCard(
                          padding: EdgeInsets.zero,
                          child: Column(children: [
                            InkWell(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                              onTap: () => context.push('/feed/${product['id']}'),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                                child: Row(children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary.withOpacity(.12),
                                    child: const Icon(Icons.grass_outlined, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text('${product['name']}', style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  const Icon(Icons.chevron_right),
                                ]),
                              ),
                            ),
                            InkWell(
                              onTap: () => context.push('/feed/${product['id']}'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${qty(product['remaining_bags'])} bags in stock', style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.primary)),
                                  Text('≈ ${qty(asD(product['remaining_bags']) * kgPerBag)} kg live stock', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: LinearProgressIndicator(
                                      minHeight: 7,
                                      value: asD(product['purchased_bags']) <= 0
                                          ? 0
                                          : (asD(product['remaining_bags']) / asD(product['purchased_bags'])).clamp(0, 1),
                                      backgroundColor: theme.colorScheme.outline.withOpacity(.2),
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(child: _Metric(label: 'Purchased', value: '${qty(product['purchased_bags'])} bags')),
                                    Expanded(child: _Metric(label: 'Consumed', value: '${qty(product['consumed_bags'])} bags')),
                                  ]),
                                ]),
                              ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(children: [
                                const Spacer(),
                                TextButton.icon(onPressed: () => _productForm(context, product: product), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit name')),
                                IconButton(
                                  tooltip: 'Delete product',
                                  onPressed: () => _deleteProduct(context, product),
                                  icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                  ],
                );
              }),
          ]);
        },
      );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).hintColor)),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ]);
}
