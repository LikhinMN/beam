import 'package:pico/pico.dart';
import 'package:beam/core/discovery.dart';
import 'package:beam/core/transfer_history.dart';
import 'package:beam/core/peer_state.dart';

enum TransferDirection { send, receive }

enum TransferStatus { active, completed, failed }

typedef TransferItem = ({
  String id,
  String fileName,
  int totalBytes,
  int transferredBytes,
  double speedBytesPerSec,
  Duration eta,
  TransferDirection direction,
  TransferStatus status,
  String? errorReason,
});

extension TransferItemX on TransferItem {
  TransferItem copyWith({
    String? id,
    String? fileName,
    int? totalBytes,
    int? transferredBytes,
    double? speedBytesPerSec,
    Duration? eta,
    TransferDirection? direction,
    TransferStatus? status,
    String? errorReason,
    bool clearErrorReason = false,
  }) {
    return (
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      totalBytes: totalBytes ?? this.totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      eta: eta ?? this.eta,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      errorReason: clearErrorReason ? null : (errorReason ?? this.errorReason),
    );
  }
}

typedef IncomingRequest = ({
  String peerId,
  String peerName,
  int nFiles,
  int totalBytes,
});

typedef AppState = ({
  List<BeamPeer> peers,
  Map<String, PeerState> peerStates,
  bool isScanning,
  BeamPeer? selectedPeer,
  List<TransferItem> transfers,
  String? firewallError,
  AsyncValue<List<HistoryEntry>> history,
  IncomingRequest? incomingRequest,
});

extension AppStateX on AppState {
  AppState copyWith({
    List<BeamPeer>? peers,
    Map<String, PeerState>? peerStates,
    bool? isScanning,
    BeamPeer? selectedPeer,
    List<TransferItem>? transfers,
    String? firewallError,
    AsyncValue<List<HistoryEntry>>? history,
    IncomingRequest? incomingRequest,
    bool clearSelectedPeer = false,
    bool clearFirewallError = false,
    bool clearIncomingRequest = false,
  }) {
    return (
      peers: peers ?? this.peers,
      peerStates: peerStates ?? this.peerStates,
      isScanning: isScanning ?? this.isScanning,
      selectedPeer: clearSelectedPeer
          ? null
          : (selectedPeer ?? this.selectedPeer),
      transfers: transfers ?? this.transfers,
      firewallError: clearFirewallError
          ? null
          : (firewallError ?? this.firewallError),
      history: history ?? this.history,
      incomingRequest: clearIncomingRequest
          ? null
          : (incomingRequest ?? this.incomingRequest),
    );
  }
}
