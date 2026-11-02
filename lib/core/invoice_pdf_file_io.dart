import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<XFile> createInvoicePdfFile(
    Uint8List bytes, String invoiceNumber) async {
  final tempDir = await getTemporaryDirectory();
  final safeInvoiceNumber =
      invoiceNumber.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final fileName = 'Invoice_$safeInvoiceNumber.pdf';
  final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return XFile(file.path, mimeType: 'application/pdf', name: fileName);
}
