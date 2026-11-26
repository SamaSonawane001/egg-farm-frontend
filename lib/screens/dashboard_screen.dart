import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/auth_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ownerId = context
        .select<AuthState, String?>((auth) => auth.user?['id']?.toString());
    final ownerName =
        context.select<AuthState, String>((auth) => auth.ownerName);
    final isAllFarms =
        context.select<AuthState, bool>((auth) => auth.isAllFarms);
    final activeFarmId =
        context.select<AuthState, String?>((auth) => auth.selectedFarmId);
    return DataLoader<Map<String, dynamic>>(
      cacheKey: 'dashboard:${ownerId ?? 'current'}:$activeFarmId',
      load: () async => Map<String, dynamic>.from(await ApiClient.instance
          .get('/dashboard', query: {'today': today()})),
      builder: (context, d, reload) {
        final low = d['feed_low_stock'] == true;
        final profit = asD(d['month_profit']);
        final cards = <Widget>[
          StatCard(
              icon: Icons.pets,
              label: 'Total active birds',
              value: qty(d['active_birds'])),
          StatCard(
              icon: Icons.egg,
              label: "Today's egg production (net)",
              value: qty(d['today_eggs']),
              color: AppColors.yolk),
          StatCard(
              icon: Icons.inventory_2_outlined,
              label: 'Available eggs',
              value: qty(d['available_eggs']),
              color: AppColors.info),
          _FeedStockCard(
            totalBags: d['feed_remaining_bags'],
            lowStock: low,
            allFarms: isAllFarms,
            breakdown: Map<String, dynamic>.from(
              d['stock_breakdown'] as Map? ?? const {},
            ),
          ),
          StatCard(
              icon: Icons.trending_up,
              label: 'Monthly revenue (invoices)',
              value: money(d['month_revenue'])),
          StatCard(
              icon: Icons.pending_actions_outlined,
              label: 'Pending Payments (Unpaid Bills)',
              value: money(d['pending_payments']),
              color: AppColors.yolk),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              final selected = DateTime.parse(today());
              context.push(
                '/expenses/monthly?month=${selected.month}&year=${selected.year}',
              );
            },
            child: Stack(
              children: [
                StatCard(
                  icon: Icons.trending_down,
                  label: 'Monthly expenses',
                  value: money(d['month_expense']),
                  color: AppColors.danger,
                ),
                const Positioned(
                  right: 12,
                  top: 12,
                  child: Icon(Icons.chevron_right, size: 20),
                ),
              ],
            ),
          ),
          StatCard(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Monthly net',
              value: money(profit),
              color: profit >= 0 ? AppColors.primary : AppColors.danger),
        ];
        return RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              PageHeader(
                title: 'Executive Dashboard',
                subtitle: 'Welcome back, $ownerName',
                actions: [
                  const AndroidAppDownloadButton(),
                  IconButton.outlined(
                      onPressed: reload, icon: const Icon(Icons.refresh))
                ],
              ),
              if (low)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    color: AppColors.danger.withOpacity(.1),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Feed stock is low: ${qty(d['feed_remaining_bags'])} bags left (alert at ${qty(d['feed_threshold'])}).',
                          style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ),
              LayoutBuilder(builder: (c, box) {
                final cols = box.maxWidth >= 800 ? 3 : 2;
                final w = (box.maxWidth - (cols - 1) * 12) / cols;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final x in cards) SizedBox(width: w, child: x)
                ]);
              }),
              if (isAllFarms) ...[
                const SizedBox(height: 16),
                _FarmBreakdown(
                  farms: List<Map<String, dynamic>>.from(
                    (d['farm_breakdown'] as List? ?? const []).map(
                      (farm) => Map<String, dynamic>.from(farm as Map),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _WeekChart(
                  days:
                      List<Map<String, dynamic>>.from(d['last7_eggs'] as List)),
            ],
          ),
        );
      },
    );
  }
}

class _FeedStockCard extends StatelessWidget {
  final dynamic totalBags;
  final bool lowStock;
  final bool allFarms;
  final Map<String, dynamic> breakdown;

