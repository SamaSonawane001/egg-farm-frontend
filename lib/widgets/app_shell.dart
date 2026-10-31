import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import 'common.dart';

class _Nav {
  final String path, label, short;
  final IconData icon, selected;
  const _Nav(this.path, this.label, this.short, this.icon, this.selected);
}

const _items = [
  _Nav('/dashboard', 'Dashboard', 'Home', Icons.space_dashboard_outlined,
      Icons.space_dashboard),
  _Nav('/flock', 'Flock & Mortality', 'Flock', Icons.pets_outlined, Icons.pets),
  _Nav('/feed', 'Feed Inventory', 'Feed', Icons.grass_outlined, Icons.grass),
  _Nav('/raw-materials', 'Raw Material', 'Raw', Icons.grain_outlined,
      Icons.grain),
  _Nav('/medicines', 'Medicines', 'Medicine', Icons.medication_outlined,
      Icons.medication),
  _Nav('/eggs', 'Egg Production', 'Eggs', Icons.egg_outlined, Icons.egg),
  _Nav('/invoices', 'Invoices & Billing', 'Bills', Icons.receipt_long_outlined,
      Icons.receipt_long),
  _Nav('/profile', 'Farm Profile', 'Profile', Icons.settings_outlined,
      Icons.settings),
];

class AppShell extends StatelessWidget {
  final String location;
  final Widget child;
  const AppShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final wide = w >= 900;
    var idx = _items.indexWhere((e) => location.startsWith(e.path));
    if (idx < 0) idx = 0;
    const mobilePaths = ['/dashboard', '/flock', '/feed', '/raw-materials'];
    final mobileIndex =
        mobilePaths.indexWhere((path) => location.startsWith(path));
    final mobileSelectedIndex = mobileIndex < 0 ? 4 : mobileIndex;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(children: [
        const _TopBar(),
        Expanded(
          child: Row(children: [
            if (wide) ...[
              NavigationRail(
                backgroundColor: cs.surface,
                extended: w >= 1150,
                labelType: w >= 1150
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                selectedIndex: idx,
                onDestinationSelected: (i) => context.go(_items[i].path),
                destinations: [
                  for (final n in _items)
                    NavigationRailDestination(
                      icon: Icon(n.icon),
                      selectedIcon: Icon(n.selected),
                      label: Text(w >= 1150 ? n.label : n.short),
                    ),
                ],
              ),
              VerticalDivider(width: 1, color: cs.outline),
            ],
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: child),
              ),
            ),
          ]),
        ),
      ]),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: mobileSelectedIndex,
              onDestinationSelected: (i) {
                if (i < mobilePaths.length) {
                  context.go(mobilePaths[i]);
                } else {
                  _showMoreNavigation(context, location);
                }
              },
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.space_dashboard_outlined),
                    selectedIcon: Icon(Icons.space_dashboard),
                    label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.pets_outlined),
                    selectedIcon: Icon(Icons.pets),
                    label: 'Flock'),
                NavigationDestination(
                    icon: Icon(Icons.grass_outlined),
                    selectedIcon: Icon(Icons.grass),
                    label: 'Feed'),
                NavigationDestination(
                    icon: Icon(Icons.grain_outlined),
                    selectedIcon: Icon(Icons.grain),
                    label: 'Raw'),
                NavigationDestination(
                    icon: Icon(Icons.more_horiz), label: 'More'),
              ],
            ),
    );
  }

  void _showMoreNavigation(BuildContext context, String location) {
    final moreItems = _items.where((item) => !const {
          '/dashboard',
          '/flock',
          '/feed',
          '/raw-materials',
        }.contains(item.path));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final item in moreItems)
              ListTile(
                leading: Icon(
                  location.startsWith(item.path) ? item.selected : item.icon,
                ),
                title: Text(item.label),
                selected: location.startsWith(item.path),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go(item.path);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Fixed profile bar shown on every authenticated page.
class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final t = Theme.of(context);
    return Material(
      color: t.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.colorScheme.outline))),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              FarmAvatar(url: auth.avatarUrl, name: auth.farmName, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.farmName,
                          style: t.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('${auth.ownerName}  •  ${auth.mobile}',
                          style: t.textTheme.bodySmall
                              ?.copyWith(color: t.hintColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
              IconButton.outlined(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout, size: 20),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Logout?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Logout')),
                      ],
                    ),
                  );
                  if (ok == true) auth.logout();
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
