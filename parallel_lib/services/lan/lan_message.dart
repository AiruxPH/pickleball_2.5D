import 'dart:convert';

enum LanMessageType {
  lobbySync,
  lobbyAction,
  startMatch,
  matchCommand,
  stateSync,
  ping,
  pong,
}

class LanMessage {
  const LanMessage({
    required this.type,
    this.payload = const {},
  });

  final LanMessageType type;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'payload': payload,
      };

  factory LanMessage.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    final type = LanMessageType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => LanMessageType.ping,
    );
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    return LanMessage(type: type, payload: payload);
  }

  String encode() => jsonEncode(toJson());

  static LanMessage? tryDecode(dynamic raw) {
    try {
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return LanMessage.fromJson(Map<String, dynamic>.from(decoded));
        }
      } else if (raw is Map) {
        return LanMessage.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (_) {}
    return null;
  }
}
