import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/models/match_lobby.dart';

void main() {
  group('MatchLobby', () {
    test('requires both local humans to be ready', () {
      final lobby = MatchLobby.local();

      expect(lobby.canStart, isFalse);
      lobby.toggleReady('p1');
      expect(lobby.canStart, isFalse);
      lobby.toggleReady('p2');
      expect(lobby.canStart, isTrue);
    });

    test('doubles adds one bot partner to each team', () {
      final lobby = MatchLobby.local(format: LobbyFormat.doubles);

      expect(lobby.slots.length, 4);
      expect(
        lobby.slots.where((slot) => slot.type == LobbySlotType.bot).length,
        2,
      );
    });

    test('serializes through the future network boundary', () {
      final lobby = MatchLobby.local(format: LobbyFormat.doubles);
      lobby.toggleReady('p1');
      lobby.toggleReady('p2');

      final restored = MatchLobby.fromJson(lobby.toJson());

      expect(restored.type, LobbyType.local);
      expect(restored.format, LobbyFormat.doubles);
      expect(restored.canStart, isTrue);
      expect(restored.slots.map((slot) => slot.id),
          containsAll(<String>['p1', 'p2', 'bot-1', 'bot-2']));
    });
  });
}
