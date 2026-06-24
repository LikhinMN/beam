import 'dart:async';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';

/// Represents a discovered Beam peer on the local network.
class BeamPeer {
  final String name;
  final String ip;
  final int port;
  final String platform;
  final bool isOnline;

  BeamPeer({
    required this.name,
    required this.ip,
    required this.port,
    required this.platform,
    required this.isOnline,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamPeer &&
          runtimeType == other.runtimeType &&
          ip == other.ip;

  @override
  int get hashCode => ip.hashCode;
}

/// Handles mDNS discovery (advertising and scanning) for the Beam app.
class BeamDiscovery {
  static const String _serviceType = '_beam._tcp';

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  String? _selfDeviceId;

  final _peers = <String, BeamPeer>{}; // Keyed by IP
  final _peersController = StreamController<List<BeamPeer>>.broadcast();

  /// Exposes a stream of discovered peers. Updates whenever a peer is found or lost.
  Stream<List<BeamPeer>> get peers => _peersController.stream;

  /// Starts advertising this device on the local network via mDNS.
  Future<void> startAdvertising(String deviceName, int port, String deviceId) async {
    _selfDeviceId = deviceId;
    int retries = 3;
    bool success = false;

    final service = BonsoirService(
      name: deviceName,
      type: _serviceType,
      port: port,
      attributes: {
        'platform': Platform.isAndroid ? 'android' : (Platform.isLinux ? 'linux' : 'unknown'),
        'id': deviceId,
      },
    );

    while (retries > 0 && !success) {
      try {
        _broadcast = BonsoirBroadcast(service: service);
        await _broadcast!.ready;
        await _broadcast!.start();
        success = true;
      } catch (e) {
        retries--;
        if (retries > 0) {
          await Future.delayed(const Duration(seconds: 1));
        } else {
          print('Failed to start mDNS advertising: $e');
        }
      }
    }
  }

  /// Stops advertising this device.
  Future<void> stopAdvertising() async {
    await _broadcast?.stop();
    _broadcast = null;
  }

  /// Starts scanning for other Beam devices on the local network.
  Future<void> startScanning() async {
    _discovery = BonsoirDiscovery(type: _serviceType);
    await _discovery!.ready;
    
    _discovery!.eventStream?.listen((event) {
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
        // Resolve the service to get IP and port
        event.service?.resolve(_discovery!.serviceResolver);
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
        _handleResolvedService(event.service as ResolvedBonsoirService);
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
        _handleLostService(event.service);
      }
    });

    await _discovery!.start();
  }

  /// Stops scanning for devices and clears the peer list.
  Future<void> stopScanning() async {
    await _discovery?.stop();
    _discovery = null;
    _peers.clear();
    _peersController.add([]);
  }

  /// Processes a resolved mDNS service.
  void _handleResolvedService(ResolvedBonsoirService service) {
    // Exclude self by matching unique device ID
    if (service.attributes['id'] == _selfDeviceId) return;

    final Map<String, dynamic> json = service.toJson();
    final ip = json['host'] as String? ?? service.host ?? '';
    final port = service.port;
    if (ip.isEmpty || port == 0) return;

    // Disambiguate names if multiple peers share the same name
    String peerName = service.name;
    final existingWithSameName = _peers.values.where((p) => p.name == service.name && p.ip != ip);
    if (existingWithSameName.isNotEmpty) {
      peerName = '${service.name} ($ip)';
    }

    final peer = BeamPeer(
      name: peerName,
      ip: ip,
      port: service.port,
      platform: service.attributes['platform'] ?? 'unknown',
      isOnline: true,
    );

    _peers[ip] = peer;
    print('addPeer called for $peerName at $ip:$port');
    _peersController.add(_peers.values.toList());
  }

  /// Removes a peer from the list when its mDNS service is lost.
  void _handleLostService(BonsoirService? service) {
    if (service == null) return;
    
    // The lost service may not have its IP resolved anymore, so we try to find it by name.
    final matchingPeers = _peers.values.where((p) => p.name == service.name || p.name.startsWith('${service.name} ')).toList();
    for (var peer in matchingPeers) {
      _peers.remove(peer.ip);
    }
    
    if (matchingPeers.isNotEmpty) {
      _peersController.add(_peers.values.toList());
    }
  }

  /// Allows explicit removal of a peer (e.g. if a direct connection fails).
  void removePeer(String ip) {
    if (_peers.remove(ip) != null) {
      _peersController.add(_peers.values.toList());
    }
  }
}
