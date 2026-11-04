import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';

const int _maxBillSize = 15 * 1024 * 1024;

class BillUploadController extends ChangeNotifier {
  Uint8List? bytes;
  String? fileName;
  String? fileUrl;
  String? error;
  bool uploading = false;

  void select(Uint8List data, String name) {
    if (data.length > _maxBillSize) {
      remove();
      error =
          'File size is ${(data.length / (1024 * 1024)).toStringAsFixed(1)}MB. Maximum allowed is 15MB.';
      notifyListeners();
      return;
    }
    bytes = data;
    fileName = name;
    fileUrl = null;
    error = null;
    notifyListeners();
  }

  void remove() {
    bytes = null;
    fileName = null;
    fileUrl = null;
    error = null;
    notifyListeners();
  }

  void setError(String message) {
    error = message;
    notifyListeners();
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  void rejectFileSize(int size) {
    bytes = null;
    fileName = null;
    fileUrl = null;
    error =
        'File size is ${(size / (1024 * 1024)).toStringAsFixed(1)}MB. Maximum allowed is 15MB.';
    notifyListeners();
  }

  Future<String?> upload({required String moduleName}) async {
    if (bytes == null || fileName == null) return fileUrl;
    if (fileUrl != null) return fileUrl;
    uploading = true;
    error = null;
    notifyListeners();
    try {
      final name = fileName!.trim().isEmpty
          ? 'receipt_${DateTime.now().millisecondsSinceEpoch}.bin'
          : fileName!;
      final extension =
          name.contains('.') ? name.split('.').last.toLowerCase() : 'bin';
      final contentType = switch (extension) {
        'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
        'png' => MediaType('image', 'png'),
        'pdf' => MediaType('application', 'pdf'),
        'webp' ||
        'heic' ||
        'heif' ||
        'bmp' ||
        'gif' =>
          MediaType('image', extension),
        _ => MediaType('application', 'octet-stream'),
      };
      final result = await ApiClient.instance.multipart(
        'POST',
        '/upload/bill',
        {'category': moduleName},
        fileBytes: bytes,
        fileName: name,
        fileField: 'file',
        contentType: contentType,
      );
      if (result is! Map ||
          result['success'] != true ||
          result['fileUrl'] is! String) {
        throw ApiException('The server did not return a bill URL.');
      }
      fileUrl = result['fileUrl'] as String;
      return fileUrl;
    } catch (e) {
      error = '$e';
      rethrow;
    } finally {
      uploading = false;
      notifyListeners();
    }
  }
}

class BillUploadPicker extends StatelessWidget {
  final BillUploadController controller;
  final String moduleName;
  const BillUploadPicker(
      {super.key, required this.controller, required this.moduleName});

  Future<void> _pick(BuildContext context) async {
    try {
      if (kIsWeb) {
        await _pickFile();
      } else {
        final source = await showModalBottomSheet<ImageSource>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery / Files'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ]),
          ),
        );
        if (source == ImageSource.camera) {
          final image = await ImagePicker().pickImage(
            source: source!,
            maxWidth: 2048,
            maxHeight: 2048,
            imageQuality: 85,
          );
          if (image != null) {
            controller.select(await image.readAsBytes(), image.name);
          }
        } else if (source == ImageSource.gallery) {
          await _pickFile();
        }
      }
    } catch (e) {
      controller.setError('Could not select the bill: $e');
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.size > _maxBillSize) {
      controller.rejectFileSize(file.size);
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      throw ApiException('Could not read the selected file. Please try again.');
    }
    controller.select(bytes, file.name);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final bytes = controller.bytes;
          final name = controller.fileName;
          final extension = name?.split('.').last.toLowerCase();
          final isPdf = extension == 'pdf';
          final isPreviewableImage =
              const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: controller.uploading ? null : () => _pick(context),
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(kIsWeb
                    ? 'Upload Bill / पावतीचा फोटो'
                    : 'Camera or Gallery · पावती'),
              ),
              if (bytes != null && name != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: isPdf
                          ? const ColoredBox(
                              color: Color(0xFFF2F3F4),
                              child: Icon(Icons.picture_as_pdf_outlined,
                                  size: 36, color: Colors.red),
                            )
                          : isPreviewableImage
                              ? Image.memory(
                                  bytes,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const ColoredBox(
                                    color: Color(0xFFF2F3F4),
                                    child: Icon(
                                        Icons.insert_drive_file_outlined,
                                        size: 36),
                                  ),
                                )
                              : const ColoredBox(
                                  color: Color(0xFFF2F3F4),
                                  child: Icon(Icons.insert_drive_file_outlined,
                                      size: 36),
                                ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: controller.uploading ? null : controller.remove,
                    child: const Text('Remove / बदल करा'),
                  ),
                ]),
                if (controller.fileUrl != null) const Text('Bill uploaded'),
              ],
              if (controller.uploading)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(children: [
                    SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Uploading bill…'),
                  ]),
                ),
              if (controller.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(controller.error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              if (bytes != null && controller.fileUrl == null)
                Text(
                  'The receipt uploads when you save this inward entry (max 15 MB).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          );
        },
      );
}

Future<void> showBillPreview(BuildContext context, String? url) async {
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  final extension = uri?.pathSegments.isNotEmpty == true
      ? uri!.pathSegments.last.split('.').last.toLowerCase()
      : '';
  final isPreviewableImage =
      const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension);
  if (!isPreviewableImage) {
    final opened =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this bill file.')),
      );
    }
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bill / Receipt'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: .5,
            maxScale: 5,
            child: Image.network(
              url,
              errorBuilder: (_, __, ___) =>
                  const Text('Could not load this bill image.'),
            ),
          ),
        ),
      ),
    ),
  );
}
