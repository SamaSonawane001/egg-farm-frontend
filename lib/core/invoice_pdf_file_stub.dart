import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<XFile> createInvoicePdfFile(
  Uint8List bytes,
  String invoiceNumber, {
  String fileNamePrefix = 'Invoice_',
}) async {
  final safeInvoiceNumber =
      invoiceNumber.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return XFile.fromData(
    bytes,
    mimeType: 'application/pdf',
    name: '$fileNamePrefix$safeInvoiceNumber.pdf',
  );
}
