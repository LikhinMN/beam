class SpeedCalculator {
  final List<_Sample> _samples = [];

  /// Called on every chunk received. [bytesTransferred] is the cumulative total bytes transferred.
  void update(int bytesTransferred) {
    final now = DateTime.now();
    _samples.add(_Sample(now, bytesTransferred));

    // Remove samples older than 2 seconds to maintain a 2-second sliding window
    _samples.removeWhere((s) => now.difference(s.timestamp).inMilliseconds > 2000);
  }

  /// Returns the current speed in bytes per second based on the 2s sliding window.
  double get currentSpeed {
    if (_samples.length < 2) return 0;
    final first = _samples.first;
    final last = _samples.last;
    
    final durationSecs = last.timestamp.difference(first.timestamp).inMilliseconds / 1000.0;
    if (durationSecs <= 0) return 0;
    
    final bytesDiff = last.bytes - first.bytes;
    return bytesDiff / durationSecs;
  }

  /// Returns the estimated time remaining based on the current speed.
  Duration eta(int remainingBytes) {
    final speed = currentSpeed;
    if (speed <= 0) return const Duration(seconds: 0);
    return Duration(seconds: (remainingBytes / speed).round());
  }

  /// Resets the calculator on a new transfer.
  void reset() {
    _samples.clear();
  }
}

class _Sample {
  final DateTime timestamp;
  final int bytes;
  _Sample(this.timestamp, this.bytes);
}
