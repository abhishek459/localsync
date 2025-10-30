import 'package:flutter/foundation.dart';

// Using @immutable for a simple, efficient data class.
@immutable
class DiscoveredPeer {
  /// The unique device ID (the certificate fingerprint).
  final String id;

  /// A human-readable device name (e.g., "Pixel 8 Pro").
  final String name;

  /// The resolved IP address (e.g., "192.168.1.10").
  final String host;

  /// The port the device is listening on.
  final int port;

  const DiscoveredPeer({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
  });

  @override
  String toString() {
    return 'DiscoveredPeer(id: $id, name: $name, host: $host, port: $port)';
  }

  // Implementing == and hashCode to allow lists to diff objects correctly.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DiscoveredPeer &&
        other.id == id &&
        other.name == name &&
        other.host == host &&
        other.port == port;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ host.hashCode ^ port.hashCode;
  }
}
