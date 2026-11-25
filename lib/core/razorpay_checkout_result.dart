class RazorpayCheckoutResult {
  final String orderId;
  final String paymentId;
  final String signature;

  const RazorpayCheckoutResult({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });
}

class RazorpayCheckoutException implements Exception {
  final String message;

  const RazorpayCheckoutException(this.message);

  @override
  String toString() => message;
}
