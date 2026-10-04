import 'dart:math';

/// Utility class for generating, formatting, and encoding/decoding room codes.
class LanRoomCode {
  LanRoomCode._();

  static const String prefix = 'PK-';

  /// Generates a friendly 4-character numeric room code, e.g. "PK-4821".
  static String generateRandom({String prefix = prefix}) {
    final rand = Random();
    final number = rand.nextInt(9000) + 1000;
    return '$prefix$number';
  }

  /// Encodes an IPv4 address into a compact 6-character Base36 code, e.g. "PK-1P4MKD".
  static String? encodeIp(String ip, {String prefix = prefix}) {
    var clean = ip.trim();
    if (clean.contains(':')) clean = clean.split(':').first;
    final parts = clean.split('.');
    if (parts.length != 4) return null;
    final b0 = int.tryParse(parts[0]);
    final b1 = int.tryParse(parts[1]);
    final b2 = int.tryParse(parts[2]);
    final b3 = int.tryParse(parts[3]);
    if (b0 == null || b1 == null || b2 == null || b3 == null) return null;
    if (b0 < 0 || b0 > 255 || b1 < 0 || b1 > 255 || b2 < 0 || b2 > 255 || b3 < 0 || b3 > 255) {
      return null;
    }

    final num = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
    final encoded = num.toRadixString(36).toUpperCase().padLeft(6, '0');
    return '$prefix$encoded';
  }

  /// Parses a host/port string or room code safely, extracting the target host and port.
  /// Handles prefixes like ws://, wss://, http://, ports, and Base36 IP room codes.
  static ({String host, int port}) parseHostAndPort(
    String input, {
    int defaultPort = 7777,
  }) {
    var clean = input.trim();
    if (clean.startsWith('ws://')) clean = clean.substring(5);
    if (clean.startsWith('wss://')) clean = clean.substring(6);
    if (clean.startsWith('http://')) clean = clean.substring(7);
    if (clean.startsWith('https://')) clean = clean.substring(8);
    if (clean.contains('/')) clean = clean.split('/').first;

    var host = clean;
    var port = defaultPort;

    if (clean.contains(':')) {
      final parts = clean.split(':');
      host = parts[0];
      final parsedPort = int.tryParse(parts[1]);
      if (parsedPort != null && parsedPort > 0 && parsedPort <= 65535) {
        port = parsedPort;
      }
    }

    // Try decoding room code if applicable
    final decoded = decodeIp(host);
    if (decoded != null) {
      host = decoded;
    }

    if (host == 'localhost' || host.isEmpty) {
      host = '127.0.0.1';
    }

    return (host: host, port: port);
  }

  /// Attempts to decode a room code or string into an IPv4 address.
  /// Returns null if the code does not represent a valid LAN IPv4.
  static String? decodeIp(String code, {String prefix = prefix}) {
    var clean = code.trim().toUpperCase();
    if (clean.contains(':')) {
      clean = clean.split(':').first;
    }
    if (clean.startsWith(prefix.toUpperCase())) {
      clean = clean.substring(prefix.length);
    }

    // Direct IPv4 pass-through
    final parts = clean.split('.');
    if (parts.length == 4 && parts.every((p) => int.tryParse(p) != null)) {
      if (isValidLanIp(clean)) return clean;
    }

    final num = int.tryParse(clean, radix: 36);
    if (num == null || num < 0 || num > 0xFFFFFFFF) return null;
    final b0 = (num >> 24) & 0xFF;
    final b1 = (num >> 16) & 0xFF;
    final b2 = (num >> 8) & 0xFF;
    final b3 = num & 0xFF;
    final ip = '$b0.$b1.$b2.$b3';
    return isValidLanIp(ip) ? ip : null;
  }

  /// Validates whether an IP address belongs to a valid routable IPv4 network.
  static bool isValidLanIp(String ip) {
    var clean = ip.trim();
    if (clean.contains(':')) clean = clean.split(':').first;
    final parts = clean.split('.');
    if (parts.length != 4) return false;
    final b0 = int.tryParse(parts[0]) ?? -1;
    final b1 = int.tryParse(parts[1]) ?? -1;
    final b2 = int.tryParse(parts[2]) ?? -1;
    final b3 = int.tryParse(parts[3]) ?? -1;
    if (b0 < 0 || b0 > 255 || b1 < 0 || b1 > 255 || b2 < 0 || b2 > 255 || b3 < 0 || b3 > 255) {
      return false;
    }

    // Disallow 0.0.0.0 and 255.255.255.255
    if (b0 == 0 && b1 == 0 && b2 == 0 && b3 == 0) return false;
    if (b0 == 255 && b1 == 255 && b2 == 255 && b3 == 255) return false;

    return true;
  }

  /// Normalizes room code format (uppercase, trims spaces).
  static String normalize(String code) {
    var clean = code.trim().toUpperCase();
    if (!clean.startsWith(prefix) && !clean.contains('.')) {
      clean = '$prefix$clean';
    }
    return clean;
  }
}
