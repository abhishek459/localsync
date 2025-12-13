import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bonsoir/bonsoir.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_sync/features/discovery/domain/discovered_peer.dart';
import 'package:local_sync/src/rust/api/identity.dart';

class DiscoveryService {
  final NetworkIdentity _identity;
  final DeviceInfoPlugin _deviceInfo;
  final int _port;
  static const _serviceType = '_localsync._tcp';
  final String _sessionId;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySubscription;
  final _peersController = StreamController<List<DiscoveredPeer>>.broadcast();

  final Map<String, DiscoveredPeer> _discoveredPeers = {};

  DiscoveryService({
    required NetworkIdentity identity,
    required DeviceInfoPlugin deviceInfo,
    required int port,
  }) : _identity = identity,
       _deviceInfo = deviceInfo,
       _port = port,
       _sessionId =
           DateTime.now().millisecondsSinceEpoch.toString() +
           Random().nextInt(9999).toString();

  Future<void> startBroadcast() async {
    try {
      final deviceName = await _getDeviceName();
      final deviceId = await _identity.publicId();

      final service = BonsoirService(
        name: deviceName,
        type: _serviceType,
        port: _port,
        attributes: {'id': deviceId, 'session': _sessionId},
      );

      _broadcast = BonsoirBroadcast(service: service);

      await _broadcast!.initialize();
      await _broadcast!.start();
    } catch (e) {
      print("Broadcast error: $e");
    }
  }

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

    _initializeAndStartDiscovery();

    return _peersController.stream;
  }

  Future<void> _initializeAndStartDiscovery() async {
    try {
      _discovery = BonsoirDiscovery(type: _serviceType);

      await _discovery!.initialize();

      if (_discovery!.eventStream == null) return;

      _discoverySubscription = _discovery!.eventStream!.listen(
        _handleDiscoveryEvent,
      );

      await _discovery!.start();
    } catch (e) {
      _discovery = null;
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

  Future<void> _handleDiscoveryEvent(BonsoirDiscoveryEvent event) async {
    if (event is BonsoirDiscoveryServiceFoundEvent) {
      // A new, unresolved service is found. We must resolve it.
      event.service.resolve(_discovery!.serviceResolver);
    } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
      // A service has been resolved, we now have its IP, port, and attributes.
      await _addOrUpdatePeer(event.service);
    } else if (event is BonsoirDiscoveryServiceLostEvent) {
      // A service is lost
      if (_discoveredPeers.containsKey(event.service.name)) {
        _discoveredPeers.remove(event.service.name);
        _updatePeerList();
      }
    }
  }

  Future<void> _addOrUpdatePeer(BonsoirService service) async {
    final host = service.host;
    final id = service.attributes['id'];
    final remoteSession = service.attributes['session'];

    if (host == null || id == null) return;

    if (remoteSession == _sessionId) return;

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
