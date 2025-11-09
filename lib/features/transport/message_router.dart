import 'package:flutter/foundation.dart';
import 'package:local_sync/features/transport/transport_protocol.dart';
import 'package:local_sync/features/vault/application/vault_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'message_router.g.dart';

/// Routes incoming raw socket data to the correct feature handler
/// based on the [MessageType].
class MessageRouter {
  final VaultHandler _vaultHandler;

  MessageRouter(this._vaultHandler);

  Future<void> handleData(Uint8List data, String fromFingerprint) async {
    if (data.isEmpty) return;

    // Read the first byte to determine the message type
    final typeByte = data[0];

    // Find the corresponding MessageType
    final messageType = MessageType.values.firstWhere(
      (e) => e.value == typeByte,
      orElse: () => MessageType.unknown,
    );

    // Get the rest of the payload
    final payload = data.sublist(1);

    switch (messageType) {
      case MessageType.vaultFile:
        try {
          // The handler can now throw an exception, so we catch it.
          await _vaultHandler.handleMessage(payload);
        } catch (e) {
          // If handling the file fails (e.g., corrupt, disk full),
          // we log the error but do not crash the connection.
          // Other valid files can still be processed.
          debugPrint('Failed to handle VaultFile message: $e');
        }
        break;
      case MessageType.syncFile:
        // TODO: Handle sync file in Phase 3
        break;
      case MessageType.unknown:
        // Unknown message type, ignore
        break;
    }
  }
}

@riverpod
Future<MessageRouter> messageRouter(Ref ref) async {
  // Wait for the vault handler to be ready
  final vaultHandler = await ref.watch(vaultHandlerProvider.future);
  return MessageRouter(vaultHandler);
}
