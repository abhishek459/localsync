import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:local_sync/features/connection/data/connection_providers.dart';
import 'package:local_sync/features/transport/transport_protocol.dart';
import 'package:local_sync/features/vault/application/encryption_service.dart';
import 'package:local_sync/features/vault/application/vault_handler.dart';
import 'package:local_sync/features/vault/data/vault_repository.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vault_file_sender_provider.g.dart';

/// Holds the progress of the current file transfer (0.0 to 1.0).
@riverpod
class TransferProgress extends _$TransferProgress {
  @override
  double build() => 0.0;

  void setProgress(double value) => state = value;
}

@riverpod
class VaultFileSender extends _$VaultFileSender {
  @override
  Future<void> build() async {}

  Future<void> sendFile(String path, String filename) async {
    state = const AsyncLoading();
    ref.read(transferProgressProvider.notifier).setProgress(0.0);

    state = await AsyncValue.guard(() async {
      final encryptionService = await ref.read(
        encryptionServiceProvider.future,
      );
      final connectionService = await ref.read(
        connectionServiceProvider.future,
      );
      final repository = await ref.read(vaultRepositoryProvider.future);
      final appDocsDir = await ref.read(appDocumentsDirectoryProvider.future);
      final uuid = ref.read(uuidProvider);

      // 1. Prepare Storage
      final vaultDir = Directory(p.join(appDocsDir.path, 'SecureVaultData'));
      if (!vaultDir.existsSync()) vaultDir.createSync(recursive: true);

      final fileId = uuid.v4();
      final destinationPath = p.join(vaultDir.path, fileId);

      // 2. Encrypt to Disk (Phase 1)
      // This produces the full encrypted file locally first.
      final encryptedFile = await encryptionService.encryptFile(
        inputPath: path,
        outputPath: destinationPath,
      );

      final fileOnDisk = File(destinationPath);
      final totalSize = await fileOnDisk.length();

      // 3. Send "Transfer Start" Control Packet
      final startMetadata = {
        'fileId': fileId,
        'filename': filename,
        'totalSize': totalSize,
        'nonce': base64Encode(encryptedFile.nonce),
        'fileType': 'vault',
      };

      final startJson = utf8.encode(jsonEncode(startMetadata));
      final startPacketBuilder = BytesBuilder();

      // Frame: [Type] [Len] [Payload]
      startPacketBuilder.addByte(MessageType.transferStart.value);

      final lenBytes = ByteData(4)..setUint32(0, startJson.length);
      startPacketBuilder.add(lenBytes.buffer.asUint8List());
      startPacketBuilder.add(startJson);

      // Note: We need to frame the *entire* message for the PacketReassembler
      // The PacketReassembler expects: [TotalFrameLen] [Body]
      final startPayload = startPacketBuilder.toBytes();
      final startFrameHeader = ByteData(4)..setUint32(0, startPayload.length);

      await connectionService.broadcast(
        Uint8List.fromList([
          ...startFrameHeader.buffer.asUint8List(),
          ...startPayload,
        ]),
      );

      // 4. Send Chunks Loop
      final fileStream = fileOnDisk.openRead();
      int bytesSent = 0;

      // We read large chunks from disk, but we might want to ensure they
      // fit our maxChunkSize protocol limit.
      // File.openRead() usually yields ~64kb chunks, which is fine.
      await for (final chunk in fileStream) {
        // Prepare the Chunk Packet Payload
        // Format: [Type (1)] [FileId Len (4)] [FileId (N)] [Data]
        // *Optimization*: Since FileID is fixed UUID (36 chars), we can hardcode len or just send bytes.
        // Let's stick to a robust parser:
        // [Type: transferChunk] [FileId (36 bytes ASCII)] [Data]

        final chunkBuilder = BytesBuilder();
        chunkBuilder.addByte(MessageType.transferChunk.value);

        // File ID (UUID is 36 bytes)
        final fileIdBytes = utf8.encode(fileId);
        // We assume ID is always 36 bytes for now, or we prefix len.
        // Let's prefix len to be safe.
        chunkBuilder.addByte(fileIdBytes.length); // 1 byte len is enough for ID
        chunkBuilder.add(fileIdBytes);

        // Data
        chunkBuilder.add(chunk);

        final chunkPayload = chunkBuilder.toBytes();

        // Wrap in TCP Frame for Reassembler
        final tcpFrameHeader = ByteData(4)..setUint32(0, chunkPayload.length);
        final fullTcpFrame = BytesBuilder();
        fullTcpFrame.add(tcpFrameHeader.buffer.asUint8List());
        fullTcpFrame.add(chunkPayload);

        await connectionService.broadcast(fullTcpFrame.toBytes());

        bytesSent += chunk.length;
        ref
            .read(transferProgressProvider.notifier)
            .setProgress(bytesSent / totalSize);
      }

      // 5. Finalize Local Record
      await repository.addFile(
        id: fileId,
        filename: filename,
        nonce: encryptedFile.nonce,
        ciphertextPath: destinationPath,
      );

      ref.invalidate(vaultFilesProvider);

      // UI Polish: smooth finish
      await Future.delayed(const Duration(milliseconds: 500));
      ref.read(transferProgressProvider.notifier).setProgress(0.0);
    });
  }
}
