import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/form_dialog.dart';

class FeedInventoryScreen extends StatelessWidget {
  const FeedInventoryScreen({super.key});

  Future<Map<String, dynamic>> _load() async {
    Future<List<Map<String, dynamic>>> loadProducts() async {
      try {
        return List<Map<String, dynamic>>.from(
            await ApiClient.instance.get('/feed/products') as List);
      } on ApiException catch (error) {
        if (error.status != 404) rethrow;
        return List<Map<String, dynamic>>.from(
            await ApiClient.instance.get('/feed') as List);
      }
    }

    final results = await Future.wait<dynamic>([
      loadProducts(),
      ApiClient.instance.get('/feed/stock').catchError((Object error) {
        if (error is ApiException && error.status == 404) {
          return <String, dynamic>{'kg_per_bag': 50};
        }
        throw error;
      }),
    ]);
    final products = List<Map<String, dynamic>>.from(results[0] as List);
    final hasReadyFeed = products.any(
        (product) => '${product['name']}'.trim().toLowerCase() == 'ready feed');
    if (!hasReadyFeed) {
      products.add({
        'id': null,
        'name': 'Ready Feed',
        'purchased_bags': 0,
        'consumed_bags': 0,
        'remaining_bags': 0,
        'total_spent': 0,
        'legacy_ready_feed': true,
      });
    }
    products.sort((a, b) {
      final aReady = '${a['name']}'.trim().toLowerCase() == 'ready feed';
      final bReady = '${b['name']}'.trim().toLowerCase() == 'ready feed';
      if (aReady != bReady) return aReady ? -1 : 1;
      return '${a['name']}'
          .toLowerCase()
          .compareTo('${b['name']}'.toLowerCase());
    });
    return {
      'products': products,
      'stock': Map<String, dynamic>.from(results[1] as Map),
    };
  }

  Future<void> _productForm(
    BuildContext context, {
    Map<String, dynamic>? product,
    required VoidCallback reload,
  }) async {
    final saved = await showFormDialog(
      context,
      title: product == null ? 'Add Feed Product' : 'Edit feed product',
      initial: product == null ? {} : {'name': product['name']},
      fields: const [
        FieldSpec('name', 'Product / feed name',
            hint: 'e.g. Soya, Maka, Layer Mash')
      ],
      onSubmit: (values) async {
        if ('${values['name']}'.trim().toLowerCase() == 'ready feed') {
          throw StateError('Ready Feed is a permanent system product');
        }
        final body = {'name': values['name']};
        if (product == null) {
          await ApiClient.instance.post('/feed/products', body);
        } else {
          await ApiClient.instance.put('/feed/products/${product['id']}', body);
        }
      },
    );
    if (saved && context.mounted) {
      reload();
      toast(context,
          product == null ? 'Feed product added' : 'Product name updated');
    }
  }

  Future<void> _deleteProduct(
    BuildContext context,
    Map<String, dynamic> product,
    VoidCallback reload,
  ) async {
    if (!await confirmDelete(context,
        'feed product "${product['name']}" and its delivery and usage history')) {
      return;
    }
    try {
      await ApiClient.instance.delete('/feed/products/${product['id']}');
      if (context.mounted) {
        reload();
        toast(context, 'Feed product deleted');
      }
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
          final kgPerBag =
              asD(stock['kg_per_bag']) > 0 ? asD(stock['kg_per_bag']) : 50.0;
          final theme = Theme.of(context);
          return ListView(padding: const EdgeInsets.all(16), children: [
            PageHeader(
              title: 'Feed Inventory',
              subtitle:
                  'Product-wise live stock, purchase and consumption tracking',
              actions: [
                FilledButton.icon(
                    onPressed: () => _productForm(context, reload: reload),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Feed Product'))
              ],
            ),
            if (products.isEmpty)
              const EmptyState(
                icon: Icons.inventory_2_outlined,
                text:
                    "No feed products added yet. Click '+ Add Feed Product' to begin.",
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
                    for (final product in products)
                      SizedBox(
                        width: width,
                        child: _feedCard(
                          context,
                          product,
                          kgPerBag,
                          theme,
                          reload,
                        ),
                      ),
                  ],
                );
              }),
          ]);
        },
      );

  Widget _feedCard(
    BuildContext context,
    Map<String, dynamic> product,
    double kgPerBag,
    ThemeData theme,
    VoidCallback reload,
  ) {
    final isReadyFeed =
        '${product['name']}'.trim().toLowerCase() == 'ready feed';
    final remainingBags = asD(product['remaining_bags']);
    final remainingKg = remainingBags * kgPerBag;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: () => context
              .push(isReadyFeed ? '/feed/ready' : '/feed/${product['id']}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: .12),
                child: Icon(
                    isReadyFeed ? Icons.blender_outlined : Icons.grass_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('${product['name']}',
                      style: theme.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
        InkWell(
          onTap: () => context
              .push(isReadyFeed ? '/feed/ready' : '/feed/${product['id']}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isReadyFeed
                    ? '${qty(remainingKg)} kg in stock'
                    : '${qty(remainingBags)} bags in stock',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: AppColors.primary),
              ),
              Text(
                isReadyFeed
                    ? '≈ ${qty(remainingBags)} bags'
                    : '≈ ${qty(remainingKg)} kg live stock',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: asD(product['purchased_bags']) <= 0
                      ? 0
                      : (remainingBags / asD(product['purchased_bags']))
                          .clamp(0, 1),
                  backgroundColor:
                      theme.colorScheme.outline.withValues(alpha: .2),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _Metric(
                  label: isReadyFeed ? 'Prepared' : 'Purchased',
                  value: isReadyFeed
                      ? '${qty(asD(product['purchased_bags']) * kgPerBag)} kg'
                      : '${qty(product['purchased_bags'])} bags',
                )),
                Expanded(
                    child: _Metric(
                  label: 'Consumed',
                  value: isReadyFeed
                      ? '${qty(asD(product['consumed_bags']) * kgPerBag)} kg'
                      : '${qty(product['consumed_bags'])} bags',
                )),
              ]),
            ]),
          ),
        ),
        if (!isReadyFeed) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              const Spacer(),
              TextButton.icon(
                  onPressed: () =>
                      _productForm(context, product: product, reload: reload),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit name')),
              IconButton(
                tooltip: 'Delete product',
                onPressed: () => _deleteProduct(context, product, reload),
                icon:
                    Icon(Icons.delete_outline, color: theme.colorScheme.error),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Theme.of(context).hintColor)),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ]);
}
