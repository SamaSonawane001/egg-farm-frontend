import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_state.dart';
import '../core/razorpay_gateway.dart';
import 'common.dart';
import 'legal_documents.dart';

Future<bool> showSubscriptionPaywall(
  BuildContext context, {
  bool paymentPending = false,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SubscriptionPaywallDialog(
          initiallyPending: paymentPending,
        ),
      ) ??
      false;
}

class SubscriptionPaywallDialog extends StatefulWidget {
  final bool initiallyPending;

  const SubscriptionPaywallDialog({
    super.key,
    this.initiallyPending = false,
  });

  @override
  State<SubscriptionPaywallDialog> createState() =>
      _SubscriptionPaywallDialogState();
}

class _SubscriptionPaywallDialogState extends State<SubscriptionPaywallDialog> {
  bool _termsAccepted = false;
  bool _busy = false;
  late bool _pending;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pending = widget.initiallyPending;
  }

  String _contact(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return digits;
  }

  Future<void> _pay() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    var paymentSucceeded = false;
    Map<String, dynamic>? verificationResult;
    try {
      final auth = context.read<AuthState>();
      final order = Map<String, dynamic>.from(
        await ApiClient.instance.post(
          '/subscription/create-order',
          {'terms_accepted': true},
        ),
      );
      await openRazorpayCheckout(
        keyId: '${order['key_id']}',
        orderId: '${order['order_id']}',
        amount: (order['amount'] as num).toInt(),
        currency: '${order['currency']}',
        ownerName: auth.ownerName,
        contact: _contact(auth.mobile),
        onPaymentSuccess: (payment) async {
          paymentSucceeded = true;
          verificationResult = Map<String, dynamic>.from(
            await ApiClient.instance.post(
              '/subscription/verify-payment',
              {
                'razorpay_order_id': payment.orderId,
                'razorpay_payment_id': payment.paymentId,
                'razorpay_signature': payment.signature,
              },
            ),
          );
        },
      );
      if (!mounted) return;
      final result = verificationResult;
      if (result == null) {
        throw StateError('Payment verification did not return a result.');
      }
      if (result['status'] == 'ACTIVE') {
        toast(context, 'Annual Pro subscription activated');
        Navigator.of(context).pop(true);
      } else if (result['status'] == 'PENDING') {
        setState(() {
          _pending = true;
          _termsAccepted = false;
        });
      } else {
        setState(() => _error = 'Payment status: ${result['status']}');
      }
    } catch (error) {
      if (!mounted) return;
      final message = '$error';
      setState(() {
        _error = message;
        if (paymentSucceeded || message.contains('Refresh payment status')) {
          _pending = true;
          _termsAccepted = false;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshPayment() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = Map<String, dynamic>.from(
        await ApiClient.instance.post(
          '/subscription/refresh-payment',
          const {},
        ),
      );
      if (!mounted) return;
      if (status['status'] == 'ACTIVE') {
        toast(context, 'Payment confirmed. Annual Pro is active.');
        Navigator.of(context).pop(true);
        return;
      }
      if (status['payment_status'] != 'PENDING') {
        setState(() {
          _pending = false;
          _termsAccepted = false;
          _error = 'Payment was not captured. You can safely retry.';
        });
      } else {
        setState(() {
          _pending = true;
          _error = 'Payment is still awaiting bank or UPI confirmation.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFF40D9A2);
    final proFeatures = [
      'Unlimited Invoices & PDF Billing',
      'Multi-Farm / Multi-Shed Management',
      'Central Godown Shared Inventory & Medicines',
      'Full Profit/Loss, Khata & Analytics Reports',
      'Cloud Backup & Priority Support',
    ];
    final trialFeatures = [
      'Up to 3 free invoices',
      'Basic flock, feed & egg tracking',
      'Single farm dashboard preview',
    ];

    Widget feature(String label, {required Color foreground}) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle, size: 19, color: accent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: foreground, height: 1.25),
                ),
              ),
            ],
          ),
        );

    Widget trialCard() => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Free Trial',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 4),
              Text('Starter',
                  style: TextStyle(color: colors.onSurfaceVariant)),
              const SizedBox(height: 16),
              const Text(
                '₹0',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              Text('/ 3 Invoices',
                  style: TextStyle(color: colors.onSurfaceVariant)),
              const SizedBox(height: 10),
              for (final item in trialFeatures)
                feature(item, foreground: colors.onSurface),
            ],
          ),
        );

    Widget proCard() => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF123D36), Color(0xFF101D32)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: .8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: .18),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: accent.withValues(alpha: .52)),
                  ),
                  child: const Text(
                    'RECOMMENDED',
                    style: TextStyle(
                      color: Color(0xFF8FF0C7),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              Text(
                'Annual Pro Plan',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 14),
              const Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 7,
                children: [
                  Text(
                    '₹1,599',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 3),
                    child: Text(
                      '/ year',
                      style: TextStyle(color: Color(0xFFB7C9C5)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '365 Days • One-Time Payment, No Auto-Pay',
                style: TextStyle(
                  color: Color(0xFF8FF0C7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              for (final item in proFeatures)
                feature(item, foreground: Colors.white),
            ],
          ),
        );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 940,
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF111C2D) : colors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .42 : .18),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plans & Pricing',
                            style:
                                Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Choose Your Plan',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 650) {
                      return Column(
                        children: [
                          trialCard(),
                          const SizedBox(height: 14),
                          proCard(),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: trialCard()),
                        const SizedBox(width: 16),
                        Expanded(child: proCard()),
                      ],
                    );
                  },
                ),
                if (_pending) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.tertiaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Payment Pending Confirmation\n'
                      'Invoices stay locked until Razorpay confirms the payment. '
                      'UPI or bank confirmation may take a little time.',
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _termsAccepted,
                        onChanged: _busy
                            ? null
                            : (value) =>
                                setState(() => _termsAccepted = value ?? false),
                      ),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('I agree to the '),
                            InkWell(
                              onTap: () => showLegalDocuments(context),
                              child: Text(
                                'Terms & Conditions',
                                style: TextStyle(
                                  color: colors.primary,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Text(' & No-Refund Policy'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.tertiaryContainer.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.tertiary.withValues(alpha: .3),
                      ),
                    ),
                    child: Text(
                      '• One-time ₹1,599 payment (No auto-debit). If cancelled anytime from Farm Profile, no refund is issued, and your Pro access stays active until the full 1-year (365 days) expiry.\n'
                      '• एकदाच ₹1,599 पेमेंट (ऑटो-पे नाही). Farm Profile मधून कधीही रद्द केले तरी पैसे परत मिळणार नाहीत, पण तुमचा प्लॅन पूर्ण १ वर्ष (३६५ दिवस) सुरू राहील.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.45,
                            color: colors.onSurface,
                          ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: colors.error)),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF0B9B74),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _busy
                      ? null
                      : _pending
                          ? _refreshPayment
                          : _termsAccepted
                              ? _pay
                              : null,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _pending
                              ? 'Refresh Payment Status'
                              : 'Pay ₹1,599 Now',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                if (_pending) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: _busy ? null : _pay,
                    icon: const Icon(Icons.payment),
                    label: const Text(
                      'Retry Payment (Pay ₹1,599 Now)',
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Account: ${auth.ownerName} • ${auth.mobile}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SubscriptionManagementCard extends StatelessWidget {
  final Map<String, dynamic> status;
  final VoidCallback reload;

  const SubscriptionManagementCard({
    super.key,
    required this.status,
    required this.reload,
  });

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    final date = DateTime.tryParse('$value')?.toLocal();
    return date == null ? '—' : DateFormat('dd MMM yyyy').format(date);
  }

  Future<void> _cancel(BuildContext context) async {
    final expiry = _formatDate(status['expires_at']);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: Text(
          'You can keep using unlimited invoices until $expiry. '
          'Cancellation stops renewal; no partial or full refund is issued '
          'for the remaining active period.\n\n'
          'रद्द केल्यावरही $expiry पर्यंत अमर्यादित बिले वापरता येतील. '
          'उर्वरित कालावधीसाठी परतावा मिळणार नाही.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep subscription'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ApiClient.instance.post('/subscription/cancel', const {});
      if (!context.mounted) return;
      reload();
      toast(context, 'Subscription cancelled. Access remains until $expiry.');
    } catch (error) {
      if (context.mounted) toast(context, '$error', error: true);
    }
  }

  Future<void> _refreshPayment(BuildContext context) async {
    try {
      final result = Map<String, dynamic>.from(
        await ApiClient.instance.post(
          '/subscription/refresh-payment',
          const {},
        ),
      );
      if (!context.mounted) return;
      reload();
      toast(
        context,
        result['status'] == 'ACTIVE'
            ? 'Payment confirmed. Annual Pro is active.'
            : 'Payment status: ${result['payment_status'] ?? result['status']}',
      );
    } catch (error) {
      if (context.mounted) toast(context, '$error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = '${status['status'] ?? 'TRIAL'}';
    final expiry = _formatDate(status['expires_at']);
    final remaining = (status['remaining_free'] as num?)?.toInt() ?? 0;
    final colors = Theme.of(context).colorScheme;
    final label = switch (state) {
      'ACTIVE' => 'Active Pro • Expires on $expiry',
      'CANCELLED' => 'Cancelled • Active until $expiry',
      'PENDING' => 'Payment Pending',
      'EXPIRED' => 'Subscription Expired',
      'REFUNDED' => 'Subscription Refunded',
      _ => 'Free Trial: $remaining/3 invoices left',
    };
    final canRenew = state == 'TRIAL' ||
        state == 'EXPIRED' ||
        state == 'REFUNDED' ||
        status['show_renewal_warning'] == true;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subscription & Invoices',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(label)),
              Pill(
                state,
                state == 'ACTIVE'
                    ? colors.primary
                    : state == 'PENDING'
                        ? colors.tertiary
                        : state == 'REFUNDED'
                            ? colors.error
                            : colors.secondary,
              ),
            ],
          ),
          if (state == 'PENDING') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _refreshPayment(context),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Payment Status'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final activated = await showSubscriptionPaywall(
                    context,
                    paymentPending: true,
                  );
                  if (activated) reload();
                },
                icon: const Icon(Icons.payment),
                label: const Text('Retry Payment (Pay ₹1,599 Now)'),
              ),
            ),
          ],
          if (state == 'ACTIVE') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancel(context),
                child: const Text('Cancel Subscription'),
              ),
            ),
          ],
          if (canRenew) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final activated = await showSubscriptionPaywall(context);
                  if (activated) reload();
                },
                child: const Text('Renew / Upgrade (₹1,599/yr)'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
