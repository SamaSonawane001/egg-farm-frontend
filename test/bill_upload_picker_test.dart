import 'dart:typed_data';

import 'package:egg_farm/widgets/bill_upload_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts any receipt extension within the upload limit', () {
    final controller = BillUploadController();

    controller.select(Uint8List.fromList([1, 2, 3]), 'shared image.docx');

    expect(controller.fileName, 'shared image.docx');
    expect(controller.bytes, isNotNull);
    expect(controller.error, isNull);
    controller.dispose();
  });

  test('clears an upload error when a new receipt is selected or removed', () {
    final controller = BillUploadController();

    controller.setError('Upload failed');
    controller.select(Uint8List.fromList([1, 2, 3]), 'receipt.gif');
    expect(controller.error, isNull);

    controller.setError('Upload failed');
    controller.remove();
    expect(controller.error, isNull);
    controller.dispose();
  });

  test('rejects receipt files larger than fifteen megabytes with exact size',
      () {
    final controller = BillUploadController();

    controller.select(Uint8List(15 * 1024 * 1024 + 1), 'receipt.pdf');

    expect(controller.bytes, isNull);
    expect(controller.error, contains('Maximum allowed is 15MB'));
    expect(controller.error, contains('15.0MB'));
    controller.dispose();
  });
}
