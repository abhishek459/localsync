import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:local_sync/features/connection/data/connection_providers.dart';
import 'package:local_sync/features/transport/transport_protocol.dart';
import 'package:local_sync/features/vault/application/encryption_service.dart';
import 'package:local_sync/features/vault/application/vault_handler.dart';
import 'package:local_sync/features/vault/data/vault_repository.dart';
import 'package:local_sync/features/vault/domain/vault_file_header.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vault_file_sender_provider.g.dart';

/// Holds the progress of the current file transfer (0.0 to 1.0).
@riverpod
class TransferProgress extends _$TransferProgress {
  @override
  double build() => 0.0;

  void setProgress(double value) {
    state = value;
  }
}

@riverpod
class VaultFileSender extends _$VaultFileSender {
  @override
  Future<void> build() async {}

  Future<void> sendFile(String path, String filename) async {
    state = const AsyncLoading();
    // Reset progress to 0
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
      final vaultDir = Directory(p.join(appDocsDir.path, 'SecureVaultData'));
      if (!vaultDir.existsSync()) vaultDir.createSync(recursive: true);

      final fileId = ref.read(uuidProvider).v4();
      final destinationPath = p.join(vaultDir.path, fileId);

      // Phase 1: Encrypting
      // We could add a "status" provider here if you want text updates
      final encryptedFile = await encryptionService.encryptFile(
        inputPath: path,
        outputPath: destinationPath,
      );

      // Phase 2: Preparing Transfer
      final header = VaultFileHeader(
        filename: filename,
        nonce: base64Encode(encryptedFile.nonce),
      );
      final headerJsonBytes = utf8.encode(header.toJson());
      final headerLenBytes = ByteData(4)..setUint32(0, headerJsonBytes.length);

      final metaBuilder = BytesBuilder();
      metaBuilder.addByte(MessageType.vaultFile.value);
      metaBuilder.add(headerLenBytes.buffer.asUint8List());
      metaBuilder.add(headerJsonBytes);
      final metaBytes = metaBuilder.toBytes();

      final fileLen = await File(destinationPath).length();
      final totalPayloadLen = metaBytes.length + fileLen;

      final frameHeaderBuilder = BytesBuilder();
      final totalLenBytes = ByteData(4)..setUint32(0, totalPayloadLen.toInt());
      frameHeaderBuilder.add(totalLenBytes.buffer.asUint8List());
      frameHeaderBuilder.add(metaBytes);

      // Phase 3: Streaming with Progress
      await connectionService.broadcastStream(
        header: frameHeaderBuilder.toBytes(),
        dataStreamFactory: () => File(destinationPath).openRead(),
        totalSize: totalPayloadLen, // Pass total size
        onProgress: (sentBytes) {
          // Update the progress provider
          final percent = sentBytes / totalPayloadLen;
          ref.read(transferProgressProvider.notifier).setProgress(percent);
        },
      );

      // Finalize
      await repository.addFile(
        id: fileId,
        filename: filename,
        nonce: encryptedFile.nonce,
        ciphertextPath: destinationPath,
      );

      ref.invalidate(vaultFilesProvider);

      // Reset progress after a short delay so the user sees 100%
      await Future.delayed(const Duration(milliseconds: 500));
      ref.read(transferProgressProvider.notifier).setProgress(0.0);
    });
  }
}
