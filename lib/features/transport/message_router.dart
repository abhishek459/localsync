import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_sync/features/transport/transport_protocol.dart';
import 'package:local_sync/features/vault/application/vault_handler.dart';
import 'package:local_sync/features/vault/data/vault_repository.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'message_router.g.dart';

/// Represents an active incoming file transfer.
class _ActiveTransfer {
  final IOSink sink;
  final String filePath;
  final int totalSize;
  int currentSize;
  final String filename;
  final String nonceBase64;
  final String type;

  _ActiveTransfer({
    required this.sink,
    required this.filePath,
    required this.totalSize,
    required this.filename,
    required this.nonceBase64,
    required this.type,
  }) : currentSize = 0;
}

class MessageRouter {
  final VaultHandler _vaultHandler;
  final Directory _tempDir;

  // Maps FileID -> ActiveTransfer
  final Map<String, _ActiveTransfer> _activeTransfers = {};

  MessageRouter(this._vaultHandler, this._tempDir);

  Future<void> handleData(Uint8List data, String fromFingerprint) async {
    if (data.isEmpty) return;

    final typeByte = data[0];
    final messageType = MessageType.values.firstWhere(
      (e) => e.value == typeByte,
      orElse: () => MessageType.unknown,
    );

    final payload = data.sublist(1);

    try {
      switch (messageType) {
        case MessageType.transferStart:
          await _handleTransferStart(payload);
          break;
        case MessageType.transferChunk:
          await _handleTransferChunk(payload);
          break;
        default:
          // Auth is handled by ConnectionService.
          break;
      }
    } catch (e) {
      debugPrint('Error handling message $messageType: $e');
    }
  }

  Future<void> _handleTransferStart(Uint8List payload) async {
    // payload: [Len(4)] [JSON]
    if (payload.length < 4) return;

    final headerLen = ByteData.sublistView(payload, 0, 4).getUint32(0);
    final headerBytes = payload.sublist(4, 4 + headerLen);
    final metadata =
        jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>;

    final fileId = metadata['fileId'] as String;
    final totalSize = metadata['totalSize'] as int;
    final filename = metadata['filename'] as String;
    final nonce = metadata['nonce'] as String;
    final type = metadata['fileType'] as String;

    // Create temp file
    final tempFile = File(p.join(_tempDir.path, '$fileId.tmp'));
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    // Create Sink
    final sink = tempFile.openWrite(mode: FileMode.write);

    _activeTransfers[fileId] = _ActiveTransfer(
      sink: sink,
      filePath: tempFile.path,
      totalSize: totalSize,
      filename: filename,
      nonceBase64: nonce,
      type: type,
    );

    debugPrint('Started transfer: $filename ($totalSize bytes)');
  }

  Future<void> _handleTransferChunk(Uint8List payload) async {
    // payload: [ID Len(1)] [ID Bytes] [Data]
    if (payload.isEmpty) return;

    final idLen = payload[0];
    final idBytes = payload.sublist(1, 1 + idLen);
    final fileId = utf8.decode(idBytes);

    final chunkData = payload.sublist(1 + idLen);

    final transfer = _activeTransfers[fileId];
    if (transfer == null) {
      // We received a chunk for an unknown transfer (maybe we missed the Start packet?)
      // In a robust system, we might ask for "Resend Start". For now, ignore.
      return;
    }

    // Write to disk
    transfer.sink.add(chunkData);
    transfer.currentSize += chunkData.length;

    // Check completion
    if (transfer.currentSize >= transfer.totalSize) {
      await _finalizeTransfer(fileId, transfer);
    }
  }

  Future<void> _finalizeTransfer(
    String fileId,
    _ActiveTransfer transfer,
  ) async {
    await transfer.sink.flush();
    await transfer.sink.close();
    _activeTransfers.remove(fileId);

    if (transfer.type == 'vault') {
      // Pass the fully assembled temp file to the VaultHandler
      // We need to modify VaultHandler to accept a File path, not Bytes.
      // But for minimal breakage, let's keep VaultHandler roughly same
      // or expose a new method `handleCompletedFile`.

      await _vaultHandler.handleCompletedFile(
        fileId: fileId,
        tempFilePath: transfer.filePath,
        filename: transfer.filename,
        nonceBase64: transfer.nonceBase64,
      );
    }
  }
}

@riverpod
Future<MessageRouter> messageRouter(Ref ref) async {
  final vaultHandler = await ref.watch(vaultHandlerProvider.future);
  final appDocsDir = await ref.watch(appDocumentsDirectoryProvider.future);
  final tempDir = Directory(p.join(appDocsDir.path, 'TempTransfers'));
  if (!tempDir.existsSync()) tempDir.createSync();

  return MessageRouter(vaultHandler, tempDir);
}
