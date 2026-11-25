import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
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
  _Nav('/farm-expenses', 'Farm Expenses · फार्म खर्च', 'Expenses',
      Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
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
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final contentWidth = constraints.maxWidth > 1200
                        ? 1200.0
                        : constraints.maxWidth;
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: contentWidth,
                        height: constraints.maxHeight,
                        child: _FarmKeyedContent(
                          location: location,
                          child: child,
                        ),
                      ),
                    );
                  },
                ),
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

class _FarmKeyedContent extends StatefulWidget {
  final Widget child;
  final String location;

  const _FarmKeyedContent({
    required this.child,
    required this.location,
  });

  @override
  State<_FarmKeyedContent> createState() => _FarmKeyedContentState();
}

class _FarmKeyedContentState extends State<_FarmKeyedContent> {
  String? _lastFarmId;
  bool _hasFarmSelection = false;

  @override
  Widget build(BuildContext context) {
    final activeFarmId =
        context.select<AuthState, String?>((auth) => auth.selectedFarmId);
    final farmChanged = _hasFarmSelection && _lastFarmId != activeFarmId;
    _hasFarmSelection = true;
    _lastFarmId = activeFarmId;
    final detailRoot = widget.location.startsWith('/raw-materials/')
        ? '/raw-materials'
        : widget.location.startsWith('/medicines/')
            ? '/medicines'
            : null;
    if (farmChanged && detailRoot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.location.startsWith('$detailRoot/')) {
          context.go(detailRoot);
        }
      });
      return const Center(child: CircularProgressIndicator());
    }
    return KeyedSubtree(
      key: ValueKey<String?>(activeFarmId),
      child: widget.child,
    );
  }
}

/// Fixed profile bar shown on every authenticated page.
class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    ApiClient.instance.onFarmRequired =
        () => _showFarmChooser(context, auth, requireSpecificFarm: true);
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
                      if (auth.isSecondaryFarm || auth.isAllFarms)
                        Text(
                          auth.isAllFarms
                              ? auth.selectedFarmName
                              : 'Unit: ${auth.selectedFarmName}',
                          style: t.textTheme.labelSmall
                              ?.copyWith(color: t.colorScheme.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ]),
              ),
              IconButton.outlined(
                tooltip: 'Switch farm',
                icon: const Icon(Icons.swap_horiz),
                onPressed: () =>
                    _showFarmChooser(context, auth, requireSpecificFarm: false),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

Future<bool> _showFarmChooser(
  BuildContext context,
  AuthState auth, {
  required bool requireSpecificFarm,
}) async {
  Future<void>? farmSelection;
  final selection = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text('Choose farm'),
            subtitle: Text('Operations and records stay separate per farm.'),
          ),
          for (final farm in auth.farms)
            ListTile(
              leading: Icon(
                auth.selectedFarmId == farm['farm_id']
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text('${farm['farm_name'] ?? 'Farm'}'),
              subtitle: farm['is_primary'] == true
                  ? const Text('Primary farm')
                  : null,
              onTap: () {
                final farmId = '${farm['farm_id']}';
                farmSelection = auth.selectFarm(farmId);
                Navigator.pop(sheetContext, farmId);
              },
            ),
          if (!requireSpecificFarm)
            ListTile(
              leading: Icon(
                auth.isAllFarms
                    ? Icons.radio_button_checked
                    : Icons.assessment_outlined,
              ),
              title: const Text('All Farms Combined · एकत्रित हिशोब'),
              onTap: () {
                farmSelection = auth.selectFarm('all');
                Navigator.pop(sheetContext, 'all');
              },
            ),
          if (!requireSpecificFarm)
            ListTile(
              leading: const Icon(Icons.add_business_outlined),
              title: const Text('Create a farm'),
              onTap: () => Navigator.pop(sheetContext, '__create_farm__'),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted) return false;
  if (selection == null) return false;
  if (selection == '__create_farm__') {
    await _showCreateFarmDialog(context, auth);
    return false;
  }
  try {
    await (farmSelection ?? auth.selectFarm(selection));
    return true;
  } catch (error) {
    if (context.mounted) toast(context, '$error', error: true);
    return false;
  }
}

Future<void> _showCreateFarmDialog(BuildContext context, AuthState auth) async {
  final nameController = TextEditingController();
  var copyBranding = true;
  final create = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Create a farm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Farm name'),
              textCapitalization: TextCapitalization.words,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: copyBranding,
              title: const Text('Copy logo, signature and payment QR'),
              onChanged: (value) =>
                  setState(() => copyBranding = value ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
  if (create != true) {
    nameController.dispose();
    return;
  }
  try {
    await auth.createFarm(
      nameController.text.trim(),
      copyBranding: copyBranding,
    );
    if (context.mounted) toast(context, 'Farm created');
  } catch (error) {
    if (context.mounted) toast(context, '$error', error: true);
  } finally {
    nameController.dispose();
  }
}
