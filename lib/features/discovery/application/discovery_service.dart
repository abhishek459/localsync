import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_sync/features/discovery/domain/discovered_peer.dart';
import 'package:local_sync/features/identity/domain/device_identity.dart';

/// Handles network discovery (broadcasting and discovering) using mDNS (Bonsoir).
class DiscoveryService {
  final DeviceIdentity _identity;
  final DeviceInfoPlugin _deviceInfo;

  static const _serviceType = '_localsync._tcp';
  // Note: This port will be used for our actual socket connection in Step 3.
  static const _port = 45678;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySubscription;
  final _peersController = StreamController<List<DiscoveredPeer>>.broadcast();

  // Keep a map of discovered peers to manage the list.
  // We use the service name as the key (e.g., "My-Pixel-8")
  final Map<String, DiscoveredPeer> _discoveredPeers = {};

  DiscoveryService({
    required DeviceIdentity identity,
    required DeviceInfoPlugin deviceInfo,
  }) : _identity = identity,
       _deviceInfo = deviceInfo;

  /// Starts broadcasting this device's presence on the network.
  Future<void> startBroadcast() async {
    try {
      final deviceName = await _getDeviceName();

      final service = BonsoirService(
        name: deviceName, // e.g., "My Pixel 8"
        type: _serviceType,
        port: _port,
        // We put our unique, permanent ID in the TXT record.
        // This is how peers will identify us.
        attributes: {'id': _identity.fingerprint},
      );

      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.start();
    } catch (e) {
      // Log broadcast start error
    }
  }

  /// Stops the mDNS broadcast.
  Future<void> stopBroadcast() async {
    await _broadcast?.stop();
    _broadcast = null;
  }

  /// Starts discovering other peers on the network.
  Stream<List<DiscoveredPeer>> discoverPeers() {
    // If discovery is already running, return the existing stream.
    if (_discovery != null) {
      return _peersController.stream;
    }

    try {
      _discovery = BonsoirDiscovery(type: _serviceType);

      // Start listening *before* starting the discovery.
      _discoverySubscription = _discovery!.eventStream!.listen(
        _handleDiscoveryEvent,
      );

      // Asynchronously start the discovery.
      // We don't await this; we let it run in the background.
      _startDiscovery();
    } catch (e) {
      // Handle discovery start error
      _peersController.addError(e);
    }

    return _peersController.stream;
  }

  // Helper to wait for the discovery to be ready and start it.
  Future<void> _startDiscovery() async {
    if (_discovery == null) return;
    try {
      await _discovery!.start();
    } catch (e) {
      // Log discovery start error
      _peersController.addError(e);
    }
  }

  /// Stops the mDNS discovery.
  Future<void> stopDiscovery() async {
    await _discoverySubscription?.cancel();
    await _discovery?.stop();
    _discovery = null;
    _discoverySubscription = null;
    _discoveredPeers.clear();
    _peersController.add([]);
  }

  void _handleDiscoveryEvent(BonsoirDiscoveryEvent event) {
    if (event is BonsoirDiscoveryServiceFoundEvent) {
      // A new, unresolved service is found. We must resolve it.
      event.service.resolve(_discovery!.serviceResolver);
    } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
      // A service has been resolved, we now have its IP, port, and attributes.
      _addOrUpdatePeer(event.service);
    } else if (event is BonsoirDiscoveryServiceLostEvent) {
      // A service is lost
      if (_discoveredPeers.containsKey(event.service.name)) {
        _discoveredPeers.remove(event.service.name);
        _updatePeerList();
      }
    }
  }

  /// This is the new, correct method for bonsoir: ^6.0.1
  void _addOrUpdatePeer(BonsoirService service) {
    // The BonsoirService now contains host, port, and attributes
    // *after* it has been resolved.
    final host = service.host;
    final id = service.attributes['id'];

    // We MUST have a host and an ID to continue.
    if (host == null || id == null) {
      return;
    }

    // Filter out our own device
    if (id == _identity.fingerprint) {
      return;
    }

    final peer = DiscoveredPeer(
      id: id,
      name: service.name,
      host: host,
      port: service.port,
    );

    // Use service name as the key in our map
    _discoveredPeers[service.name] = peer;
    _updatePeerList();
  }

  /// Pushes the new list of peers to the stream.
  void _updatePeerList() {
    _peersController.add(_discoveredPeers.values.toList());
  }

  /// Helper to get a platform-specific device name.
  /// This code is compatible with device_info_plus: ^12.x.x
  Future<String> _getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return info.model; // e.g., "Pixel 8 Pro"
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.name; // e.g., "My iPhone"
      } else if (Platform.isLinux) {
        final info = await _deviceInfo.linuxInfo;
        return info.prettyName; // e.g., "Ubuntu 24.04"
      } else if (Platform.isMacOS) {
        final info = await _deviceInfo.macOsInfo;
        return info.computerName; // e.g., "My MacBook Pro"
      } else if (Platform.isWindows) {
        final info = await _deviceInfo.windowsInfo;
        return info.computerName; // e.g., "My-PC"
      }
    } catch (e) {
      // Fallback
    }
    return 'LocalSync Device';
  }

  /// Cleans up all resources.
  void dispose() {
    stopBroadcast();
    stopDiscovery();
    _peersController.close();
  }
}
