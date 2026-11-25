import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'razorpay_checkout_result.dart';

Future<RazorpayCheckoutResult> openRazorpayCheckout({
  required String keyId,
  required String orderId,
  required int amount,
  required String currency,
  required String ownerName,
  required String contact,
}) async {
  final gateway = Razorpay();
  final completer = Completer<RazorpayCheckoutResult>();
  gateway.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
    if (completer.isCompleted) return;
    final paymentId = response.paymentId;
    final responseOrderId = response.orderId;
    final signature = response.signature;
    if (paymentId == null || responseOrderId == null || signature == null) {
      completer.completeError(
        const RazorpayCheckoutException(
          'Razorpay returned an incomplete payment response.',
        ),
      );
      return;
    }
    completer.complete(
      RazorpayCheckoutResult(
        orderId: responseOrderId,
        paymentId: paymentId,
        signature: signature,
      ),
    );
  });
  gateway.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
    if (!completer.isCompleted) {
      completer.completeError(
        RazorpayCheckoutException(
          response.message ?? 'Payment failed or was cancelled.',
        ),
      );
    }
  });
  gateway.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
    if (!completer.isCompleted) {
      completer.completeError(
        RazorpayCheckoutException(
          'Payment moved to ${response.walletName ?? 'an external wallet'}. '
          'Refresh payment status before retrying.',
        ),
      );
    }
  });
  try {
    gateway.open({
      'key': keyId,
      'amount': amount,
      'currency': currency,
      'name': 'Egg Farm Manager',
      'description': 'Annual Pro Plan — 365 days',
      'order_id': orderId,
      'prefill': {
        'name': ownerName,
        'contact': contact,
      },
      'theme': {'color': '#0F766E'},
    });
    return await completer.future;
  } finally {
    gateway.clear();
  }
}
