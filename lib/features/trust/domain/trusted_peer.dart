import 'package:flutter/foundation.dart';

/// A data model for a peer we have explicitly trusted.
/// This object is what we store in our `sqlite3` database.
@immutable
class TrustedPeer {
  /// The peer's unique SHA-256 certificate fingerprint. This is the ID.
  final String fingerprint;

  /// A user-assigned (or certificate-derived) name for the peer.
  final String name;

  /// The timestamp when the user first trusted this peer.
  final DateTime trustedAt;

  const TrustedPeer({
    required this.fingerprint,
    required this.name,
    required this.trustedAt,
  });

  /// Creates a [TrustedPeer] from a database row (Map).
  factory TrustedPeer.fromMap(Map<String, dynamic> map) {
    return TrustedPeer(
      fingerprint: map['fingerprint'] as String,
      name: map['name'] as String,
      trustedAt: DateTime.fromMillisecondsSinceEpoch(map['trusted_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrustedPeer && other.fingerprint == fingerprint;
  }

  @override
  int get hashCode => fingerprint.hashCode;
}
