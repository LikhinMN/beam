import 'dart:async';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import 'package:beam/ui/state/actions.dart' as actions;

/// Represents a discovered Beam peer on the local network.
class BeamPeer {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String platform;
  final bool isOnline;

  BeamPeer({
    required this.id,
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

  final resolvedServices = <String, BonsoirService>{};

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
        final service = event.service as ResolvedBonsoirService;
        final incomingId = service.attributes['id'];
        final resolvedId = resolvedServices[service.name]?.attributes['id'];
        // Ignore attribute updates that carry a different device's id
        if (resolvedId != null && incomingId != resolvedId) return;
        
        resolvedServices[service.name] = service;
        // Process off main thread to prevent jank
        Future.microtask(() => _handleResolvedService(service));
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
    resolvedServices.clear();
    actions.setPeers([]);
  }

  /// Processes a resolved mDNS service.
  void _handleResolvedService(ResolvedBonsoirService service) {
    final serviceId = service.attributes['id'];
    // Exclude self by matching unique device ID
    if (serviceId == _selfDeviceId) return;

    final Map<String, dynamic> json = service.toJson();
    final ip = json['host'] as String? ?? service.host ?? '';
    final port = service.port;
    if (ip.isEmpty || port == 0) return;

    final peerName = service.name;

    final peer = BeamPeer(
      id: serviceId ?? service.name,
      name: peerName,
      ip: ip,
      port: service.port,
      platform: service.attributes['platform'] ?? 'unknown',
      isOnline: true,
    );

    actions.upsertPeer(peer);
  }

  /// Removes a peer from the list when its mDNS service is lost.
  void _handleLostService(BonsoirService? service) {
    if (service == null) return;
    
    final resolved = resolvedServices[service.name];
    final id = resolved?.attributes['id'] ?? service.attributes['id'] ?? service.name;
    
    final peer = BeamPeer(
      id: id,
      name: service.name,
      ip: '',
      port: 0,
      platform: '',
      isOnline: false,
    );
    
    actions.removePeer(peer);
    resolvedServices.remove(service.name);
  }

  /// Allows explicit removal of a peer (e.g. if a direct connection fails).
  void removePeer(String id) {
    final peer = BeamPeer(id: id, name: '', ip: '', port: 0, platform: '', isOnline: false);
    actions.removePeer(peer);
  }
}
