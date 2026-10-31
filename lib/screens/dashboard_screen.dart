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
    final auth = context.watch<AuthState>();
    return DataLoader<Map<String, dynamic>>(
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
          StatCard(
              icon: Icons.grass,
              label: 'Remaining feed bags',
              value: qty(d['feed_remaining_bags']),
              sub: low ? 'Low stock!' : null,
              color: low ? AppColors.danger : AppColors.info),
          StatCard(
              icon: Icons.trending_up,
              label: 'Monthly revenue (invoices)',
              value: money(d['month_revenue'])),
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
                subtitle: 'Welcome back, ${auth.ownerName}',
                actions: [
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

class _WeekChart extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  const _WeekChart({required this.days});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
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
                            DateFormat('E')
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
