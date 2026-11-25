import 'razorpay_checkout_result.dart';

Future<RazorpayCheckoutResult> openRazorpayCheckout({
  required String keyId,
  required String orderId,
  required int amount,
  required String currency,
  required String ownerName,
  required String contact,
}) =>
    Future.error(
      const RazorpayCheckoutException(
        'Razorpay Checkout is not supported on this platform.',
      ),
    );
