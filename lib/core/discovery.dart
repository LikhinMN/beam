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

  BeamPeer copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    String? platform,
    bool? isOnline,
  }) {
    return BeamPeer(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      platform: platform ?? this.platform,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeamPeer &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port &&
          id == other.id;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode ^ id.hashCode;
}

/// Handles mDNS discovery (advertising and scanning) for the Beam app.
class BeamDiscovery {
  static const String _serviceType = '_beam._tcp';

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  String? _selfDeviceId;
  bool _isScanning = false;
  bool _isAdvertising = false;
  StreamSubscription? _eventSubscription;

  final Map<String, BeamPeer> _peers = {};
  final Map<String, String> _nameToPeerKey = {};
  final Set<String> _localIps = {};

  bool _isValidPeerIp(String? host) {
    if (host == null) return false;
    if (host == '127.0.0.1') return false; // loopback
    if (host == '::1') return false; // IPv6 loopback
    if (host.startsWith('169.254.')) return false; // link-local
    if (host == '0.0.0.0') return false;
    return true;
  }

  Future<void> _fetchLocalIps() async {
    _localIps.clear();
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          _localIps.add(addr.address);
        }
      }
    } catch (e) {
      // ignore
    }
  }

  /// Starts advertising this device on the local network via mDNS.
  Future<void> startAdvertising(
    String deviceName,
    int port,
    String deviceId,
  ) async {
    if (_isAdvertising) return;
    _isAdvertising = true;
    _selfDeviceId = deviceId;
    await _fetchLocalIps();

    int retries = 3;
    bool success = false;

    final service = BonsoirService(
      name: deviceName,
      type: _serviceType,
      port: port,
      attributes: {
        'platform': Platform.isAndroid
            ? 'android'
            : (Platform.isLinux ? 'linux' : 'unknown'),
        'id': deviceId,
      },
    );

    while (retries > 0 && !success) {
      try {
        if (_broadcast != null) {
          print(
            '[Discovery] DISCOVERY_INSTANCE_DISPOSED broadcast hashCode=${_broadcast.hashCode}',
          );
          await _broadcast!.stop();
        }
        _broadcast = BonsoirBroadcast(service: service);
        print(
          '[Discovery] DISCOVERY_INSTANCE_CREATED broadcast hashCode=${_broadcast.hashCode}',
        );
        await _broadcast!.ready;
        await _broadcast!.start();
        success = true;
        print('[Discovery] BROADCAST STARTED: ${service.name}');
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
    if (!_isAdvertising) return;
    _isAdvertising = false;
    if (_broadcast != null) {
      print(
        '[Discovery] DISCOVERY_INSTANCE_DISPOSED broadcast hashCode=${_broadcast.hashCode}',
      );
      await _broadcast?.stop();
      _broadcast = null;
    }
    print('[Discovery] BROADCAST STOPPED');
  }

  /// Starts scanning for other Beam devices on the local network.
  Future<void> startScanning() async {
    if (_isScanning) return;
    _isScanning = true;
    await _fetchLocalIps();

    if (_discovery != null) {
      print(
        '[Discovery] DISCOVERY_INSTANCE_DISPOSED discovery hashCode=${_discovery.hashCode}',
      );
      await _discovery!.stop();
    }
    _discovery = BonsoirDiscovery(type: _serviceType);
    print(
      '[Discovery] DISCOVERY_INSTANCE_CREATED discovery hashCode=${_discovery.hashCode}',
    );
    await _discovery!.ready;

    _eventSubscription = _discovery!.eventStream?.listen((event) {
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
        print('[Discovery] DISCOVERED: ${event.service?.name}');
        event.service?.resolve(_discovery!.serviceResolver);
      } else if (event.type ==
          BonsoirDiscoveryEventType.discoveryServiceResolved) {
        final service = event.service as ResolvedBonsoirService;
        Future.microtask(() => _handleResolvedService(service));
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
        _handleLostService(event.service);
      }
    });

    await _discovery!.start();
    print('[Discovery] SCANNING STARTED');
  }

  /// Stops scanning for devices and clears the peer list.
  Future<void> stopScanning() async {
    if (!_isScanning) return;
    _isScanning = false;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    if (_discovery != null) {
      print(
        '[Discovery] DISCOVERY_INSTANCE_DISPOSED discovery hashCode=${_discovery.hashCode}',
      );
      await _discovery?.stop();
      _discovery = null;
    }
    _peers.clear();
    _nameToPeerKey.clear();
    actions.setPeers([]);
    print('[Discovery] SCANNING STOPPED');
  }

  /// Processes a resolved mDNS service.
  void _handleResolvedService(ResolvedBonsoirService service) {
    final safeAttributes = Map<String, String>.from(service.attributes);
    final serviceId = safeAttributes['id'] ?? 'unknown';

    // Exclude self
    if (serviceId == _selfDeviceId) {
      print(
        '[Discovery] SELF_DEVICE_FILTERED id=$serviceId host=${service.host} platform=${safeAttributes['platform']}',
      );
      return;
    }

    final Map<String, dynamic> json = service.toJson();
    final ip = json['host'] as String? ?? service.host ?? '';
    final port = service.port;

    if (!_isValidPeerIp(ip)) return;
    if (_localIps.contains(ip)) return;
    if (ip == Platform.localHostname) return;

    final peerKey = '$ip:$port:$serviceId';
    _nameToPeerKey[service.name] = peerKey;

    final peerName = service.name;
    final platform = safeAttributes['platform'] ?? 'unknown';

    final existingPeerKey = _nameToPeerKey[peerName];
    if (existingPeerKey != null) {
      final existingPeer = _peers[existingPeerKey];
      if (existingPeer != null) {
        if (existingPeer.id != serviceId || existingPeer.platform != platform) {
          print(
            '[Discovery] ATTRIBUTE_CORRUPTION_IGNORED host=$ip old_id=${existingPeer.id} new_id=$serviceId old_platform=${existingPeer.platform} new_platform=$platform',
          );
          return;
        }
      }
    }

    final oldPeer = _peers[peerKey];
    final isNew = oldPeer == null;

    final peer =
        oldPeer?.copyWith(name: peerName, platform: platform, isOnline: true) ??
        BeamPeer(
          id: serviceId,
          name: peerName,
          ip: ip,
          port: port,
          platform: platform,
          isOnline: true,
        );

    _peers[peerKey] = peer;

    if (isNew) {
      print(
        '[Discovery] RESOLVED: host=$ip, port=$port, id=$serviceId, platform=$platform, hashCode=${service.hashCode}',
      );
    } else {
      print(
        '[Discovery] UPDATED: host=$ip, port=$port, id=$serviceId, platform=$platform, hashCode=${service.hashCode}',
      );
    }

    actions.upsertPeer(peer);
  }

  /// Removes a peer from the list when its mDNS service is lost.
  void _handleLostService(BonsoirService? service) {
    if (service == null) return;

    final peerKey = _nameToPeerKey[service.name];
    if (peerKey == null) return;

    final peer = _peers[peerKey];
    if (peer == null) return;

    print(
      '[Discovery] REMOVED: host=${peer.ip}, port=${peer.port}, id=${peer.id}, platform=${peer.platform}, hashCode=${service.hashCode}',
    );

    final offlinePeer = peer.copyWith(isOnline: false);
    _peers[peerKey] = offlinePeer;

    actions.removePeer(offlinePeer);
    _nameToPeerKey.remove(service.name);
    _peers.remove(peerKey);
  }

  /// Allows explicit removal of a peer (e.g. if a direct connection fails).
  void removePeer(String id) {
    String? foundKey;
    for (final entry in _peers.entries) {
      if (entry.value.id == id) {
        foundKey = entry.key;
        break;
      }
    }

    if (foundKey != null) {
      final peer = _peers[foundKey]!;
      actions.removePeer(peer.copyWith(isOnline: false));
      _peers.remove(foundKey);
      _nameToPeerKey.removeWhere((k, v) => v == foundKey);
    }
  }
}
