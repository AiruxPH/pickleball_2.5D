import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// Training Screen — drill mode selector
/// Players can practice specific skills without scoring
/// ─────────────────────────────────────────────────────────────

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late Animation<double> _fade;
  int _selectedDrill = 0;

  final List<_DrillOption> _drills = const [
    _DrillOption(
      'SERVE DRILL',
      'Perfect your underhand diagonal serve. Land balls in the correct service box.',
      Icons.play_arrow_rounded,
      Color(0xFF0284C7),
      'serve_drill',
    ),
    _DrillOption(
      'RETURN DRILL',
      'AI serves continuously. Focus on consistent returns to keep the rally alive.',
      Icons.replay_rounded,
      Color(0xFF34D399),
      'return_drill',
    ),
    _DrillOption(
      'SMASH DRILL',
      'AI lobs the ball high. Practice powerful overhead smashes.',
      Icons.bolt_rounded,
      Color(0xFFF43F5E),
      'smash_drill',
    ),
    _DrillOption(
      'DINK DRILL',
      'Practice soft kitchen shots. AI returns dinks. Stay out of the NVZ!',
      Icons.south_west_rounded,
      Color(0xFF8B5CF6),
      'dink_drill',
    ),
    _DrillOption(
      'FOOTWORK DRILL',
      'Move quickly to retrieve balls from all corners of the court.',
      Icons.directions_run_rounded,
      Color(0xFFF59E0B),
      'footwork_drill',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 20),
                      const Text(
                        'SELECT DRILL',
                        style: TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._drills.asMap().entries.map((e) => _buildDrillCard(e.key, e.value)),
                      const SizedBox(height: 24),
                      _buildStartButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Icon(Icons.fitness_center_rounded, color: Color(0xFF34D399), size: 22),
          const SizedBox(width: 8),
          const Text(
            'TRAINING MODE',
            style: TextStyle(
              fontFamily: AppFonts.orbitron,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF34D399).withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34D399).withAlpha(60)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF34D399), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Training mode has no scoring. Focus on improving your skills without pressure!',
              style: TextStyle(
                color: Color(0xFF34D399),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrillCard(int index, _DrillOption drill) {
    final selected = _selectedDrill == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedDrill = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? drill.color.withAlpha(20) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? drill.color : const Color(0xFF334155),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: drill.color.withAlpha(50), blurRadius: 12)]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: drill.color.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(drill.icon, color: drill.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drill.label,
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected ? drill.color : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    drill.description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.radio_button_checked_rounded, color: drill.color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    final drill = _drills[_selectedDrill];
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: drill.color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
          shadowColor: drill.color.withAlpha(80),
        ),
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.pushReplacementNamed(
            context,
            '/game',
            arguments: {
              'mode': 'singles',
              'practice': true,
              'drillType': drill.drillId,
              'difficulty': 3,
            },
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(drill.icon, size: 20),
            const SizedBox(width: 10),
            Text(
              'START ${drill.label}',
              style: const TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrillOption {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final String drillId;
  const _DrillOption(this.label, this.description, this.icon, this.color, this.drillId);
}
