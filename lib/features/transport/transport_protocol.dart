/// Defines the v0.2 transport protocol structure.
///
/// We use a stateful chunking protocol to handle large files without
/// consuming excessive RAM.
///
/// ### Protocol Flow
/// 1. [transferStart] -> Receiver opens file stream.
/// 2. [transferChunk] -> Receiver appends data to stream.
/// 3. [transferChunk] ...
/// 4. (Receiver detects totalSize reached) -> Closes stream, finalizes file.
class TransportProtocol {
  /// The length, in bytes, of the 32-bit integer that defines the header length.
  static const int headerLengthBytes = 4;

  /// The max size of a single file chunk (1MB).
  /// Keeping this small ensures responsiveness and low memory footprint.
  static const int maxChunkSize = 1024 * 1024;
}

/// A 1-byte identifier for the message type.
enum MessageType {
  unknown(0x00),

  // -- Auth --
  auth(0x03),

  // -- V0.2 Chunked Protocol --
  /// Control packet to initiate a transfer.
  /// Payload: JSON { fileId, filename, totalSize, nonce, type: 'vault'|'sync' }
  transferStart(0x04),

  /// Data packet containing a byte range.
  /// Payload: [FileID (36 bytes string)] [Data Bytes]
  /// Note: We use the ID to map chunks to the correct active transfer.
  transferChunk(0x05),

  /// (Optional) Acknowledge receipt of a specific chunk or completion.
  ack(0x06);

  const MessageType(this.value);
  final int value;
}