  const _FeedStockCard({
    required this.totalBags,
    required this.lowStock,
    required this.allFarms,
    required this.breakdown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feeds = List<Map<String, dynamic>>.from(
      (breakdown['feed_products'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map)),
    );
    final materials = List<Map<String, dynamic>>.from(
      (breakdown['raw_materials'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map)),
    );
    final otherFeeds = feeds
        .where((feed) =>
            '${feed['feed_type']}'.trim().toLowerCase() != 'ready feed')
        .toList();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.grass, size: 20, color: AppColors.info),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Remaining feed bags',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(qty(totalBags), style: theme.textTheme.headlineSmall),
          ),
          if (lowStock) ...[
            const SizedBox(height: 3),
            const Text(
              'Low stock!',
              style: TextStyle(
                  color: AppColors.danger, fontWeight: FontWeight.w600),
            ),
          ],
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: const Text(
              'Stock details • साठा तपशील',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            children: [
              _StockGroup(
                title: 'Ready Feed • तयार फीड',
                items: [
                  {
                    'name': 'Ready Feed',
                    'quantity': breakdown['ready_feed_bags'] ?? 0,
                    'unit': 'bags',
                  }
                ],
              ),
              if (otherFeeds.isNotEmpty)
                _StockGroup(
                  title: 'Other Feed • इतर फीड',
                  items: otherFeeds
                      .map((feed) => {
                            'name':
                                '${feed['feed_type'] ?? 'Feed'}${allFarms ? ' • ${feed['farm_name'] ?? ''}' : ''}',
                            'quantity': feed['remaining'] ?? 0,
                            'unit': 'bags',
                          })
                      .toList(),
                ),
              if (materials.isNotEmpty)
                _StockGroup(
                  title: 'Raw Materials • कच्चा माल',
                  items: materials
                      .map((material) => {
                            'name':
                                '${material['name'] ?? 'Material'}${material['is_shared_pool'] == true ? ' • Central Godown' : allFarms ? ' • ${material['farm_name'] ?? ''}' : ''}',
                            'quantity': material['bags_equivalent'] ?? 0,
                            'unit': 'bags',
                            'detail':
                                '${qty(material['current_stock'])} ${material['unit'] ?? 'kg'}'
                          })
                      .toList(),
                ),
              if (otherFeeds.isEmpty && materials.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('No additional stock items.'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockGroup extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;

  const _StockGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item['name']}', softWrap: true),
                        if (item['detail'] != null)
                          Text('${item['detail']}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.hintColor)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${qty(item['quantity'])} ${item['unit']}',
                      textAlign: TextAlign.end,
                      softWrap: true,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FarmBreakdown extends StatelessWidget {
  final List<Map<String, dynamic>> farms;
  const _FarmBreakdown({required this.farms});

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Farm-Wise Breakdown · फार्मनुसार हिशोब',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (farms.isEmpty)
              const Text('No farm activity found for this period.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Farm')),
                    DataColumn(label: Text('Active birds')),
                    DataColumn(label: Text("Today's eggs")),
                    DataColumn(label: Text('Revenue')),
                    DataColumn(label: Text('Expenses')),
                    DataColumn(label: Text('Net')),
                  ],
                  rows: [
                    for (final farm in farms)
                      DataRow(cells: [
                        DataCell(Text('${farm['farm_name'] ?? ''}')),
                        DataCell(Text(qty(farm['active_birds']))),
                        DataCell(Text(qty(farm['today_eggs']))),
                        DataCell(Text(money(farm['month_revenue']))),
                        DataCell(Text(money(farm['month_expense']))),
                        DataCell(Text(money(farm['month_profit']))),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _WeekChart extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  const _WeekChart({required this.days});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final weekdayFormat = DateFormat('E');
    final maxV = days.fold<double>(
        1, (m, e) => asD(e['net_eggs']) > m ? asD(e['net_eggs']) : m);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Net eggs – last 7 days', style: t.textTheme.titleMedium),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final e in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(qty(e['net_eggs']), style: t.textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Container(
                          height: 100 * (asD(e['net_eggs']) / maxV) + 3,
                          decoration: BoxDecoration(
                            color: AppColors.yolk,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                            weekdayFormat
                                .format(DateTime.parse('${e['date']}')),
                            style: t.textTheme.labelSmall),
                      ]),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}
