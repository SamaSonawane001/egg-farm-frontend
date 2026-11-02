import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'invoice_pdf_file_stub.dart'
    if (dart.library.io) 'invoice_pdf_file_io.dart' as implementation;

Future<XFile> createInvoicePdfFile(
  Uint8List bytes,
  String invoiceNumber, {
  String fileNamePrefix = 'Invoice_',
}) =>
    implementation.createInvoicePdfFile(
      bytes,
      invoiceNumber,
      fileNamePrefix: fileNamePrefix,
    );
