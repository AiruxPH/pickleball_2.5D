import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../game/match_command_controller.dart';
import '../lan/lan_state_snapshot.dart';

/// Direct peer-to-peer gameplay transport. Firebase is used only to exchange
/// SDP and ICE signaling records; match data travels over WebRTC data channels.
final class WebRtcGameTransport {
  WebRtcGameTransport({
    required this.room,
    required this.uid,
    required this.isHost,
    required this.onCommand,
    required this.onSnapshot,
    required this.onConnectionChanged,
  });

  final DatabaseReference room;
  final String uid;
  final bool isHost;
  final ValueChanged<MatchCommand> onCommand;
  final ValueChanged<LanStateSnapshot> onSnapshot;
  final VoidCallback onConnectionChanged;

  RTCPeerConnection? _peer;
  RTCDataChannel? _realtime;
  RTCDataChannel? _reliable;
  final List<StreamSubscription<DatabaseEvent>> _subscriptions = [];
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  final Set<String> _seenCandidateKeys = <String>{};
  bool _remoteDescriptionReady = false;
  bool _closed = false;

  bool get isConnected =>
      _realtime?.state == RTCDataChannelState.RTCDataChannelOpen &&
      _reliable?.state == RTCDataChannelState.RTCDataChannelOpen;

  static const _configuration = <String, dynamic>{
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ],
      },
    ],
  };

  Future<void> start() async {
    _peer = await createPeerConnection(_configuration);
    _peer!.onConnectionState = (_) => onConnectionChanged();
    _peer!.onIceCandidate = _publishLocalCandidate;

    if (isHost) {
      await _startHost();
    } else {
      await _startClient();
    }
  }

  Future<void> _startHost() async {
    final realtimeInit = RTCDataChannelInit()
      ..id = 1
      ..ordered = false
      ..maxRetransmits = 1;
    final reliableInit = RTCDataChannelInit()
      ..id = 3
      ..ordered = true;
    _attachChannel(
      await _peer!.createDataChannel('realtime', realtimeInit),
    );
    _attachChannel(
      await _peer!.createDataChannel('reliable', reliableInit),
    );

    _listenForCandidates('client');
    _subscriptions.add(room.child('webrtc/answer').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is! Map || _remoteDescriptionReady || _closed) return;
      unawaited(_acceptAnswer(Map<String, dynamic>.from(value)));
    }));

    final offer = await _peer!.createOffer({});
    await _peer!.setLocalDescription(offer);
    await room.child('webrtc/offer').set({
      'sdp': offer.sdp,
      'type': offer.type,
      'uid': uid,
      'createdAt': ServerValue.timestamp,
    });
  }

  Future<void> _startClient() async {
    _peer!.onDataChannel = _attachChannel;
    _listenForCandidates('host');
    _subscriptions.add(room.child('webrtc/offer').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is! Map || _remoteDescriptionReady || _closed) return;
      unawaited(_acceptOffer(Map<String, dynamic>.from(value)));
    }));
  }

  Future<void> _acceptOffer(Map<String, dynamic> value) async {
    final sdp = value['sdp'] as String?;
    final type = value['type'] as String?;
    if (sdp == null || type == null || _peer == null) return;
    await _peer!.setRemoteDescription(RTCSessionDescription(sdp, type));
    _remoteDescriptionReady = true;
    await _flushRemoteCandidates();
    final answer = await _peer!.createAnswer({});
    await _peer!.setLocalDescription(answer);
    await room.child('webrtc/answer').set({
      'sdp': answer.sdp,
      'type': answer.type,
      'uid': uid,
      'createdAt': ServerValue.timestamp,
    });
  }

  Future<void> _acceptAnswer(Map<String, dynamic> value) async {
    final sdp = value['sdp'] as String?;
    final type = value['type'] as String?;
    if (sdp == null || type == null || _peer == null) return;
    await _peer!.setRemoteDescription(RTCSessionDescription(sdp, type));
    _remoteDescriptionReady = true;
    await _flushRemoteCandidates();
  }

  void _listenForCandidates(String remoteRole) {
    _subscriptions.add(room
        .child('webrtc/candidates/$remoteRole')
        .onChildAdded
        .listen((event) {
      final key = event.snapshot.key;
      final value = event.snapshot.value;
      if (key == null || value is! Map || !_seenCandidateKeys.add(key)) return;
      final data = Map<String, dynamic>.from(value);
      final candidate = RTCIceCandidate(
        data['candidate'] as String?,
        data['sdpMid'] as String?,
        (data['sdpMLineIndex'] as num?)?.toInt(),
      );
      if (_remoteDescriptionReady) {
        unawaited(_peer?.addCandidate(candidate));
      } else {
        _pendingRemoteCandidates.add(candidate);
      }
    }));
  }

  void _publishLocalCandidate(RTCIceCandidate candidate) {
    if (_closed || candidate.candidate == null) return;
    final role = isHost ? 'host' : 'client';
    unawaited(room.child('webrtc/candidates/$role').push().set({
      ...candidate.toMap() as Map,
      'uid': uid,
      'createdAt': ServerValue.timestamp,
    }));
  }

  Future<void> _flushRemoteCandidates() async {
    final peer = _peer;
    if (peer == null) return;
    for (final candidate in _pendingRemoteCandidates) {
      await peer.addCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();
  }

  void _attachChannel(RTCDataChannel channel) {
    if (channel.label == 'realtime') {
      _realtime = channel;
    } else if (channel.label == 'reliable') {
      _reliable = channel;
    } else {
      unawaited(channel.close());
      return;
    }
    channel.onDataChannelState = (_) => onConnectionChanged();
    channel.onMessage = _handleMessage;
    onConnectionChanged();
  }

  void _handleMessage(RTCDataChannelMessage message) {
    if (message.isBinary) return;
    try {
      final decoded = jsonDecode(message.text);
      if (decoded is! Map) return;
      final envelope = Map<String, dynamic>.from(decoded);
      final payload = envelope['d'];
      if (payload is! Map) return;
      if (envelope['t'] == 'command' && isHost) {
        onCommand(MatchCommand.fromJson(Map<String, dynamic>.from(payload)));
      } else if (envelope['t'] == 'snapshot' && !isHost) {
        onSnapshot(
          LanStateSnapshot.fromJson(Map<String, dynamic>.from(payload)),
        );
      }
    } catch (error) {
      debugPrint('[WebRTC] Ignored malformed gameplay message: $error');
    }
  }

  bool sendCommand(MatchCommand command) {
    final channel =
        command.type == MatchCommandType.movement ? _realtime : _reliable;
    if (channel?.state != RTCDataChannelState.RTCDataChannelOpen) return false;
    unawaited(channel!.send(RTCDataChannelMessage(jsonEncode({
      't': 'command',
      'd': command.toJson(),
    }))));
    return true;
  }

  bool sendSnapshot(LanStateSnapshot snapshot) {
    final channel = _realtime;
    if (channel?.state != RTCDataChannelState.RTCDataChannelOpen) return false;
    if ((channel!.bufferedAmount ?? 0) > 262144) return true;
    unawaited(channel.send(RTCDataChannelMessage(jsonEncode({
      't': 'snapshot',
      'd': snapshot.toJson(),
    }))));
    return true;
  }

  Future<void> close() async {
    _closed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _realtime?.close();
    await _reliable?.close();
    await _peer?.close();
    await _peer?.dispose();
    _realtime = null;
    _reliable = null;
    _peer = null;
  }
}
