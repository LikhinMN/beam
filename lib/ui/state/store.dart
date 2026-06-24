import 'package:pico/pico.dart';
import 'app_state.dart';

/// The global application state store powered by Pico.
final store = Store<AppState>((
  peers: const [],
  isScanning: false,
  selectedPeer: null,
  transfers: const [],
  firewallError: null,
  pairingState: const AsyncData(null),
  incomingPIN: null,
  history: const AsyncData([]),
));
