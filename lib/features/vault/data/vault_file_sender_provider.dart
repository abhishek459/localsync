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

      if (connectionService == null) {
        throw Exception("Networking service not ready or not logged in.");
      }

      final repository = await ref.read(vaultRepositoryProvider.future);
      final appDocsDir = await ref.read(appDocumentsDirectoryProvider.future);
      final uuid = ref.read(uuidProvider);

      // 1. Prepare Storage
      final vaultDir = Directory(p.join(appDocsDir.path, 'SecureVaultData'));
      if (!vaultDir.existsSync()) vaultDir.createSync(recursive: true);

      final fileId = uuid.v4();
      final destinationPath = p.join(vaultDir.path, fileId);

      // 2. Encrypt to Disk (Phase 1)
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

      startPacketBuilder.addByte(MessageType.transferStart.value);
      final lenBytes = ByteData(4)..setUint32(0, startJson.length);
      startPacketBuilder.add(lenBytes.buffer.asUint8List());
      startPacketBuilder.add(startJson);

      final startPayload = startPacketBuilder.toBytes();
      final startFrameHeader = ByteData(4)..setUint32(0, startPayload.length);

      // Send Start Frame
      await connectionService.broadcastStream(
        header: Uint8List.fromList([
          ...startFrameHeader.buffer.asUint8List(),
          ...startPayload,
        ]),
        totalSize: 0,
        dataStreamFactory: () => const Stream.empty(),
      );

      // 4. Send Chunks Loop (Using simpler logic)
      final fileStream = fileOnDisk.openRead();
      final fileIdBytes = utf8.encode(fileId);
      final fileIdLen = fileIdBytes.length;
      int bytesSent = 0;

      await for (final chunk in fileStream) {
        final chunkBuilder = BytesBuilder();

        // [Type (1)] [FileId Len (1)] [FileId (N)] [Data (N)]
        chunkBuilder.addByte(MessageType.transferChunk.value);
        chunkBuilder.addByte(fileIdLen);
        chunkBuilder.add(fileIdBytes);
        chunkBuilder.add(chunk);

        final chunkPayload = chunkBuilder.toBytes();

        // Frame Header [Len (4)]
        final frameHeader = ByteData(4)..setUint32(0, chunkPayload.length);

        final fullFrame = BytesBuilder();
        fullFrame.add(frameHeader.buffer.asUint8List());
        fullFrame.add(chunkPayload);

        // We use broadcastStream here effectively as a simple "send"
        // by wrapping this single frame in a stream.
        // This reuses the logic in ConnectionService without needing a separate 'broadcast' method.
        await connectionService.broadcastStream(
          header: fullFrame.toBytes(),
          totalSize: 0,
          dataStreamFactory: () => const Stream.empty(),
        );

        bytesSent += chunk.length;
        ref
            .read(transferProgressProvider.notifier)
            .setProgress((bytesSent / totalSize).clamp(0.0, 1.0));
      }

      // 5. Finalize Local Record
      await repository.addFile(
        id: fileId,
        filename: filename,
        nonce: encryptedFile.nonce,
        ciphertextPath: destinationPath,
      );

      ref.invalidate(vaultFilesProvider);
      await Future.delayed(const Duration(milliseconds: 500));
      ref.read(transferProgressProvider.notifier).setProgress(0.0);
    });
  }
}
