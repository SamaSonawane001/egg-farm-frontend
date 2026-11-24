import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/form_dialog.dart';

class ReadyFeedDetailScreen extends StatefulWidget {
  const ReadyFeedDetailScreen({super.key});

  @override
  State<ReadyFeedDetailScreen> createState() => _ReadyFeedDetailScreenState();
}

class _ReadyFeedDetailScreenState extends State<ReadyFeedDetailScreen> {
  Future<Map<String, dynamic>> _load() async {
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/feed/ready-feed'),
        ApiClient.instance.get('/flock/batches'),
        ApiClient.instance.get('/raw-materials'),
      ]);
      final result = Map<String, dynamic>.from(results[0] as Map);
      final feeds = List<Map<String, dynamic>>.from(
        result['source_products'] as List,
      ).map((feed) => {
            ...feed,
            'source_type': 'feed',
            'item_id': '${feed['id']}',
            'available_kg': asD(feed['remaining_bags']) *
                (asD(result['kg_per_bag']) > 0
                    ? asD(result['kg_per_bag'])
                    : 50),
          });
      final materials = List<Map<String, dynamic>>.from(
        results[2] as List,
      ).map((material) => {
            ...material,
            'source_type': 'raw_material',
            'item_id': '${material['id']}',
            'available_kg': asD(material['current_stock']),
          });
      return {
        'product': Map<String, dynamic>.from(result['product'] as Map),
        'sources': [...feeds, ...materials],
        'preparations':
            List<Map<String, dynamic>>.from(result['preparations'] as List),
        'usage': List<Map<String, dynamic>>.from(result['usage'] as List),
        'batches': List<Map<String, dynamic>>.from(results[1] as List),
        'kgPerBag': asD(result['kg_per_bag']),
      };
    } on ApiException catch (error) {
      if (error.status != 404) rethrow;
      return _loadLegacyFallback();
    }
  }

  Future<Map<String, dynamic>> _loadLegacyFallback() async {
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
      ApiClient.instance.get('/flock/batches').catchError((Object error) {
        if (error is ApiException && error.status == 404) return <dynamic>[];
        throw error;
      }),
      ApiClient.instance.get('/raw-materials'),
    ]);
    final products = List<Map<String, dynamic>>.from(results[0] as List);
    final ready = products.where(
      (item) => '${item['name']}'.trim().toLowerCase() == 'ready feed',
    );
    final product = ready.isEmpty
        ? <String, dynamic>{
            'id': null,
            'name': 'Ready Feed',
            'purchased_bags': 0,
            'consumed_bags': 0,
            'remaining_bags': 0,
            'total_spent': 0,
          }
        : Map<String, dynamic>.from(ready.first);
    List<Map<String, dynamic>> usage = [];
    if (product['id'] != null) {
      try {
        final detail = Map<String, dynamic>.from(
          await ApiClient.instance.get('/feed/products/${product['id']}')
              as Map,
        );
        usage = List<Map<String, dynamic>>.from(detail['usage'] as List? ?? []);
      } on ApiException catch (error) {
        if (error.status != 404) rethrow;
      }
    }
    final stock = Map<String, dynamic>.from(results[1] as Map);
    final kgPerBag =
        asD(stock['kg_per_bag']) > 0 ? asD(stock['kg_per_bag']) : 50.0;
    final sources = products
        .where((item) => '${item['name']}'.trim().toLowerCase() != 'ready feed')
        .map((feed) => {
              ...feed,
              'source_type': 'feed',
              'item_id': '${feed['id']}',
              'available_kg': asD(feed['remaining_bags']) * kgPerBag,
            })
        .toList();
    sources.addAll(
      List<Map<String, dynamic>>.from(results[3] as List).map((material) => {
            ...material,
            'source_type': 'raw_material',
            'item_id': '${material['id']}',
            'available_kg': asD(material['current_stock']),
          }),
    );
    return {
      'product': product,
      'sources': sources,
      'preparations': <Map<String, dynamic>>[],
      'usage': usage,
      'batches': List<Map<String, dynamic>>.from(results[2] as List),
      'kgPerBag': kgPerBag,
    };
  }

  Future<void> _usageForm(Map<String, dynamic> product,
      List<Map<String, dynamic>> batches, double kgPerBag, VoidCallback reload,
      {Map<String, dynamic>? usage}) async {
    final availableBags = asD(product['remaining_bags']) +
        (usage == null ? 0 : asD(usage['bags_equivalent']));
    final saved = await showFormDialog(
      context,
      title: usage == null
          ? 'Log Ready Feed given to birds'
          : 'Edit Ready Feed bird feeding',
      initial: {
        ...?usage,
        if (usage != null && usage['batch_id'] == null) 'batch_id': '',
      },
      fields: [
        const FieldSpec('usage_date', 'Date', type: FieldType.date),
        FieldSpec(
          'batch_id',
          'Flock batch',
          type: FieldType.select,
          required: false,
          options: [
            const MapEntry('', 'All / not specified'),
            for (final batch in batches)
              MapEntry('${batch['id']}', '${batch['batch_name']}'),
          ],
        ),
        FieldSpec(
          'quantity',
          'Quantity used',
          type: FieldType.number,
          validator: (value, values) {
            final entered = double.tryParse(value ?? '');
            if (entered == null) return null;
            final bags = values['unit'] == 'kg' ? entered / kgPerBag : entered;
            return bags > availableBags + 0.0005
                ? 'Only ${qty(availableBags * kgPerBag)} kg available'
                : null;
          },
        ),
        const FieldSpec(
          'unit',
          'Unit',
          type: FieldType.select,
          options: [MapEntry('kg', 'Kilograms'), MapEntry('bags', 'Bags')],
        ),
      ],
      onSubmit: (values) async {
        final body = {
          'feed_product_id': product['id'],
          'usage_date': values['usage_date'],
          'batch_id': values['batch_id']!.isEmpty ? null : values['batch_id'],
          'quantity': double.parse(values['quantity']!),
          'unit': values['unit'],
        };
        if (usage == null) {
          await ApiClient.instance.post('/feed/usage', body);
        } else {
          await ApiClient.instance.put('/feed/usage/${usage['id']}', body);
        }
      },
    );
    if (saved && mounted) {
      reload();
      toast(
          context,
          usage == null
              ? 'Ready Feed usage recorded'
              : 'Ready Feed usage updated');
    }
  }

  Future<void> _deleteUsage(
    BuildContext context,
    Map<String, dynamic> usage,
    VoidCallback reload,
  ) async {
    if (!await confirmDelete(context, 'this Ready Feed bird-feeding record')) {
      return;
    }
    try {
      await ApiClient.instance.delete('/feed/usage/${usage['id']}');
      if (context.mounted) {
        reload();
        toast(context, 'Ready Feed usage deleted');
      }
    } catch (error) {
      if (context.mounted) toast(context, '$error', error: true);
    }
  }

  Future<void> _preparationForm(
    BuildContext context,
    List<Map<String, dynamic>> sources,
    double kgPerBag,
    VoidCallback reload, {
    Map<String, dynamic>? preparation,
  }) async {
    final today = DateTime.now();
    var date = preparation == null
        ? '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}'
        : '${preparation['preparation_date']}'.substring(0, 10);
    final rows = <_IngredientRow>[];
    final savedIngredients = List<Map<String, dynamic>>.from(
        preparation?['ingredients'] as List? ?? const []);
    if (savedIngredients.isEmpty) {
      rows.add(_IngredientRow(
        sourceKey: sources.isEmpty
            ? null
            : '${sources.first['source_type']}:${sources.first['item_id']}',
      ));
    } else {
      for (final item in savedIngredients) {
        rows.add(_IngredientRow(
          sourceKey:
              '${item['source_type'] ?? 'feed'}:${item['item_id'] ?? item['feed_product_id'] ?? item['material_id']}',
          quantity: asD(item['quantity_kg']).toString(),
        ));
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          double totalKg = 0;
          for (final row in rows) {
            final entered = asD(row.controller.text);
            totalKg += row.unit == 'bags' ? entered * kgPerBag : entered;
          }
          return AlertDialog(
            title: Text(preparation == null
                ? 'Prepare Ready Feed · खाद्य तयार करा'
                : 'Edit Ready Feed batch'),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sources.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'No feed or raw material sources are available yet. Add inventory stock, then select ingredients here.',
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final initial =
                            DateTime.tryParse(date) ?? DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            date =
                                '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text('Preparation date: $date'),
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < rows.length; index++) ...[
                      _ingredientFields(
                        sources,
                        rows[index],
                        kgPerBag,
                        setDialogState,
                        canRemove: rows.length > 1,
                        onRemove: () => setDialogState(() {
                          rows.removeAt(index).dispose();
                        }),
                      ),
                      const SizedBox(height: 10),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => setDialogState(() {
                        rows.add(_IngredientRow(
                          sourceKey: sources.isEmpty
                              ? null
                              : '${sources.first['source_type']}:${sources.first['item_id']}',
                        ));
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Ingredient'),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Row(children: [
                        const Icon(Icons.scale_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Total Ready Feed to Add',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          '${qty(totalKg)} kg',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final ingredients = <Map<String, dynamic>>[];
                  final totalsBySource = <String, double>{};
                  for (final row in rows) {
                    final sourceKey = row.sourceKey;
                    final quantity =
                        double.tryParse(row.controller.text.trim());
                    if (sourceKey == null ||
                        quantity == null ||
                        quantity <= 0 ||
                        (quantity * 1000 - (quantity * 1000).round()).abs() >
                            0.00001) {
                      toast(context,
                          'Enter a valid quantity for every ingredient',
                          error: true);
                      return;
                    }
                    final separator = sourceKey.indexOf(':');
                    final sourceType = sourceKey.substring(0, separator);
                    final itemId = sourceKey.substring(separator + 1);
                    ingredients.add({
                      'source_type': sourceType,
                      'item_id': itemId,
                      'quantity_kg':
                          row.unit == 'bags' ? quantity * kgPerBag : quantity,
                    });
                    final quantityKg =
                        row.unit == 'bags' ? quantity * kgPerBag : quantity;
                    totalsBySource.update(
                      sourceKey,
                      (value) => value + quantityKg,
                      ifAbsent: () => quantityKg,
                    );
                  }
                  for (final entry in totalsBySource.entries) {
                    final sourceKey = entry.key;
                    final source = sources.firstWhere((item) =>
                        '${item['source_type']}:${item['item_id']}' ==
                        sourceKey);
                    final oldKg = preparation == null
                        ? 0.0
                        : List<Map<String, dynamic>>.from(
                            preparation['ingredients'] as List,
                          )
                            .where((item) =>
                                '${item['source_type'] ?? 'feed'}:${item['item_id'] ?? item['feed_product_id'] ?? item['material_id']}' ==
                                sourceKey)
                            .fold<double>(
                              0,
                              (sum, item) => sum + asD(item['quantity_kg']),
                            );
                    final availableKg = asD(source['available_kg']) + oldKg;
                    if (entry.value > availableKg + 0.0005) {
                      toast(
                        context,
                        'Not enough ${source['name']} in stock (${qty(asD(source['available_kg']))} kg available)',
                        error: true,
                      );
                      return;
                    }
                  }
                  try {
                    final body = {'date': date, 'ingredients': ingredients};
                    if (preparation == null) {
                      await ApiClient.instance
                          .post('/feed/prepare-ready-feed', body);
                    } else {
                      await ApiClient.instance.put(
                        '/feed/prepare-ready-feed/${preparation['id']}',
                        body,
                      );
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  } catch (error) {
                    if (context.mounted) toast(context, '$error', error: true);
                  }
                },
                child:
                    Text(preparation == null ? 'Prepare Feed' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    );
    for (final row in rows) {
      row.dispose();
    }
    if (result == true && context.mounted) {
      reload();
      toast(context,
          preparation == null ? 'Ready Feed batch prepared' : 'Batch updated');
    }
  }

  Widget _ingredientFields(
    List<Map<String, dynamic>> sources,
    _IngredientRow row,
    double kgPerBag,
    StateSetter setDialogState, {
    required bool canRemove,
    required VoidCallback onRemove,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<String>(
            key: ValueKey('source-${row.sourceKey}'),
            initialValue: row.sourceKey,
            decoration: const InputDecoration(labelText: 'Source item'),
            items: [
              for (final source in sources)
                DropdownMenuItem(
                  value: '${source['source_type']}:${source['item_id']}',
                  child: Text(
                    '${source['name']} [${source['source_type'] == 'feed' ? 'Feed' : 'Raw Material'}] - Available: ${qty(source['available_kg'])} kg${source['source_type'] == 'feed' ? ' (${qty(asD(source['remaining_bags']))} bags)' : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setDialogState(() => row.sourceKey = value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: row.controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantity'),
            onChanged: (_) => setDialogState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: DropdownButtonFormField<String>(
            key: ValueKey('unit-${row.unit}'),
            initialValue: row.unit,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: const [
              DropdownMenuItem(value: 'kg', child: Text('kg')),
              DropdownMenuItem(value: 'bags', child: Text('bags')),
            ],
            onChanged: (value) => setDialogState(() {
              if (value != null) row.unit = value;
            }),
          ),
        ),
        IconButton(
          tooltip: 'Remove ingredient',
          onPressed: canRemove ? onRemove : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    );
  }

  Future<void> _deletePreparation(
    BuildContext context,
    Map<String, dynamic> preparation,
    VoidCallback reload,
  ) async {
    if (!await confirmDelete(context, 'this Ready Feed preparation batch')) {
      return;
    }
    try {
      await ApiClient.instance.delete(
        '/feed/prepare-ready-feed/${preparation['id']}',
      );
      if (context.mounted) {
        reload();
        toast(context, 'Ready Feed batch deleted');
      }
    } catch (error) {
      if (context.mounted) toast(context, '$error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => DataLoader<Map<String, dynamic>>(
        load: _load,
        builder: (context, data, reload) {
          final product = data['product'] as Map<String, dynamic>;
          final sources = data['sources'] as List<Map<String, dynamic>>;
          final preparations =
              data['preparations'] as List<Map<String, dynamic>>;
          final usage = data['usage'] as List<Map<String, dynamic>>;
          final batches = data['batches'] as List<Map<String, dynamic>>;
          final kgPerBag =
              asD(data['kgPerBag']) > 0 ? asD(data['kgPerBag']) : 50.0;
          final readyKg = asD(product['remaining_bags']) * kgPerBag;
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: PageHeader(
                    title: 'Ready Feed · तयार खाद्य',
                    subtitle: 'Prepared feed batches and bird consumption',
                    actions: [
                      FilledButton.icon(
                        onPressed: () => _preparationForm(
                          context,
                          sources,
                          kgPerBag,
                          reload,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add / Prepare Ready Feed'),
                      ),
                      OutlinedButton.icon(
                        onPressed: product['id'] == null
                            ? null
                            : () => _usageForm(
                                  product,
                                  batches,
                                  kgPerBag,
                                  reload,
                                ),
                        icon: const Icon(Icons.restaurant_outlined),
                        label: const Text('Log bird feeding'),
                      ),
                    ],
                  ),
                ),
              ]),
              LayoutBuilder(
                builder: (context, constraints) {
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
                      SizedBox(
                        width: width,
                        child: StatCard(
                          icon: Icons.inventory_2_outlined,
                          label: 'Live Ready Feed stock',
                          value: '${qty(readyKg)} kg',
                          sub: '≈ ${qty(product['remaining_bags'])} bags',
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: StatCard(
                          icon: Icons.blender_outlined,
                          label: 'Prepared total',
                          value:
                              '${qty(asD(product['purchased_bags']) * kgPerBag)} kg',
                          sub: '${qty(product['purchased_bags'])} bags',
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: StatCard(
                          icon: Icons.restaurant_outlined,
                          label: 'Consumed by birds',
                          value:
                              '${qty(asD(product['consumed_bags']) * kgPerBag)} kg',
                          sub: '${qty(product['consumed_bags'])} bags',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              PageHeader(title: 'Preparation history'),
              if (preparations.isEmpty)
                const EmptyState(
                  icon: Icons.blender_outlined,
                  text: 'No Ready Feed batches prepared yet.',
                ),
              for (final preparation in preparations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: .12),
                          child: const Icon(Icons.blender_outlined,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Prepared ${qty(preparation['total_quantity_kg'])} kg',
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                '${fmtDate(preparation['preparation_date'])} · ${List<Map<String, dynamic>>.from(preparation['ingredients'] as List).map((item) => '${qty(item['quantity_kg'])} kg ${item['feed_name']}').join(' + ')}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit batch',
                          onPressed: () => _preparationForm(
                            context,
                            sources,
                            kgPerBag,
                            reload,
                            preparation: preparation,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete batch',
                          onPressed: () => _deletePreparation(
                            context,
                            preparation,
                            reload,
                          ),
                          icon: Icon(Icons.delete_outline,
                              color: theme.colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              PageHeader(title: 'Bird feeding history'),
              if (usage.isEmpty)
                const EmptyState(
                  icon: Icons.restaurant_outlined,
                  text: 'No Ready Feed consumption recorded yet.',
                ),
              for (final entry in usage)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Row(children: [
                      const Icon(Icons.restaurant_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${qty(entry['quantity'])} ${entry['unit']} used${entry['remarks'] == null ? (entry['batch_name'] == null ? '' : ' · ${entry['batch_name']}') : ' · ${entry['remarks']}'}',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(fmtDate(entry['usage_date'])),
                      IconButton(
                        tooltip: 'Edit bird feeding',
                        onPressed: product['id'] == null
                            ? null
                            : () => _usageForm(
                                  product,
                                  batches,
                                  kgPerBag,
                                  reload,
                                  usage: entry,
                                ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete bird feeding',
                        onPressed: product['id'] == null
                            ? null
                            : () => _deleteUsage(context, entry, reload),
                        icon: Icon(Icons.delete_outline,
                            color: theme.colorScheme.error),
                      ),
                    ]),
                  ),
                ),
            ],
          );
        },
      );
}

class _IngredientRow {
  String? sourceKey;
  final TextEditingController controller;
  String unit;

  _IngredientRow({
    this.sourceKey,
    String quantity = '',
  })  : unit = 'kg',
        controller = TextEditingController(text: quantity);

  void dispose() => controller.dispose();
}
