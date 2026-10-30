import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _owner = TextEditingController();
  final _farm = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Uint8List? _avatar;
  String? _avatarName;
  bool _busy = false, _hide = true;

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 80);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _avatar = bytes;
      _avatarName = x.name;
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthState>().register(
            mobile: _mobile.text.trim(),
            password: _password.text,
            ownerName: _owner.text.trim(),
            farmName: _farm.text.trim(),
            avatar: _avatar,
            avatarName: _avatarName,
          );
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String? req(String? s) => (s ?? '').trim().isEmpty ? 'Required' : null;
    return AuthScaffold(
      child: AppCard(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(children: [
            const BrandHeader(title: 'Create your farm account', subtitle: 'Your data stays private to your farm'),
            GestureDetector(
              onTap: _pick,
              child: Stack(children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: cs.primary.withOpacity(.12),
                  backgroundImage: _avatar == null ? null : MemoryImage(_avatar!),
                  child: _avatar == null ? Icon(Icons.add_a_photo_outlined, color: cs.primary, size: 28) : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(radius: 14, backgroundColor: cs.primary, child: Icon(Icons.edit, size: 14, color: cs.onPrimary)),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            Text('Farm / owner photo (optional)', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextFormField(controller: _owner, decoration: dec(context, 'Owner name', icon: Icons.person_outline), validator: req),
            const SizedBox(height: 12),
            TextFormField(controller: _farm, decoration: dec(context, 'Farm name', icon: Icons.agriculture_outlined), validator: req),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: dec(context, 'Mobile number', hint: '10 digit number', icon: Icons.phone_outlined),
              validator: (s) => RegExp(r'^[0-9]{10,13}$').hasMatch((s ?? '').trim()) ? null : 'Enter a valid mobile number',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _hide,
              decoration: dec(context, 'Password', icon: Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              validator: (s) => (s ?? '').length < 6 ? 'Minimum 6 characters' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: _hide,
              decoration: dec(context, 'Confirm password', icon: Icons.lock_outline),
              validator: (s) => s == _password.text ? null : 'Passwords do not match',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create account'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => context.go('/login'), child: const Text('Already registered? Login')),
          ]),
        ),
      ),
    );
  }
}
