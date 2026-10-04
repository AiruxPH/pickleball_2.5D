import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_3d/game/character_renderer.dart';
import 'package:pickleball_3d/models/player.dart';
import 'package:pickleball_3d/models/shop_items.dart';
import 'package:pickleball_3d/services/character_sprite_manager.dart';
import 'package:pickleball_3d/utils/game_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CharacterSpriteManager Tests', () {
    test('CharacterSpriteManager instance is singleton', () {
      final a = CharacterSpriteManager.instance;
      final b = CharacterSpriteManager.instance;
      expect(identical(a, b), isTrue);
    });

    test('Loads character sprites from bundle without errors', () async {
      final manager = CharacterSpriteManager.instance;
      await manager.init();

      expect(manager.isLoaded, isTrue);
      expect(manager.playerSprite, isNotNull);
      expect(manager.aiRivalSprite, isNotNull);
      expect(manager.partnerSprite, isNotNull);
    });

    test('Returns correct sprite for human player, AI, and partner', () async {
      final manager = CharacterSpriteManager.instance;
      await manager.init();

      final humanPlayer = Player(startPosition: Vec3(0, 0, 15), isHuman: true);
      final aiPlayer = Player(startPosition: Vec3(0, 0, -15), isHuman: false);
      final partnerPlayer = Player(startPosition: Vec3(5, 0, 15), isHuman: false, isPartner: true);

      final humanSprite = manager.getSpriteForPlayer(humanPlayer);
      final aiSprite = manager.getSpriteForPlayer(aiPlayer);
      final partnerSprite = manager.getSpriteForPlayer(partnerPlayer);

      expect(humanSprite, equals(manager.playerSprite));
      expect(aiSprite, equals(manager.aiRivalSprite));
      expect(partnerSprite, equals(manager.partnerSprite));
    });

    test('drawPlayerSprite renders safely on Canvas with movement and swings', () async {
      final manager = CharacterSpriteManager.instance;
      await manager.init();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final humanPlayer = Player(startPosition: Vec3(0, 0, 15), isHuman: true);
      final aiPlayer = Player(startPosition: Vec3(0, 0, -15), isHuman: false);
      final partnerPlayer = Player(startPosition: Vec3(4, 0, 15), isHuman: false, isPartner: true);

      // 1. Normal human player render
      final drawnHuman = manager.drawPlayerSprite(
        canvas: canvas,
        player: humanPlayer,
        scale: 1.0,
        isLowEnd: false,
        showShadow: true,
      );
      expect(drawnHuman, isTrue);

      // 2. AI with forehand swing
      aiPlayer.isSwinging = true;
      aiPlayer.swingArm = 0.5;
      aiPlayer.isForehand = true;
      final drawnAi = manager.drawPlayerSprite(
        canvas: canvas,
        player: aiPlayer,
        scale: 0.8,
        isLowEnd: false,
        showShadow: true,
      );
      expect(drawnAi, isTrue);

      // 3. Partner with running stride locomotion & backhand swing
      partnerPlayer.runBlend = 1.0;
      partnerPlayer.legCycleTimer = 1.8;
      partnerPlayer.velocity.x = -6.0;
      partnerPlayer.isSwinging = true;
      partnerPlayer.swingArm = 0.75;
      partnerPlayer.isForehand = false;
      final drawnPartner = manager.drawPlayerSprite(
        canvas: canvas,
        player: partnerPlayer,
        scale: 1.1,
        isLowEnd: false,
        showShadow: true,
      );
      expect(drawnPartner, isTrue);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('CharacterRenderer renders all athletic character styles and movement', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final cam = PerspectiveCamera(
        position: Vec3(0, 3.2, -8.5),
        target: Vec3(0, 0.9, 0),
        fov: 60,
        screenSize: const Size(800, 600),
      );

      // Player Pro running
      final player = Player(startPosition: Vec3(0, 0, 14), isHuman: true)
        ..runBlend = 0.8
        ..legCycleTimer = 2.4
        ..velocity.x = 4.0;
      CharacterRenderer.drawPlayer(
        canvas: canvas,
        player: player,
        cam: cam,
        isLowEnd: false,
        showShadow: true,
      );

      // AI Rival crouch & ready
      final ai = Player(startPosition: Vec3(0, 0, -14), isHuman: false)
        ..runBlend = 0.0
        ..animTimer = 1.2;
      CharacterRenderer.drawPlayer(
        canvas: canvas,
        player: ai,
        cam: cam,
        isLowEnd: false,
        showShadow: true,
      );

      // Partner Pro with custom skin & paddle
      final partner = Player(startPosition: Vec3(-4, 0, 14), isHuman: false, isPartner: true)
        ..isSwinging = true
        ..swingArm = 0.4
        ..isForehand = true;
      final customPaddle = kPaddleCatalog.first;
      CharacterRenderer.drawPlayer(
        canvas: canvas,
        player: partner,
        cam: cam,
        isLowEnd: false,
        showShadow: true,
        equippedPaddle: customPaddle,
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
