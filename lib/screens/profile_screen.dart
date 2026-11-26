import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/auth_state.dart';
import '../widgets/common.dart';
import '../widgets/legal_documents.dart';
import '../widgets/subscription_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _owner,
      _farm,
      _address,
      _threshold,
      _kg,
      _tax,
      _eggsPerTray;
  Uint8List? _avatar;
  String? _avatarName;
  bool _saving = false;
  String? _assetBusy;
  late final AuthState _auth;

  @override
  void dispose() {
    _owner.dispose();
    _farm.dispose();
    _address.dispose();
    _threshold.dispose();
    _kg.dispose();
    _tax.dispose();
    _eggsPerTray.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthState>();
    final u = _auth.user ?? {};
    final primary = _auth.primaryFarm ?? u;
    String s(dynamic v) =>
        v is double && v == v.roundToDouble() ? '${v.toInt()}' : '${v ?? ''}';
    _owner = TextEditingController(text: s(u['owner_name']));
    _farm = TextEditingController(text: s(primary['farm_name']));
    _address = TextEditingController(text: s(primary['address']));
    _threshold = TextEditingController(text: s(u['low_stock_threshold']));
    _kg = TextEditingController(text: s(u['kg_per_bag']));
    _tax = TextEditingController(text: s(u['default_tax_percent']));
    _eggsPerTray = TextEditingController(text: s(u['eggs_per_tray'] ?? 30));
  }

  Future<void> _editUnit({String? farmId, String? farmName}) async {
    final name = TextEditingController(text: farmName ?? '');
    var copyBranding = true;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(farmId == null ? 'Add farm / unit' : 'Rename unit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: dec(dialogContext, 'Farm / unit name'),
                textCapitalization: TextCapitalization.words,
              ),
              if (farmId == null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: copyBranding,
                  title: const Text('Copy primary farm branding and defaults'),
                  onChanged: (value) => setDialogState(
                    () => copyBranding = value ?? false,
                  ),
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
                if (name.text.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(farmId == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
    if (save != true) {
      name.dispose();
      return;
    }

    try {
      if (farmId == null) {
        await _auth.createFarm(name.text.trim(), copyBranding: copyBranding);
      } else {
        await _auth.renameFarm(farmId, name.text.trim());
      }
      if (mounted) {
        toast(context, farmId == null ? 'Farm added' : 'Unit renamed');
      }
    } catch (error) {
      if (mounted) toast(context, '$error', error: true);
    } finally {
      name.dispose();
    }
  }

  Widget _farmUnitsCard(AuthState auth) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'My Farms / Units',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editUnit(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add unit'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final farm in auth.farms)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  farm['is_primary'] == true
                      ? Icons.business_outlined
                      : Icons.warehouse_outlined,
                ),
                title: Text('${farm['farm_name'] ?? 'Farm'}'),
                subtitle: Text(
                  farm['is_primary'] == true
                      ? 'Primary business identity'
                      : farm['farm_id'] == auth.selectedFarmId
                          ? 'Unit · currently selected'
                          : 'Unit',
                ),
                trailing: farm['is_primary'] == true
                    ? const Icon(Icons.verified_outlined)
                    : IconButton(
                        tooltip: 'Rename unit',
                        onPressed: () => _editUnit(
                          farmId: '${farm['farm_id']}',
                          farmName: '${farm['farm_name'] ?? ''}',
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
              ),
          ],
        ),
      );

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 600, imageQuality: 80);
    if (x == null) return;
    final b = await x.readAsBytes();
    setState(() {
      _avatar = b;
      _avatarName = x.name;
    });
  }

  Future<void> _pickFarmAsset(String asset) async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    if (x == null || !mounted) return;
    setState(() => _assetBusy = asset);
    try {
      await context
          .read<AuthState>()
          .uploadFarmAsset(asset, await x.readAsBytes(), x.name);
      if (mounted) toast(context, 'Image uploaded');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _assetBusy = null);
    }
  }

  Future<void> _removeFarmAsset(String asset) async {
    setState(() => _assetBusy = asset);
    try {
      await context.read<AuthState>().removeFarmAsset(asset);
      if (mounted) toast(context, 'Image removed');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _assetBusy = null);
    }
  }

  Widget _farmAssetCard({
    required String asset,
    required String title,
    required String subtitle,
    required String? url,
    required bool square,
  }) {
    final cs = Theme.of(context).colorScheme;
    final busy = _assetBusy == asset;
    final disabled = _assetBusy != null;
    final hasImage = url != null && url.isNotEmpty;
    final isDataUri = url?.startsWith('data:image/png;base64,') ?? false;
    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: square ? 82 : 92,
        height: square ? 82 : 76,
        color: cs.surfaceContainerHighest.withValues(alpha: .5),
        alignment: Alignment.center,
        child: hasImage
            ? (isDataUri
                ? Image.memory(
                    base64Decode(
                        url.substring('data:image/png;base64,'.length)),
                    key: ValueKey(url),
                    width: square ? 76 : 88,
                    height: square ? 76 : 68,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      square ? Icons.qr_code_2 : Icons.draw_outlined,
                      size: 34,
                      color: cs.primary,
                    ),
                  )
                : Image.network(
                    url,
                    key: ValueKey(url),
                    width: square ? 76 : 88,
                    height: square ? 76 : 68,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      square ? Icons.qr_code_2 : Icons.draw_outlined,
                      size: 34,
                      color: cs.primary,
                    ),
                  ))
            : Icon(
                square ? Icons.qr_code_2 : Icons.draw_outlined,
                size: 34,
                color: cs.primary.withValues(alpha: .7),
              ),
      ),
    );
    return AppCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        preview,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                OutlinedButton.icon(
                  onPressed: disabled ? null : () => _pickFarmAsset(asset),
                  icon: busy
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_outlined, size: 17),
                  label: Text(asset == 'signature'
                      ? hasImage
                          ? 'Change Signature'
                          : 'Upload Signature'
                      : hasImage
                          ? 'Change Payment QR'
                          : 'Upload Payment QR'),
                ),
                if (hasImage)
                  TextButton(
                    onPressed: disabled ? null : () => _removeFarmAsset(asset),
                    child: const Text('Remove'),
                  ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthState>().updateProfile({
        'owner_name': _owner.text.trim(),
        'farm_name': _farm.text.trim(),
        'address': _address.text.trim(),
        'low_stock_threshold': _threshold.text.trim(),
        'kg_per_bag': _kg.text.trim(),
        'default_tax_percent': _tax.text.trim(),
        'eggs_per_tray': _eggsPerTray.text.trim(),
      }, avatar: _avatar, avatarName: _avatarName);
      if (mounted) {
        setState(() {
          _avatar = null;
          _avatarName = null;
        });
        toast(context, 'Profile updated');
      }
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _defaultsFields({
    required bool desktop,
    required String? Function(String?) numberValidator,
  }) {
    final fields = [
      TextFormField(
        controller: _threshold,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: dec(context, 'Low feed-stock alert (bags)'),
        validator: numberValidator,
      ),
      TextFormField(
        controller: _kg,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: dec(context, 'Kilograms per feed bag'),
        validator: (s) =>
            (double.tryParse((s ?? '').trim()) ?? 0) > 0 ? null : 'Must be > 0',
      ),
      TextFormField(
        controller: _tax,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: dec(context, 'Default tax % for new invoices'),
        validator: numberValidator,
      ),
      TextFormField(
        controller: _eggsPerTray,
        keyboardType: TextInputType.number,
        decoration: dec(context, 'Eggs per Tray / Crate'),
        validator: (s) => (int.tryParse((s ?? '').trim()) ?? 0) > 0
            ? null
            : 'Must be a whole number greater than 0',
      ),
    ];

    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fields[0],
          const SizedBox(height: 12),
          fields[1],
          const SizedBox(height: 12),
          fields[2],
          const SizedBox(height: 12),
          fields[3],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: fields[0]),
            const SizedBox(width: 16),
            Expanded(child: fields[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: fields[2]),
            const SizedBox(width: 16),
            Expanded(child: fields[3]),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final cs = Theme.of(context).colorScheme;
    String? req(String? s) => (s ?? '').trim().isEmpty ? 'Required' : null;
    String? num0(String? s) => (double.tryParse((s ?? '').trim()) ?? -1) < 0
        ? 'Enter a valid number'
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 768;
        final saveButton = FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          label: const Text('Save changes'),
        );
        final logoutButton = OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: cs.error),
          onPressed: () => auth.logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        );
        final legalButton = TextButton.icon(
          onPressed: () => showLegalDocuments(context),
          icon: const Icon(Icons.policy_outlined, size: 18),
          label: const Text('Terms & Conditions • Privacy Policy'),
        );
        return Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const PageHeader(
                title: 'Farm Profile & Settings',
                subtitle: 'Manage primary business identity and unit defaults'),
            AppCard(
              child: Column(children: [
                GestureDetector(
                  onTap: _pick,
                  child: Stack(children: [
                    Stack(children: [
                      _avatar != null
                          ? CircleAvatar(
                              radius: 48,
                              backgroundImage: MemoryImage(_avatar!))
                          : FarmAvatar(
                              url: auth.avatarUrl,
                              name: auth.farmName,
                              radius: 48),
                      if (_saving && _avatar != null)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .4),
                                shape: BoxShape.circle),
                            child: const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white)),
                          ),
                        ),
                    ]),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                          radius: 15,
                          backgroundColor: cs.primary,
                          child:
                              Icon(Icons.edit, size: 15, color: cs.onPrimary)),
                    ),
                  ]),
                ),
                const SizedBox(height: 6),
                Text('Registered mobile: ${auth.mobile}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _farm,
                    decoration: dec(context, 'Farm name',
                        icon: Icons.agriculture_outlined),
                    validator: req),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _owner,
                    decoration:
                        dec(context, 'Owner name', icon: Icons.person_outline),
                    validator: req),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _address,
                    minLines: 2,
                    maxLines: 3,
                    decoration:
                        dec(context, 'Farm address (printed on invoices)')),
              ]),
            ),
            const SizedBox(height: 14),
            _farmUnitsCard(auth),
            const SizedBox(height: 14),
            const CentralInventoryToggle(),
            const SizedBox(height: 14),
            DataLoader<Map<String, dynamic>>(
              load: () async => Map<String, dynamic>.from(
                await ApiClient.instance.get('/subscription/status') as Map,
              ),
              builder: (context, status, reload) =>
                  SubscriptionManagementCard(status: status, reload: reload),
            ),
            const SizedBox(height: 14),
            _farmAssetCard(
              asset: 'signature',
              title: 'Authorized Signature',
              subtitle: 'मालकाची सही / Signature',
              url: auth.signatureUrl,
              square: false,
            ),
            const SizedBox(height: 10),
            _farmAssetCard(
              asset: 'payment_qr',
              title: 'Payment QR Code',
              subtitle: 'PhonePe / Google Pay / Bank QR',
              url: auth.paymentQrUrl,
              square: true,
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Defaults',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _defaultsFields(
                      desktop: desktop,
                      numberValidator: num0,
                    ),
                  ]),
            ),
            const SizedBox(height: 16),
            if (desktop)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 220, child: saveButton),
                    const SizedBox(width: 12),
                    SizedBox(width: 180, child: logoutButton),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: double.infinity, child: saveButton),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: logoutButton),
                ],
              ),
            const SizedBox(height: 4),
            const Center(child: AndroidAppDownloadButton()),
            const SizedBox(height: 4),
            Center(child: legalButton),
          ]),
        );
      },
    );
  }
}
