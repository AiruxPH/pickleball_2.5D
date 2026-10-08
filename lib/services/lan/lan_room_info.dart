import '../../models/match_lobby.dart';
import '../../models/match_foundation.dart';

/// Metadata describing a discoverable LAN or web multiplayer room.
class LanRoomInfo {
  const LanRoomInfo({
    required this.roomCode,
    required this.hostAddress,
    required this.port,
    required this.format,
    required this.createdAt,
    this.name = 'Pickleball Room',
    this.balanceProfile = MatchBalanceProfile.standard,
  });

  final String roomCode;
  final String hostAddress;
  final int port;
  final LobbyFormat format;
  final int createdAt;
  final String name;
  final MatchBalanceProfile balanceProfile;

  Map<String, dynamic> toJson() => {
        'roomCode': roomCode,
        'hostAddress': hostAddress,
        'port': port,
        'format': format.name,
        'createdAt': createdAt,
        'name': name,
        'balanceProfile': balanceProfile.name,
      };

  factory LanRoomInfo.fromJson(Map<String, dynamic> json) {
    return LanRoomInfo(
      roomCode: json['roomCode'] as String? ?? 'PK-0000',
      hostAddress: json['hostAddress'] as String? ?? '127.0.0.1',
      port: (json['port'] as num?)?.toInt() ?? 7777,
      format: (json['format'] as String?) == 'doubles'
          ? LobbyFormat.doubles
          : LobbyFormat.singles,
      createdAt: (json['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      name: json['name'] as String? ?? 'Pickleball Room',
      balanceProfile:
          MatchBalanceProfileX.fromName(json['balanceProfile']),
    );
  }
}
