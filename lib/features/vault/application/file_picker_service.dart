import 'package:file_picker/file_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_picker_service.g.dart';

class FilePickerService {
  Future<FilePickerResult?> pickFile() async {
    try {
      // Pick a single file
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      return result;
    } catch (e) {
      // Handle potential platform exceptions
      return null;
    }
  }
}

@riverpod
FilePickerService filePickerService(Ref ref) {
  return FilePickerService();
}
