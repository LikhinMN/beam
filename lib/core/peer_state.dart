enum PeerState {
  discovered,   // seen via mDNS
  trusted,      // QR paired, not connected
  connected,    // active session
  transferring, // file transfer in progress
  offline,      // mDNS lost
}
