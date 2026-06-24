import 'dart:io';

/// Helper class to check port availability and provide Linux firewall instructions.
class FirewallHelper {
  /// Checks if the given [port] can be bound to.
  /// Note: A successful bind means the port is free locally, though an external
  /// firewall may still drop incoming packets.
  static Future<bool> checkPortAccessible(int port) async {
    try {
      final socket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Returns clear instructions for allowing the given [port] through
  /// common Linux firewalls (firewalld and ufw).
  static String getFirewallInstructions(int port) {
    return '''Port $port appears to be blocked. To allow it:
sudo firewall-cmd --add-port=$port/tcp --permanent
sudo firewall-cmd --reload
Or if using ufw:
sudo ufw allow $port/tcp''';
  }
}
