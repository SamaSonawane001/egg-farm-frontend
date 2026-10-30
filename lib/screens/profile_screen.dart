import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/auth_state.dart';
import '../widgets/common.dart';

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
    final u = context.read<AuthState>().user ?? {};
    String s(dynamic v) =>
        v is double && v == v.roundToDouble() ? '${v.toInt()}' : '${v ?? ''}';
    _owner = TextEditingController(text: s(u['owner_name']));
    _farm = TextEditingController(text: s(u['farm_name']));
    _address = TextEditingController(text: s(u['address']));
    _threshold = TextEditingController(text: s(u['low_stock_threshold']));
    _kg = TextEditingController(text: s(u['kg_per_bag']));
    _tax = TextEditingController(text: s(u['default_tax_percent']));
    _eggsPerTray = TextEditingController(text: s(u['eggs_per_tray'] ?? 30));
  }

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

  Future<void> _changePassword() async {
    final cur = TextEditingController(), next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Change password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: cur,
              obscureText: true,
              decoration: dec(c, 'Current password')),
          const SizedBox(height: 12),
          TextField(
              controller: next,
              obscureText: true,
              decoration: dec(c, 'New password (min 6)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Update')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.instance.post('/profile/password',
          {'current_password': cur.text, 'new_password': next.text});
      if (mounted) toast(context, 'Password changed');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final cs = Theme.of(context).colorScheme;
    String? req(String? s) => (s ?? '').trim().isEmpty ? 'Required' : null;
    String? num0(String? s) => (double.tryParse((s ?? '').trim()) ?? -1) < 0
        ? 'Enter a valid number'
        : null;
    return Form(
      key: _form,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const PageHeader(
            title: 'Farm Profile & Settings',
            subtitle: 'Manage your farm identity and defaults'),
        AppCard(
          child: Column(children: [
            GestureDetector(
              onTap: _pick,
              child: Stack(children: [
                Stack(children: [
                  _avatar != null
                      ? CircleAvatar(
                          radius: 48, backgroundImage: MemoryImage(_avatar!))
                      : FarmAvatar(
                          url: auth.avatarUrl, name: auth.farmName, radius: 48),
                  if (_saving && _avatar != null)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.4),
                            shape: BoxShape.circle),
                        child: const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                      ),
                    ),
                ]),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                      radius: 15,
                      backgroundColor: cs.primary,
                      child: Icon(Icons.edit, size: 15, color: cs.onPrimary)),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            Text('Registered mobile: ${auth.mobile}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextFormField(
                controller: _farm,
                decoration:
                    dec(context, 'Farm name', icon: Icons.agriculture_outlined),
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
                decoration: dec(context, 'Farm address (printed on invoices)')),
          ]),
        ),
        const SizedBox(height: 14),
        AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Defaults', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _threshold,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: dec(context, 'Low feed-stock alert (bags)'),
              validator: num0,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kg,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: dec(context, 'Kilograms per feed bag'),
              validator: (s) => (double.tryParse((s ?? '').trim()) ?? 0) > 0
                  ? null
                  : 'Must be > 0',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tax,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: dec(context, 'Default tax % for new invoices'),
              validator: num0,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _eggsPerTray,
              keyboardType: TextInputType.number,
              decoration: dec(context, 'Eggs per Tray / Crate'),
              validator: (s) => (int.tryParse((s ?? '').trim()) ?? 0) > 0
                  ? null
                  : 'Must be a whole number greater than 0',
            ),
          ]),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          label: const Text('Save changes'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            onPressed: _changePassword,
            icon: const Icon(Icons.lock_reset),
            label: const Text('Change password')),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: cs.error),
          onPressed: () => auth.logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ]),
    );
  }
}
