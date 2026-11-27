import 'dart:async';
import 'dart:js_interop';

import 'razorpay_checkout_result.dart';

@JS('window.eggFarmOpenRazorpay')
external JSBoolean _openRazorpay(
  JSString keyId,
  JSString orderId,
  JSNumber amount,
  JSString currency,
  JSString ownerName,
  JSString contact,
  JSFunction onSuccess,
  JSFunction onDismiss,
);

Future<RazorpayCheckoutResult> openRazorpayCheckout({
  required String keyId,
  required String orderId,
  required int amount,
  required String currency,
  required String ownerName,
  required String contact,
  required Future<void> Function(RazorpayCheckoutResult payment)
      onPaymentSuccess,
}) {
  final completer = Completer<RazorpayCheckoutResult>();
  var paymentReceived = false;
  Future<void> verifyPayment(RazorpayCheckoutResult payment) async {
    try {
      await onPaymentSuccess(payment);
      if (!completer.isCompleted) completer.complete(payment);
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
  }

  final onSuccess = ((
    JSString responseOrderId,
    JSString paymentId,
    JSString signature,
  ) {
    if (completer.isCompleted) return;
    final order = responseOrderId.toDart;
    final payment = paymentId.toDart;
    final signed = signature.toDart;
    if (order.isEmpty || payment.isEmpty || signed.isEmpty) {
      completer.completeError(
        const RazorpayCheckoutException(
          'Razorpay returned an incomplete payment response.',
        ),
      );
      return;
    }
    paymentReceived = true;
    unawaited(
      verifyPayment(
        RazorpayCheckoutResult(
          orderId: order,
          paymentId: payment,
          signature: signed,
        ),
      ),
    );
  }).toJS;
  final onDismiss = (() {
    if (!paymentReceived && !completer.isCompleted) {
      completer.completeError(
        const RazorpayCheckoutException('Payment was not completed.'),
      );
    }
  }).toJS;

  if (!_openRazorpay(
    keyId.toJS,
    orderId.toJS,
    amount.toJS,
    currency.toJS,
    ownerName.toJS,
    contact.toJS,
    onSuccess,
    onDismiss,
  ).toDart) {
    throw const RazorpayCheckoutException(
      'Razorpay Checkout did not load. Refresh the page and try again.',
    );
  }
  return completer.future;
}
