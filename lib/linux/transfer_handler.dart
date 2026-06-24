import 'dart:io';
import 'dart:async';
import 'package:beam/core/protocol.dart';
import 'package:beam/core/transfer_server.dart';
import 'package:beam/core/file_utils.dart';
import 'firewall_helper.dart';
import 'storage_helper.dart';

/// Represents a transfer event augmented with Linux-specific info (e.g., firewall warnings).
class LinuxTransferEvent {
  final TransferEvent event;
  final String? message;
  
  LinuxTransferEvent(this.event, {this.message});
}

/// Bridges the core transfer engine with Linux-specific storage and firewall handling.
class LinuxTransferHandler {
  final _controller = StreamController<LinuxTransferEvent>.broadcast();

  /// Stream of decorated transfer events and firewall warnings.
  Stream<LinuxTransferEvent> get events => _controller.stream;

  /// Starts the given [server] on [port] and verifies the firewall access.
  Future<void> startServer(TransferServer server, {int port = 9001}) async {
    // 1. Non-blocking firewall check
    final isAccessible = await FirewallHelper.checkPortAccessible(port);
    if (!isAccessible) {
      final instructions = FirewallHelper.getFirewallInstructions(port);
      _controller.add(LinuxTransferEvent(
        TransferEvent(status: TransferEventType.failed, error: 'Port blocked'),
        message: instructions,
      ));
      // We continue to start the server anyway, as local firewall blocks
      // incoming packets but might allow local binding.
    }
    
    // 2. Start the core server
    await server.start(port: port);
    
    // 3. Listen and handle events
    server.events.listen(_handleEvent);
  }

  /// Internal handler for transfer events from the core isolate.
  Future<void> _handleEvent(TransferEvent event) async {
    final fileName = event.fileName ?? 'Unknown file';
    final senderIp = event.senderIp ?? 'Unknown IP';

    switch (event.status) {
      case TransferEventType.started:
        print('Transfer started: $fileName from $senderIp');
        _controller.add(LinuxTransferEvent(event));
        break;
        
      case TransferEventType.progress:
        // Emit progress directly to the UI stream
        _controller.add(LinuxTransferEvent(event));
        break;
        
      case TransferEventType.completed:
        try {
          if (event.filePath != null) {
            final tempFile = File(event.filePath!);
            if (await tempFile.exists()) {
              final downloadsDir = await StorageHelper.getDefaultDownloadDirectory();
              
              // Apply Linux-specific + common sanitization logic
              final sanitizedName = FileUtils.sanitizeFileName(fileName);
              final finalName = FileUtils.resolveConflict(downloadsDir, sanitizedName);
              
              final finalPath = '${downloadsDir.path}${Platform.pathSeparator}$finalName';
              
              await tempFile.copy(finalPath);
              await tempFile.delete(); // Cleanup temp file
              
              print('Transfer completed: saved to $finalPath');
            }
          }
        } catch (e) {
          print('Error saving completed file: $e');
        } finally {
          _controller.add(LinuxTransferEvent(event));
        }
        break;
        
      case TransferEventType.failed:
        print('Transfer failed for $fileName: ${event.error}');
        _controller.add(LinuxTransferEvent(event, message: event.error));
        break;
    }
  }

  /// Cleans up the event stream.
  void dispose() {
    _controller.close();
  }
}
