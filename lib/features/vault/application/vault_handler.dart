import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:local_sync/features/transport/transport_protocol.dart';
import 'package:local_sync/features/vault/data/vault_repository.dart';
import 'package:local_sync/features/vault/domain/vault_file_header.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'vault_handler.g.dart';

class VaultHandlerException implements Exception {
  final String message;
  VaultHandlerException(this.message);
  @override
  String toString() => message;
}

class VaultHandler {
  final VaultRepository _repository;
  final Uuid _uuid;
  final void Function() _onFileHandled;
  final Directory _vaultDir; // Injected to know where to save

  VaultHandler(
    this._repository,
    this._uuid,
    this._onFileHandled,
    this._vaultDir,
  );

  /// Handles an incoming Vault File packet.
  /// [messageData] contains: [HL (4)] [HeaderJSON] [Ciphertext]
  Future<void> handleMessage(Uint8List messageData) async {
    try {
      // 1. Parse Header Length
      if (messageData.length < TransportProtocol.headerLengthBytes) {
        throw VaultHandlerException(
          'Incomplete packet (missing header length).',
        );
      }
      final headerLenBytes = messageData.sublist(
        0,
        TransportProtocol.headerLengthBytes,
      );
      final headerLen = ByteData.sublistView(headerLenBytes).getUint32(0);

      // 2. Parse JSON Header
      final headerStart = TransportProtocol.headerLengthBytes;
      final headerEnd = headerStart + headerLen;

      if (messageData.length < headerEnd) {
        throw VaultHandlerException('Incomplete packet (missing header data).');
      }
      final headerJsonBytes = messageData.sublist(headerStart, headerEnd);
      final header = VaultFileHeader.fromJson(utf8.decode(headerJsonBytes));

      // 3. Extract Ciphertext
      // Note: On the receiver side, with the current packet reassembler,
      // this is still in RAM.
      final ciphertext = messageData.sublist(headerEnd);

      // 4. Generate ID and Path
      final fileId = _uuid.v4();
      final savePath = p.join(_vaultDir.path, fileId);

      // 5. Write Ciphertext to Disk
      // We manually write it here because Repo doesn't accept bytes anymore.
      final file = File(savePath);
      await file.writeAsBytes(ciphertext);

      // 6. Decode Nonce
      final nonce = base64Decode(header.nonce);

      // 7. Save Metadata
      await _repository.addFile(
        id: fileId,
        filename: header.filename,
        nonce: nonce,
        ciphertextPath: savePath,
      );

      _onFileHandled();
    } catch (e) {
      throw VaultHandlerException('Failed to process incoming file: $e');
    }
  }
}

@riverpod
Uuid uuid(Ref ref) => const Uuid();

@riverpod
Future<VaultHandler> vaultHandler(Ref ref) async {
  final repository = await ref.watch(vaultRepositoryProvider.future);
  final uuid = ref.watch(uuidProvider);

  // Need the directory to save incoming files
  final appDocsDir = await ref.watch(appDocumentsDirectoryProvider.future);
  final vaultDir = Directory(p.join(appDocsDir.path, 'SecureVaultData'));
  if (!vaultDir.existsSync()) {
    vaultDir.createSync(recursive: true);
  }

  return VaultHandler(repository, uuid, () {
    ref.invalidate(vaultFilesProvider);
  }, vaultDir);
}
