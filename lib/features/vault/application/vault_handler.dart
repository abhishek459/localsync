import 'dart:convert';
import 'dart:typed_data';

import 'package:local_sync/features/transport/transport_protocol.dart';
import 'package:local_sync/features/vault/data/vault_repository.dart';
import 'package:local_sync/features/vault/domain/vault_file_header.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'vault_handler.g.dart';

/// A custom exception for errors that occur during vault file handling.
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

  VaultHandler(this._repository, this._uuid, this._onFileHandled);

  Future<void> handleMessage(Uint8List messageData) async {
    try {
      // 1. Get Header Length (HL)
      if (messageData.length < TransportProtocol.headerLengthBytes) {
        throw VaultHandlerException(
          'Received an incomplete file packet (missing header length).',
        );
      }
      final headerLenBytes = messageData.sublist(
        0,
        TransportProtocol.headerLengthBytes,
      );
      final headerLen = ByteData.sublistView(headerLenBytes).getUint32(0);

      // 2. Get JSON Header
      final headerStart = TransportProtocol.headerLengthBytes;
      final headerEnd = headerStart + headerLen;

      if (messageData.length < headerEnd) {
        throw VaultHandlerException(
          'Received an incomplete file packet (missing header data).',
        );
      }
      final headerBytes = messageData.sublist(headerStart, headerEnd);
      final headerJson = utf8.decode(headerBytes);
      final header = VaultFileHeader.fromJson(headerJson);

      // 3. Get Ciphertext (everything after the header)
      final ciphertext = messageData.sublist(headerEnd);

      // 4. Generate a new ID
      final fileId = _uuid.v4();

      // 5. Decode metadata from Base64
      final nonce = base64Decode(header.nonce);
      final mac = base64Decode(header.mac);

      // 6. Save to repository
      await _repository.addFile(
        id: fileId,
        filename: header.filename,
        nonce: nonce,
        mac: mac,
        ciphertext: ciphertext,
      );

      // 7. Notify listeners of success
      _onFileHandled();
    } on FormatException catch (e) {
      // Catches bad UTF-8, bad JSON, or bad Base64
      throw VaultHandlerException(
        'Failed to parse incoming file header. Data may be corrupt. (Details: $e)',
      );
    } on RangeError {
      // Catches any .sublist failures
      throw VaultHandlerException(
        'Failed to parse incoming file packet. The packet was malformed or incomplete.',
      );
    } catch (e) {
      // Catch-all for other errors (e.g., repository I/O errors)
      // We re-throw as our custom exception to standardize.
      throw VaultHandlerException(
        'Failed to save incoming file to the vault. (Details: $e)',
      );
    }
  }
}

@riverpod
Uuid uuid(Ref ref) => const Uuid();

@riverpod
Future<VaultHandler> vaultHandler(Ref ref) async {
  final repository = await ref.watch(vaultRepositoryProvider.future);
  final uuid = ref.watch(uuidProvider);

  // Inject the callback to invalidate the vault files list on success
  return VaultHandler(repository, uuid, () {
    ref.invalidate(vaultFilesProvider);
  });
}
