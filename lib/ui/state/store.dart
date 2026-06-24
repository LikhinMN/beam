import 'package:pico/pico.dart';
import 'app_state.dart';

/// The global application state store powered by Pico.
final store = Store<AppState>((
  peers: const [],
  peerStates: const {},
  isScanning: false,
  selectedPeer: null,
  transfers: const [],
  firewallError: null,
  history: const AsyncData([]),
  incomingRequest: null,
));
