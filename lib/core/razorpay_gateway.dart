import 'razorpay_checkout_result.dart';
import 'razorpay_gateway_stub.dart'
    if (dart.library.html) 'razorpay_gateway_web.dart'
    if (dart.library.io) 'razorpay_gateway_mobile.dart' as implementation;

export 'razorpay_checkout_result.dart';

Future<RazorpayCheckoutResult> openRazorpayCheckout({
  required String keyId,
  required String orderId,
  required int amount,
  required String currency,
  required String ownerName,
  required String contact,
}) =>
    implementation.openRazorpayCheckout(
      keyId: keyId,
      orderId: orderId,
      amount: amount,
      currency: currency,
      ownerName: ownerName,
      contact: contact,
    );
