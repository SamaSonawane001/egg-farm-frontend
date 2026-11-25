import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/auth_state.dart';
import '../widgets/common.dart';
import '../widgets/legal_documents.dart';
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
  bool _consentAccepted = false;
  bool _sendingOtp = false, _otpSent = false, _verifyingOtp = false;
  String? _otpPhone, _verifiedPhone, _phoneVerificationToken;
  final _otp = TextEditingController();
  Timer? _resendTimer;
  int _resendSeconds = 0;
  late final _termsTap = TapGestureRecognizer()..onTap = _openLegalDocuments;
  late final _privacyTap = TapGestureRecognizer()..onTap = _openLegalDocuments;

  void _openLegalDocuments() {
    showLegalDocuments(context);
  }

  @override
  void initState() {
    super.initState();
    _mobile.addListener(_onMobileChanged);
  }

  void _onMobileChanged() {
    if (_otpPhone == null || _mobile.text.trim() == _otpPhone) return;
    _resendTimer?.cancel();
    setState(() {
      _otpPhone = null;
      _verifiedPhone = null;
      _phoneVerificationToken = null;
      _otpSent = false;
      _resendSeconds = 0;
      _otp.clear();
    });
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendSeconds <= 1) {
          _resendSeconds = 0;
          timer.cancel();
        } else {
          _resendSeconds--;
        }
      });
    });
  }

  Future<void> _sendOtp() async {
    final phone = _mobile.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      toast(context, 'Enter a valid 10-digit mobile number', error: true);
      return;
    }
    setState(() => _sendingOtp = true);
    try {
      await context.read<AuthState>().sendSignupOtp(phone);
      if (!mounted) return;
      setState(() {
        _otpPhone = phone;
        _otpSent = true;
        _otp.clear();
      });
      _startResendCountdown();
      toast(context, 'OTP sent to +91 $phone');
    } catch (error) {
      if (mounted) toast(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _mobile.text.trim();
    if (_otpPhone != phone || !RegExp(r'^\d{6}$').hasMatch(_otp.text.trim())) {
      toast(context, 'Enter the 6-digit OTP', error: true);
      return;
    }
    setState(() => _verifyingOtp = true);
    try {
      final token = await context
          .read<AuthState>()
          .verifySignupOtp(phone, _otp.text.trim());
      if (!mounted) return;
      _resendTimer?.cancel();
      setState(() {
        _verifiedPhone = phone;
        _phoneVerificationToken = token;
        _otpSent = false;
        _resendSeconds = 0;
      });
      toast(context, 'Mobile number verified');
    } catch (error) {
      if (mounted) toast(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  void _changeNumber() {
    _resendTimer?.cancel();
    setState(() {
      _otpPhone = null;
      _verifiedPhone = null;
      _phoneVerificationToken = null;
      _otpSent = false;
      _resendSeconds = 0;
      _otp.clear();
    });
    _mobile.clear();
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 600, imageQuality: 80);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _avatar = bytes;
      _avatarName = x.name;
    });
  }

  Future<void> _submit() async {
    final verificationToken = _phoneVerificationToken;
    if (verificationToken == null || _verifiedPhone != _mobile.text.trim()) {
      toast(context, 'Verify your mobile number before creating an account',
          error: true);
      return;
    }
    if (!_consentAccepted) {
      toast(context, 'Confirm your age and accept the Terms & Privacy Policy',
          error: true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthState>().register(
            mobile: _mobile.text.trim(),
            password: _password.text,
            ownerName: _owner.text.trim(),
            farmName: _farm.text.trim(),
            phoneVerificationToken: verificationToken,
            consentAccepted: _consentAccepted,
            consentVersion: 'v1.0-2027',
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
  void dispose() {
    _resendTimer?.cancel();
    _mobile.removeListener(_onMobileChanged);
    _owner.dispose();
    _farm.dispose();
    _mobile.dispose();
    _password.dispose();
    _confirm.dispose();
    _otp.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
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
            const BrandHeader(
                title: 'Create your farm account',
                subtitle: 'Your data stays private to your farm'),
            GestureDetector(
              onTap: _pick,
              child: Stack(children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: cs.primary.withValues(alpha: .12),
                  backgroundImage:
                      _avatar == null ? null : MemoryImage(_avatar!),
                  child: _avatar == null
                      ? Icon(Icons.add_a_photo_outlined,
                          color: cs.primary, size: 28)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                      radius: 14,
                      backgroundColor: cs.primary,
                      child: Icon(Icons.edit, size: 14, color: cs.onPrimary)),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            Text('Farm / owner photo (optional)',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextFormField(
                controller: _owner,
                decoration:
                    dec(context, 'Owner name', icon: Icons.person_outline),
                validator: req),
            const SizedBox(height: 12),
            TextFormField(
                controller: _farm,
                decoration:
                    dec(context, 'Farm name', icon: Icons.agriculture_outlined),
                validator: req),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _mobile,
                    readOnly: _phoneVerificationToken != null ||
                        _sendingOtp ||
                        _verifyingOtp,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: dec(
                      context,
                      'Mobile number',
                      hint: '10 digit number',
                      icon: Icons.phone_outlined,
                    ).copyWith(
                      suffixIcon: _phoneVerificationToken == null
                          ? null
                          : const Icon(Icons.verified, color: Colors.green),
                    ),
                    validator: (s) =>
                        RegExp(r'^[6-9]\d{9}$').hasMatch((s ?? '').trim())
                            ? null
                            : 'Enter a valid 10-digit mobile number',
                  ),
                ),
                const SizedBox(width: 8),
                if (_phoneVerificationToken == null && !_otpSent)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton(
                      onPressed: _sendingOtp || _verifyingOtp ? null : _sendOtp,
                      child: _sendingOtp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send OTP'),
                    ),
                  )
                else if (_phoneVerificationToken == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 18),
                    child: Text('OTP sent'),
                  ),
              ],
            ),
            if (_phoneVerificationToken != null)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Chip(
                      avatar: Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                      label: Text('Verified'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _changeNumber,
                      child: const Text('Change number'),
                    ),
                  ],
                ),
              ),
            if (_otpSent && _phoneVerificationToken == null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enter the 6-digit OTP sent to +91 $_otpPhone'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _otp,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: dec(context, 'OTP', icon: Icons.lock_clock),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton.tonal(
                          onPressed:
                              _verifyingOtp || _sendingOtp ? null : _verifyOtp,
                          child: _verifyingOtp
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Verify OTP'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed:
                              _resendSeconds > 0 || _sendingOtp || _verifyingOtp
                                  ? null
                                  : _sendOtp,
                          child: Text(_resendSeconds > 0
                              ? 'Resend OTP (${_resendSeconds}s)'
                              : 'Resend OTP'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _hide,
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
              validator: (s) => RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,100}$')
                      .hasMatch(s ?? '')
                  ? null
                  : 'Use 8-100 characters with at least one letter and one number',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: _hide,
              decoration:
                  dec(context, 'Confirm password', icon: Icons.lock_outline),
              validator: (s) =>
                  s == _password.text ? null : 'Passwords do not match',
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: _consentAccepted,
                    onChanged: _busy
                        ? null
                        : (value) => setState(
                              () => _consentAccepted = value ?? false,
                            ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodySmall,
                        children: [
                          const TextSpan(text: 'I am 18+ and agree to the '),
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: _termsTap,
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: _privacyTap,
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ||
                        _phoneVerificationToken == null ||
                        _verifiedPhone != _mobile.text.trim() ||
                        !_consentAccepted
                    ? null
                    : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create account'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Already registered? Login')),
          ]),
        ),
      ),
    );
  }
}
