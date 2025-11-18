/// Defines the v0.1 transport protocol structure.
///
/// We are multiplexing different features (Vault, Sync) over a single
/// socket connection. The first byte of every message will be a
/// [MessageType] identifier to allow the receiver to route the
/// data to the correct handler.
///
/// ### Vault v0.1 Packet Structure
///
/// | Bytes | Content | Description |
/// | :--- | :--- | :--- |
/// | 1 | MessageType (0x01) | Identifies this as a Secure Vault file. |
/// | 4 | Header Length (HL) | A 32-bit unsigned int (Big Endian) specifying the length of the JSON header. |
/// | HL | Header JSON | A UTF-8 encoded JSON string containing file metadata. |
/// | ... | Ciphertext | The raw encrypted file bytes. |
///
class TransportProtocol {
  /// The length, in bytes, of the 32-bit integer that defines the header length.
  static const int headerLengthBytes = 4;
}

/// A 1-byte identifier for the message type.
enum MessageType {
  /// (0x00) Reserved for handshake or ping.
  unknown(0x00),

  /// (0x01) A file for the Secure Vault.
  vaultFile(0x01),

  /// (0x02) A file for the P2P Synced Folder.
  syncFile(0x02),

  /// (0x03) Authentication packet (Certificate exchange).
  auth(0x03);

  const MessageType(this.value);
  final int value;
}
