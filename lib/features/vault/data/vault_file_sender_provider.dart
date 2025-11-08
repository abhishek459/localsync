import 'dart:convert';
import 'dart:typed_data';

import 'package:local_sync/features/connection/data/connection_providers.dart';
import 'package:local_sync/features/transport/transport_protocol.dart';
import 'package:local_sync/features/vault/application/encryption_service.dart';
import 'package:local_sync/features/vault/application/vault_handler.dart';
import 'package:local_sync/features/vault/data/vault_repository.dart';
import 'package:local_sync/features/vault/domain/vault_file_header.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vault_file_sender_provider.g.dart';

@riverpod
class VaultFileSender extends _$VaultFileSender {
  @override
  Future<void> build() async {}

  Future<void> sendFile(String path, String filename) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final encryptionService = await ref.read(
        encryptionServiceProvider.future,
      );
      final connectionService = await ref.read(
        connectionServiceProvider.future,
      );
      final repository = await ref.read(vaultRepositoryProvider.future);
      final fileId = ref.read(uuidProvider).v4();

      final encryptedFile = await encryptionService.encryptFile(path);

      final header = VaultFileHeader(
        filename: filename,
        nonce: base64Encode(encryptedFile.nonce),
        mac: base64Encode(encryptedFile.mac),
      );
      final headerBytes = utf8.encode(header.toJson());

      final headerLenBytes = ByteData(4)..setUint32(0, headerBytes.length);

      final builder = BytesBuilder();
      builder.addByte(MessageType.vaultFile.value);
      builder.add(headerLenBytes.buffer.asUint8List());
      builder.add(headerBytes);
      builder.add(encryptedFile.ciphertext);

      final fullPayload = builder.toBytes();

      // 1. Save to local repository *first*
      await repository.addFile(
        id: fileId,
        filename: filename,
        nonce: encryptedFile.nonce,
        mac: encryptedFile.mac,
        ciphertext: encryptedFile.ciphertext,
      );

      // 2. Invalidate local UI so sender sees the file
      ref.invalidate(vaultFilesProvider);

      // 3. Broadcast to peers
      await connectionService.broadcast(fullPayload);
    });
  }
}
