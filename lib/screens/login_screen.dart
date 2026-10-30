import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AuthScaffold extends StatelessWidget {
  final Widget child;
  const AuthScaffold({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [const Color(0xFF0C0A09), const Color(0xFF052E16)]
                : [AppColors.cream, const Color(0xFFD1FAE5)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class BrandHeader extends StatelessWidget {
  final String title, subtitle;
  const BrandHeader({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.yolk.withOpacity(.2), shape: BoxShape.circle),
        child: const Icon(Icons.egg, size: 36, color: AppColors.yolk),
      ),
      const SizedBox(height: 14),
      Text(title, style: t.textTheme.headlineMedium, textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text(subtitle, style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor), textAlign: TextAlign.center),
      const SizedBox(height: 22),
    ]);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _hide = true;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthState>().login(_mobile.text.trim(), _password.text);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: AppCard(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(children: [
            const BrandHeader(title: 'Egg Farm Manager', subtitle: 'Sign in to manage your farm'),
            TextFormField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: dec(context, 'Mobile number', icon: Icons.phone_outlined),
              validator: (s) => RegExp(r'^[0-9]{10,13}$').hasMatch((s ?? '').trim()) ? null : 'Enter a valid mobile number',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _hide,
              onFieldSubmitted: (_) => _submit(),
              decoration: dec(context, 'Password', icon: Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              validator: (s) => (s ?? '').isEmpty ? 'Enter your password' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Login'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => context.go('/signup'), child: const Text("New farm? Create an account")),
          ]),
        ),
      ),
    );
  }
}
