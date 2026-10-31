import 'dart:typed_data';

import 'package:egg_farm/widgets/bill_upload_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts supported receipt extensions within the upload limit', () {
    final controller = BillUploadController();

    controller.select(Uint8List.fromList([1, 2, 3]), 'receipt.webp');

    expect(controller.fileName, 'receipt.webp');
    expect(controller.bytes, isNotNull);
    expect(controller.error, isNull);
    controller.dispose();
  });

  test('rejects unsupported receipt file types', () {
    final controller = BillUploadController();

    controller.select(Uint8List.fromList([1, 2, 3]), 'receipt.gif');

    expect(controller.bytes, isNull);
    expect(controller.error, contains('JPG, PNG, WebP or PDF'));
    controller.dispose();
  });

  test('rejects receipt files larger than five megabytes', () {
    final controller = BillUploadController();

    controller.select(Uint8List(5 * 1024 * 1024 + 1), 'receipt.pdf');

    expect(controller.bytes, isNull);
    expect(controller.error, contains('no larger than 5 MB'));
    controller.dispose();
  });
}
