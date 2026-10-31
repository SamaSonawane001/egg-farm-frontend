import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/form_dialog.dart';

class RawMaterialsScreen extends StatefulWidget {
  const RawMaterialsScreen({super.key});

  @override
  State<RawMaterialsScreen> createState() => _RawMaterialsScreenState();
}

class _RawMaterialsScreenState extends State<RawMaterialsScreen> {
  final TextEditingController _search = TextEditingController();
  String _searchTerm = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait([
      ApiClient.instance.get('/raw-materials'),
      ApiClient.instance.get('/feed/stock'),
    ]);
    return {
      'materials': List<Map<String, dynamic>>.from(results[0] as List),
      'kgPerBag': asD((results[1] as Map)['kg_per_bag']),
    };
  }

  Future<void> _materialForm(
    BuildContext context, {
    Map<String, dynamic>? material,
    required VoidCallback reload,
  }) async {
    var duplicate = false;
    final saved = await showFormDialog(
      context,
      title: material == null ? 'Add Raw Material' : 'Edit Raw Material',
      initial: material ?? {},
      fields: [
        const FieldSpec('name', 'Material name'),
        FieldSpec(
          'min_alert_threshold',
          'Low-stock alert threshold (kg)',
          type: FieldType.number,
          required: false,
          validator: (value, _) => decimalValueError(
            value,
            maxDecimalPlaces: 3,
          ),
        ),
      ],
      onSubmit: (values) async {
        final body = {
          'name': values['name'],
          'min_alert_threshold':
              double.tryParse(values['min_alert_threshold'] ?? '') ?? 0,
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
    BuildContext context,
    Map<String, dynamic> material, {
    required VoidCallback reload,
  }) async {
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

  @override
  Widget build(BuildContext context) => DataLoader<Map<String, dynamic>>(
        load: _load,
        builder: (context, data, reload) {
          final materials = data['materials'] as List<Map<String, dynamic>>;
          final kgPerBag =
              asD(data['kgPerBag']) > 0 ? asD(data['kgPerBag']) : 50.0;
          final needle = _searchTerm.trim().toLowerCase();
          final visibleMaterials = materials.where((material) =>
              '${material['name']} ${material['unit']}'
                  .toLowerCase()
                  .contains(needle));

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _search,
                onChanged: (value) => setState(() => _searchTerm = value),
                decoration: dec(
                  context,
                  'Search raw materials',
                  icon: Icons.search,
                ).copyWith(
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageHeader(
                    title: 'Raw Material · कच्चा माल',
                    subtitle: 'Raw material products and live stock',
                    actions: [
                      FilledButton.icon(
                        onPressed: () => _materialForm(context, reload: reload),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Raw Material Product'),
                      ),
                    ],
                  ),
                  if (visibleMaterials.isEmpty && needle.isNotEmpty)
                    const EmptyState(
                      icon: Icons.search_off,
                      text: 'No raw materials match your search.',
                    )
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
                                onOpen: () => context.push(
                                  '/raw-materials/${material['id']}',
                                  extra: {
                                    'name': '${material['name']}',
                                    'unit': '${material['unit']}',
                                  },
                                ),
                                onEdit: () => _materialForm(
                                  context,
                                  material: material,
                                  reload: reload,
                                ),
                                onDelete: () => _deleteMaterial(
                                  context,
                                  material,
                                  reload: reload,
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                ],
              ),
            ),
          ]);
        },
      );
}

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> material;
  final double kgPerBag;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MaterialCard({
    required this.material,
    required this.kgPerBag,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final stock = asD(material['current_stock']);
    final purchased = asD(material['total_purchased']);
    final consumed = asD(material['total_consumed']);
    final low = stock <= asD(material['min_alert_threshold']);
    final progress = purchased <= 0 ? 0.0 : (stock / purchased).clamp(0.0, 1.0);
    final color = low ? Theme.of(context).colorScheme.error : AppColors.primary;
    const unit = 'kg';
    final secondary = '≈ ${qty(stock / kgPerBag)} bags live stock';

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          onTap: onOpen,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: .12),
                child:
                    const Icon(Icons.grain_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${material['name']}',
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
        InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${qty(stock)} $unit in stock',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: color),
                ),
                Text(
                  secondary,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: progress,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: .2),
                    color: color,
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _StockMetric(
                      label: 'Purchased / आवक',
                      value: '${qty(purchased)} $unit',
                    ),
                  ),
                  Expanded(
                    child: _StockMetric(
                      label: 'Consumed / वापर',
                      value: '${qty(consumed)} $unit',
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            const Spacer(),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit name'),
            ),
            IconButton(
              tooltip: 'Delete material',
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
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
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      );
}
