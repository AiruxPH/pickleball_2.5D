import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lan_action_button.dart';

class LanRoomCodeCard extends StatefulWidget {
  const LanRoomCodeCard({
    super.key,
    required this.roomCode,
    required this.hostAddress,
    required this.port,
    required this.ui,
  });

  final String roomCode;
  final String hostAddress;
  final int port;
  final double ui;

  @override
  State<LanRoomCodeCard> createState() => _LanRoomCodeCardState();
}

class _LanRoomCodeCardState extends State<LanRoomCodeCard> {
  bool _copied = false;
  bool _showDetails = false;

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E36).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14 * widget.ui),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
          width: 1.5 * widget.ui,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
            blurRadius: 16 * widget.ui,
            spreadRadius: 2 * widget.ui,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 20 * widget.ui,
        vertical: 14 * widget.ui,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8 * widget.ui),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_tethering,
                  color: const Color(0xFF00E5FF),
                  size: 22 * widget.ui,
                ),
              ),
              SizedBox(width: 14 * widget.ui),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ROOM CODE',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 10 * widget.ui,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8 * widget.ui,
                        color: const Color(0xFF81D4FA),
                      ),
                    ),
                    SizedBox(height: 3 * widget.ui),
                    SelectableText(
                      widget.roomCode,
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 22 * widget.ui,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5 * widget.ui,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              LanActionButton(
                label: _copied ? 'COPIED!' : 'COPY CODE',
                icon: _copied ? Icons.check : Icons.copy,
                ui: widget.ui * 0.88,
                color: _copied ? const Color(0xFF00E676) : const Color(0xFF00E5FF),
                onTap: _copyCode,
              ),
            ],
          ),
          SizedBox(height: 8 * widget.ui),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Share this code with your opponent on the same Wi-Fi or device',
                style: TextStyle(
                  fontSize: 11 * widget.ui,
                  color: Colors.white70,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _showDetails = !_showDetails),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4 * widget.ui),
                  child: Text(
                    _showDetails ? 'Hide IP' : 'Network Info',
                    style: TextStyle(
                      fontSize: 10 * widget.ui,
                      color: const Color(0xFF81D4FA),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_showDetails) ...[
            SizedBox(height: 8 * widget.ui),
            Container(
              padding: EdgeInsets.all(8 * widget.ui),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(6 * widget.ui),
              ),
              child: Text(
                'Host Address: ${widget.hostAddress}:${widget.port}',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 11 * widget.ui,
                  color: Colors.white60,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
