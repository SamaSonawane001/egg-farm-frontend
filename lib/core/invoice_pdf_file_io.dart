import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<XFile> createInvoicePdfFile(
  Uint8List bytes,
  String invoiceNumber, {
  String fileNamePrefix = 'Invoice_',
}) async {
  final tempDir = await getTemporaryDirectory();
  final invoiceDir =
      Directory('${tempDir.path}${Platform.pathSeparator}invoices');
  await invoiceDir.create(recursive: true);
  final safeInvoiceNumber =
      invoiceNumber.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final fileName = '$fileNamePrefix$safeInvoiceNumber.pdf';
  final file = File('${invoiceDir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return XFile(file.path, mimeType: 'application/pdf', name: fileName);
}
