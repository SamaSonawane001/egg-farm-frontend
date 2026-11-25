import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_state.dart';
import '../core/razorpay_gateway.dart';
import 'common.dart';

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
    try {
      final auth = context.read<AuthState>();
      final order = Map<String, dynamic>.from(
        await ApiClient.instance.post(
          '/subscription/create-order',
          {'terms_accepted': true},
        ),
      );
      final checkout = await openRazorpayCheckout(
        keyId: '${order['key_id']}',
        orderId: '${order['order_id']}',
        amount: (order['amount'] as num).toInt(),
        currency: '${order['currency']}',
        ownerName: auth.ownerName,
        contact: _contact(auth.mobile),
      );
      final result = Map<String, dynamic>.from(
        await ApiClient.instance.post(
          '/subscription/verify-payment',
          {
            'razorpay_order_id': checkout.orderId,
            'razorpay_payment_id': checkout.paymentId,
            'razorpay_signature': checkout.signature,
          },
        ),
      );
      if (!mounted) return;
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
        if (message.contains('Refresh payment status')) _pending = true;
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
    return AlertDialog(
      title: const Text('Annual Pro Subscription'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Annual Pro Plan • ₹899 / 1 Year (365 Days) • Unlimited Invoices & Multi-Farm Access',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (_pending)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Payment Pending Confirmation\n'
                    'Invoices stay locked until Razorpay confirms the payment. '
                    'UPI or bank confirmation may take a little time.',
                  ),
                )
              else
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _termsAccepted,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: _busy
                      ? null
                      : (value) =>
                          setState(() => _termsAccepted = value ?? false),
                  title: const Text(
                    'I agree to the Subscription Terms (English / मराठी): '
                    'Valid for 365 days from payment. You can cancel anytime '
                    'from Farm Profile; upon cancellation, access continues '
                    'until the 1-year expiry date with no partial or full refund.\n\n'
                    'मी सदस्यता अटींना सहमत आहे: पेमेंटनंतर 365 दिवस वैध. '
                    'Farm Profile मधून कधीही रद्द करता येईल; रद्द केल्यावरही '
                    'मुदत संपेपर्यंत प्रवेश सुरू राहील आणि अंशतः किंवा पूर्ण '
                    'परतावा मिळणार नाही.',
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: colors.error)),
              ],
              const SizedBox(height: 6),
              Text(
                'Account: ${auth.ownerName} • ${auth.mobile}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : _pending
                  ? _refreshPayment
                  : _termsAccepted
                      ? _pay
                      : null,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _pending ? 'Refresh Payment Status' : 'Pay ₹899 Now',
                ),
        ),
      ],
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
                child: const Text('Renew / Upgrade (₹899/yr)'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
