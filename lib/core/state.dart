import 'package:pico/pico.dart';
import 'package:beam/core/protocol.dart';

/// Define the global application state using a Dart Record.
typedef AppState = ({
  bool isServerRunning,
  List<TransferEvent> transfers,
});

/// Create the global Pico store with the initial state.
final store = Store<AppState>((
  isServerRunning: false,
  transfers: [],
));

/// Actions to mutate the state

void setServerRunning(bool isRunning) {
  store.set((state) => (
    isServerRunning: isRunning,
    transfers: state.transfers,
  ));
}

void addTransferEvent(TransferEvent event) {
  store.set((state) => (
    isServerRunning: state.isServerRunning,
    transfers: [...state.transfers, event],
  ));
}

void clearTransfers() {
  store.set((state) => (
    isServerRunning: state.isServerRunning,
    transfers: [],
  ));
}
