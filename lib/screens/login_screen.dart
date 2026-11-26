import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../core/api_client.dart';
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
                ? [AppColors.darkBackground, const Color(0xFF12352F)]
                : [AppColors.cream, const Color(0xFFD9EEE5)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: child),
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
        decoration: BoxDecoration(
          color: AppColors.yolk.withValues(alpha: .2),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.egg, size: 36, color: AppColors.yolk),
      ),
      const SizedBox(height: 14),
      Text(title,
          style: t.textTheme.headlineMedium, textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text(subtitle,
          style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
          textAlign: TextAlign.center),
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
  Timer? _lockoutTimer;
  int _lockoutSeconds = 0;
  bool _accountLocked = false;
  String? _securityMessage;

  String _formatCountdown(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  void _startLockoutCountdown(
    int seconds, {
    required bool accountLocked,
  }) {
    _lockoutTimer?.cancel();
    final duration = seconds > 0 ? seconds : (accountLocked ? 900 : 60);
    setState(() {
      _accountLocked = accountLocked;
      _lockoutSeconds = duration;
      _securityMessage = _countdownMessage();
    });
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockoutSeconds--;
        if (_lockoutSeconds <= 0) {
          _lockoutSeconds = 0;
          _securityMessage = null;
          timer.cancel();
        } else {
          _securityMessage = _countdownMessage();
        }
      });
    });
  }

  String _countdownMessage() {
    final time = _formatCountdown(_lockoutSeconds);
    return _accountLocked
        ? 'Account temporarily locked. Try again in $time or reset via Forgot password?'
        : 'Too many requests. Try again in $time.';
  }

  void _showLoginError(Object error) {
    if (error is ApiException && (error.status == 423 || error.status == 429)) {
      _startLockoutCountdown(
        error.retryAfterSeconds ?? 0,
        accountLocked: error.status == 423,
      );
      return;
    }
    if (error is ApiException && error.message.contains('attempts remaining')) {
      _lockoutTimer?.cancel();
      setState(() {
        _lockoutSeconds = 0;
        _accountLocked = false;
        _securityMessage = error.message;
      });
      return;
    }
    if (mounted) toast(context, '$error', error: true);
  }

  Future<void> _forgotPassword() async {
    final reset = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ForgotPasswordSheet(),
    );
    if (reset == true && mounted) {
      toast(context, 'Password updated! Please login.');
    }
  }

  Future<void> _submit() async {
    if (_lockoutSeconds > 0) return;
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context
          .read<AuthState>()
          .login(_mobile.text.trim(), _password.text);
    } catch (e) {
      if (mounted) _showLoginError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _mobile.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: AppCard(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(children: [
            const BrandHeader(
                title: 'Egg Farm Manager',
                subtitle: 'Sign in to manage your farm'),
            TextFormField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration:
                  dec(context, 'Mobile number', icon: Icons.phone_outlined),
              validator: (s) =>
                  RegExp(r'^[6-9]\d{9}$').hasMatch((s ?? '').trim())
                      ? null
                      : 'Enter a valid 10-digit mobile number',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _hide,
              onFieldSubmitted: (_) => _submit(),
              decoration:
                  dec(context, 'Password', icon: Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                      _hide
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              validator: (s) =>
                  (s ?? '').isEmpty ? 'Enter your password' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgotPassword,
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 20),
            if (_securityMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer
                      .withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: .55),
                  ),
                ),
                child: Text(
                  _securityMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy || _lockoutSeconds > 0 ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Login'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
                onPressed: () => context.go('/signup'),
                child: const Text("New farm? Create an account")),
            const SizedBox(height: 4),
            const AndroidAppDownloadButton(),
          ]),
        ),
      ),
    );
  }
}

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet();

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text.trim())) {
      toast(context, 'Enter a valid 10-digit mobile number', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthState>().sendResetOtp(_phone.text.trim());
      if (!mounted) return;
      setState(() => _otpSent = true);
      toast(context, 'OTP sent to +91 ${_phone.text.trim()}');
    } catch (error) {
      if (mounted) toast(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthState>().resetPassword(
            phone: _phone.text.trim(),
            otp: _otp.text.trim(),
            newPassword: _newPassword.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) toast(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Reset password',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('Verify your registered mobile number to continue.'),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                readOnly: _otpSent,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: dec(context, 'Mobile number',
                    hint: '10 digit number', icon: Icons.phone_outlined),
                validator: (value) =>
                    RegExp(r'^[6-9]\d{9}$').hasMatch((value ?? '').trim())
                        ? null
                        : 'Enter a valid 10-digit mobile number',
              ),
              if (!_otpSent) ...[
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _busy ? null : _sendOtp,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send OTP'),
                ),
              ],
              if (_otpSent) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration:
                      dec(context, '6-digit OTP', icon: Icons.lock_clock),
                  validator: (value) =>
                      RegExp(r'^\d{6}$').hasMatch((value ?? '').trim())
                          ? null
                          : 'Enter the 6-digit OTP',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPassword,
                  obscureText: true,
                  decoration: dec(context, 'New password'),
                  validator: (value) => RegExp(
                              r'^(?=.*[A-Za-z])(?=.*\d).{8,100}$')
                          .hasMatch(value ?? '')
                      ? null
                      : 'Use 8-100 characters with at least one letter and one number',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPassword,
                  obscureText: true,
                  decoration: dec(context, 'Confirm new password'),
                  validator: (value) => value == _newPassword.text
                      ? null
                      : 'Passwords do not match',
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : _resetPassword,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reset Password'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
