import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../models/shop_items.dart';
import '../models/ultimate_skill.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart';
import '../widgets/shop_paddle_preview.dart';
import '../widgets/shop_player_preview.dart';

/// ─────────────────────────────────────────────────────────────
/// ShopScreen — Pro Tour Equipment & Athlete Store
/// Dual catalog: Paddles & Athletes with live canvas preview,
/// gameplay stat bars, item rarity tiers, and currency purchase.
/// ─────────────────────────────────────────────────────────────

class ShopScreen extends StatefulWidget {
  final int initialTabIndex; // 0: Paddles, 1: Athletes, 2: Bank

  const ShopScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  late int _activeTab; // 0 = Paddles, 1 = Players, 2 = Bank
  late String _selectedPaddleId;
  late String _selectedPlayerId;

  late AnimationController _tabAnimCtrl;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTabIndex;

    final settings = context.read<GameSettings>();
    _selectedPaddleId = settings.equippedPaddleId;
    _selectedPlayerId = settings.equippedPlayerId;

    _tabAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _tabAnimCtrl.dispose();
    super.dispose();
  }

  void _onPaddleSelected(String id) {
    HapticFeedback.selectionClick();
    setState(() => _selectedPaddleId = id);
  }

  void _onPlayerSelected(String id) {
    HapticFeedback.selectionClick();
    setState(() => _selectedPlayerId = id);
  }

  void _onBuyOrEquipPaddle(GameSettings settings, PaddleItem paddle) {
    final isUnlocked = settings.isPaddleUnlocked(paddle.id);
    final isEquipped = settings.equippedPaddleId == paddle.id;

    if (isEquipped) return;

    if (isUnlocked) {
      // Equip
      HapticFeedback.mediumImpact();
      settings.equipPaddle(paddle.id);
      context.read<SettingsService>().save(settings);
      _showFeedbackSnackBar(
        context,
        '${paddle.name} EQUIPPED!',
        paddle.tier.color,
        Icons.check_circle_rounded,
      );
      setState(() {});
    } else {
      // Check currency
      final hasEnough = paddle.isGems
          ? settings.gems >= paddle.gemPrice
          : settings.coins >= paddle.coinPrice;

      if (!hasEnough) {
        _showInsufficientFundsDialog(context, paddle.isGems);
        return;
      }

      // Purchase
      HapticFeedback.heavyImpact();
      final success = settings.buyPaddle(paddle);
      if (success) {
        context.read<SettingsService>().save(settings);
        _showUnlockedCelebration(context, paddle.name, paddle.tier, isPaddle: true);
        setState(() {});
      }
    }
  }

  void _onBuyOrEquipPlayer(GameSettings settings, PlayerSkinItem skin) {
    final isUnlocked = settings.isPlayerUnlocked(skin.id);
    final isEquipped = settings.equippedPlayerId == skin.id;

    if (isEquipped) return;

    if (isUnlocked) {
      // Equip
      HapticFeedback.mediumImpact();
      settings.equipPlayer(skin.id);
      context.read<SettingsService>().save(settings);
      _showFeedbackSnackBar(
        context,
        '${skin.name} EQUIPPED!',
        skin.tier.color,
        Icons.check_circle_rounded,
      );
      setState(() {});
    } else {
      // Check currency
      final hasEnough = skin.isGems
          ? settings.gems >= skin.gemPrice
          : settings.coins >= skin.coinPrice;

      if (!hasEnough) {
        _showInsufficientFundsDialog(context, skin.isGems);
        return;
      }

      // Purchase
      HapticFeedback.heavyImpact();
      final success = settings.buyPlayer(skin);
      if (success) {
        context.read<SettingsService>().save(settings);
        _showUnlockedCelebration(context, skin.name, skin.tier, isPaddle: false);
        setState(() {});
      }
    }
  }

  void _showFeedbackSnackBar(BuildContext context, String text, Color color, IconData icon) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xF00F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withAlpha(180), width: 1.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        content: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: AppFonts.orbitron,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInsufficientFundsDialog(BuildContext context, bool isGems) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xF20F172A),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEF4444), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEF4444).withAlpha(40),
                  border: Border.all(color: const Color(0xFFEF4444), width: 2),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'INSUFFICIENT FUNDS',
                style: TextStyle(
                  fontFamily: AppFonts.orbitron,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You do not have enough ${isGems ? 'Diamonds / Gems' : 'Coins'} to acquire this item. Visit the Bank tab to claim free bonus tournament rewards!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC200),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _activeTab = 2); // Switch to Bank tab
                      },
                      child: const Text(
                        'OPEN BANK',
                        style: TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnlockedCelebration(
    BuildContext context,
    String name,
    ItemTier tier, {
    required bool isPaddle,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: tier.color, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: tier.glowColor.withAlpha(70),
                blurRadius: 8,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: tier.color.withAlpha(50),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tier.color),
                ),
                child: Text(
                  tier.displayName,
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: tier.color,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Icon(Icons.stars_rounded, color: Color(0xFFFFC200), size: 54),
              const SizedBox(height: 10),
              const Text(
                'ITEM UNLOCKED!',
                style: TextStyle(
                  fontFamily: AppFonts.orbitron,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.orbitron,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: tier.color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isPaddle
                    ? 'Your new paddle has been unlocked and automatically equipped for your upcoming matches!'
                    : 'Your athlete character has been unlocked and equipped for tournament play!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tier.color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'AWESOME!',
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<GameSettings>();
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // ── Background Atmosphere ──────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF060911),
                    Color(0xFF0B132B),
                    Color(0xFF111C38),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // ── Main UI Layout ────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top Navigation (Combined single bar in landscape, stacked in portrait)
                _buildTopNavigation(context, settings, isLandscape),

                // Tab View Content (Responsive)
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _activeTab == 0
                        ? _buildPaddlesTab(settings, isLandscape, size)
                        : _activeTab == 1
                            ? _buildAthletesTab(settings, isLandscape, size)
                            : _buildBankTab(settings, size, isLandscape),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Navigation (Responsive Header & Category Tabs) ────────
  Widget _buildTopNavigation(BuildContext context, GameSettings settings, bool isLandscape) {
    if (isLandscape) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
        child: Row(
          children: [
            // Back / Exit button
            _buildExitButton(context, isCompact: true),
            const SizedBox(width: 10),

            // Store Title
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_baseball_rounded, color: Color(0xFFFFC200), size: 16),
                SizedBox(width: 5),
                Text(
                  'SHOP',
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 10),

            // Segmented Category Tabs in Center
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildTabBar(isCompact: true),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Currencies with quick top-up buttons
            _buildCurrencyPill(
              icon: Icons.monetization_on_rounded,
              color: const Color(0xFFFFC200),
              value: settings.coins.toString(),
              isCompact: true,
              onAddTap: () => setState(() => _activeTab = 2),
            ),
            const SizedBox(width: 6),
            _buildCurrencyPill(
              icon: Icons.diamond_rounded,
              color: const Color(0xFFAB47BC),
              value: settings.gems.toString(),
              isCompact: true,
              onAddTap: () => setState(() => _activeTab = 2),
            ),
          ],
        ),
      );
    } else {
      return Column(
        children: [
          _buildHeaderBar(context, settings),
          _buildTabBar(isCompact: false),
        ],
      );
    }
  }

  Widget _buildExitButton(BuildContext context, {bool isCompact = false}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 12,
          vertical: isCompact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0x331E293B),
          borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
          border: Border.all(color: Colors.white24, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: isCompact ? 12 : 14),
            SizedBox(width: isCompact ? 4 : 6),
            Text(
              'EXIT',
              style: TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: isCompact ? 9.5 : 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Portrait Header Bar ──────────────────────────────────────
  Widget _buildHeaderBar(BuildContext context, GameSettings settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          _buildExitButton(context, isCompact: false),
          const SizedBox(width: 12),
          const Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_baseball_rounded, color: Color(0xFFFFC200), size: 18),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'SHOP',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildCurrencyPill(
            icon: Icons.monetization_on_rounded,
            color: const Color(0xFFFFC200),
            value: settings.coins.toString(),
            onAddTap: () => setState(() => _activeTab = 2),
          ),
          const SizedBox(width: 8),
          _buildCurrencyPill(
            icon: Icons.diamond_rounded,
            color: const Color(0xFFAB47BC),
            value: settings.gems.toString(),
            onAddTap: () => setState(() => _activeTab = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyPill({
    required IconData icon,
    required Color color,
    required String value,
    required VoidCallback onAddTap,
    bool isCompact = false,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(isCompact ? 6 : 8, isCompact ? 3 : 4, 3, isCompact ? 3 : 4),
      decoration: BoxDecoration(
        color: const Color(0xF20F172A),
        borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
        border: Border.all(color: color.withAlpha(120), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(30),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isCompact ? 14 : 16),
          SizedBox(width: isCompact ? 4 : 5),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.orbitron,
              fontSize: isCompact ? 10 : 11.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(width: isCompact ? 4 : 5),
          GestureDetector(
            onTap: onAddTap,
            child: Container(
              width: isCompact ? 15 : 18,
              height: isCompact ? 15 : 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
              child: Icon(Icons.add, color: Colors.black, size: isCompact ? 11 : 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar (Paddles / Athletes / Bank) ───────────────────────
  Widget _buildTabBar({bool isCompact = false}) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isCompact ? 0 : 16,
        vertical: isCompact ? 0 : 8,
      ),
      padding: EdgeInsets.all(isCompact ? 3 : 4),
      decoration: BoxDecoration(
        color: const Color(0x440F172A),
        borderRadius: BorderRadius.circular(isCompact ? 18 : 24),
        border: Border.all(color: Colors.white.withAlpha(25), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              index: 0,
              label: 'PADDLES',
              icon: Icons.sports_tennis_rounded,
              isCompact: isCompact,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              index: 1,
              label: 'PLAYERS',
              icon: Icons.person_rounded,
              isCompact: isCompact,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              index: 2,
              label: 'BANK & PERKS',
              icon: Icons.account_balance_wallet_rounded,
              isCompact: isCompact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    bool isCompact = false,
  }) {
    final isSelected = _activeTab == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 3 : 6,
          vertical: isCompact ? 5 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(isCompact ? 14 : 20),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x660284C7),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isCompact ? 12 : 15,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
              SizedBox(width: isCompact ? 3 : 6),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppFonts.orbitron,
                  fontSize: isCompact ? 8.5 : 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textMuted,
                  letterSpacing: isCompact ? 0.3 : 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // TAB 1: PADDLES STORE
  // ────────────────────────────────────────────────────────────
  Widget _buildPaddlesTab(GameSettings settings, bool isLandscape, Size size) {
    return GridView.builder(
      padding: EdgeInsets.all(isLandscape ? 12 : 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isLandscape ? 4 : 2,
        childAspectRatio: isLandscape ? 0.95 : 0.82,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: kPaddleCatalog.length,
      itemBuilder: (context, index) {
        final paddle = kPaddleCatalog[index];
        final isOwned = settings.isPaddleUnlocked(paddle.id);
        final isEquipped = settings.equippedPaddleId == paddle.id;
        final isSelected = paddle.id == _selectedPaddleId;

        return _buildPaddleCard(
          paddle: paddle,
          isOwned: isOwned,
          isEquipped: isEquipped,
          isSelected: isSelected,
          isCompact: false,
          onTap: () {
            _onPaddleSelected(paddle.id);
            _showPaddleDetailsModal(context, settings, paddle);
          },
        );
      },
    );
  }

  void _showPaddleDetailsModal(BuildContext context, GameSettings settings, PaddleItem paddle) {
    final isUnlocked = settings.isPaddleUnlocked(paddle.id);
    final isEquipped = settings.equippedPaddleId == paddle.id;
    final equippedPaddle = getPaddleById(settings.equippedPaddleId);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final screenH = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 32 : 20,
          vertical: isLandscape ? 12 : 24,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isLandscape ? 580 : 420,
            maxHeight: screenH * 0.92,
          ),
          decoration: BoxDecoration(
            color: const Color(0xE60F172A),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: paddle.tier.color.withAlpha(120), width: 2),
            boxShadow: [
              BoxShadow(
                color: paddle.tier.glowColor.withAlpha(70),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (Tier badge + close)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: paddle.tier.color.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: paddle.tier.color, width: 1),
                      ),
                      child: Text(
                        paddle.tier.displayName,
                        style: TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: paddle.tier.color,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (isLandscape)
                  // Landscape 2-column layout: Left preview & name, Right stats & CTA
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShopPaddlePreview(
                              paddle: paddle,
                              width: 100,
                              height: 120,
                              isInteractive: false,
                              showParticles: false,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              paddle.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: AppFonts.orbitron,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              paddle.tagline,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 6,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPaddleStatsCard(paddle, equippedPaddle),
                            const SizedBox(height: 12),
                            _buildPaddleActionButton(settings, paddle, isUnlocked, isEquipped, isCompact: true),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  // Portrait vertical stack
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: ShopPaddlePreview(
                          paddle: paddle,
                          width: 110,
                          height: 135,
                          isInteractive: false,
                          showParticles: false,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        paddle.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        paddle.tagline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildPaddleStatsCard(paddle, equippedPaddle),
                      const SizedBox(height: 16),
                      _buildPaddleActionButton(settings, paddle, isUnlocked, isEquipped),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaddleStatsCard(PaddleItem paddle, PaddleItem currentEquipped) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        children: [
          _buildStatMeter(
            label: 'POWER',
            value: paddle.power,
            diff: paddle.power - currentEquipped.power,
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 7),
          _buildStatMeter(
            label: 'CONTROL',
            value: paddle.control,
            diff: paddle.control - currentEquipped.control,
            color: const Color(0xFF06B6D4),
          ),
          const SizedBox(height: 7),
          _buildStatMeter(
            label: 'SPIN RATE',
            value: paddle.spin,
            diff: paddle.spin - currentEquipped.spin,
            color: const Color(0xFFA855F7),
          ),
          const SizedBox(height: 7),
          _buildStatMeter(
            label: 'STAMINA EFF.',
            value: paddle.staminaEfficiency,
            diff: paddle.staminaEfficiency - currentEquipped.staminaEfficiency,
            color: const Color(0xFF10B981),
          ),
          if (paddle.specialSkill != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: getUltimateByType(paddle.specialSkill!).primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: getUltimateByType(paddle.specialSkill!).primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ULTIMATE SKILL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    getUltimateByType(paddle.specialSkill!).name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: getUltimateByType(paddle.specialSkill!).primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatMeter({
    required String label,
    required double value,
    required double diff,
    required Color color,
  }) {
    final pct = (value * 100).toInt();
    final diffPct = (diff * 100).toInt();

    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.orbitron,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 7,
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: const Color(0x33334155),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        if (diffPct != 0) ...[
          const SizedBox(width: 4),
          Text(
            diffPct > 0 ? '+$diffPct%' : '$diffPct%',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: diffPct > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaddleActionButton(
    GameSettings settings,
    PaddleItem paddle,
    bool isUnlocked,
    bool isEquipped, {
    bool isCompact = false,
  }) {
    if (isEquipped) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 12),
        decoration: BoxDecoration(
          color: const Color(0x2210B981),
          borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: isCompact ? 14 : 18),
              SizedBox(width: isCompact ? 5 : 8),
              Text(
                'EQUIPPED IN MATCHES',
                style: TextStyle(
                  fontFamily: AppFonts.orbitron,
                  fontSize: isCompact ? 10 : 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF10B981),
                  letterSpacing: isCompact ? 1.0 : 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isUnlocked) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: isCompact ? 9 : 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 12 : 16)),
            elevation: 4,
          ),
          onPressed: () => _onBuyOrEquipPaddle(settings, paddle),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_tennis_rounded, size: isCompact ? 15 : 18),
              SizedBox(width: isCompact ? 6 : 8),
              Text(
                'EQUIP PADDLE',
                style: TextStyle(
                  fontFamily: AppFonts.orbitron,
                  fontSize: isCompact ? 11 : 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: isCompact ? 1.0 : 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Purchase Button
    final isGems = paddle.isGems;
    final price = paddle.price;
    final hasEnough = isGems ? settings.gems >= price : settings.coins >= price;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasEnough
              ? (isGems ? const Color(0xFF9333EA) : const Color(0xFFFFC200))
              : const Color(0xFF475569),
          foregroundColor: (hasEnough && !isGems) ? Colors.black : Colors.white,
          padding: EdgeInsets.symmetric(vertical: isCompact ? 9 : 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 12 : 16)),
          elevation: 6,
        ),
        onPressed: () => _onBuyOrEquipPaddle(settings, paddle),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isGems ? Icons.diamond_rounded : Icons.monetization_on_rounded,
              size: isCompact ? 15 : 20,
              color: (hasEnough && !isGems) ? Colors.black : Colors.white,
            ),
            SizedBox(width: isCompact ? 6 : 8),
            Text(
              'UNLOCK FOR $price ${isGems ? 'GEMS' : 'COINS'}',
              style: TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: isCompact ? 10.5 : 12.5,
                fontWeight: FontWeight.w900,
                letterSpacing: isCompact ? 0.9 : 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaddleCard({
    required PaddleItem paddle,
    required bool isOwned,
    required bool isEquipped,
    required bool isSelected,
    required VoidCallback onTap,
    bool isCompact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(isCompact ? 6 : 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : const Color(0xF20F172A),
          borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFC200)
                : paddle.tier.color.withAlpha(isOwned ? 140 : 80),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x66FFC200),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: Rarity or Equipped indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  paddle.tier.displayName,
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: isCompact ? 6.5 : 7.5,
                    fontWeight: FontWeight.w800,
                    color: paddle.tier.color,
                  ),
                ),
                if (isEquipped)
                  Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: isCompact ? 11 : 13)
                else if (isOwned)
                  Icon(Icons.lock_open_rounded, color: const Color(0xFF38BDF8), size: isCompact ? 10 : 12)
                else
                  Icon(Icons.lock_rounded, color: Colors.white38, size: isCompact ? 10 : 12),
              ],
            ),

            // Middle: Thumbnail preview
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final previewW = (constraints.maxWidth * 0.78).clamp(70.0, 160.0);
                  final previewH = (constraints.maxHeight * 0.88).clamp(80.0, 180.0);
                  return Center(
                    child: ShopPaddlePreview(
                      paddle: paddle,
                      width: previewW,
                      height: previewH,
                      isInteractive: false,
                      showParticles: false,
                    ),
                  );
                },
              ),
            ),

            // Bottom: Name & Price
            Column(
              children: [
                Text(
                  paddle.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: isCompact ? 7.5 : 8.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                if (isEquipped)
                  Text(
                    'EQUIPPED',
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: isCompact ? 6.5 : 7.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981),
                    ),
                  )
                else if (isOwned)
                  Text(
                    'OWNED',
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: isCompact ? 6.5 : 7.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF38BDF8),
                    ),
                  )
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // TAB 2: ATHLETES / PLAYERS STORE
  // ────────────────────────────────────────────────────────────
  Widget _buildAthletesTab(GameSettings settings, bool isLandscape, Size size) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isLandscape ? 4 : 2,
        childAspectRatio: isLandscape ? 0.95 : 0.82,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: kPlayerSkinCatalog.length,
      itemBuilder: (context, index) {
        final skin = kPlayerSkinCatalog[index];
        final isOwned = settings.isPlayerUnlocked(skin.id);
        final isEquipped = settings.equippedPlayerId == skin.id;
        final isSelected = skin.id == _selectedPlayerId;

        return _buildAthleteCard(
          skin: skin,
          isOwned: isOwned,
          isEquipped: isEquipped,
          isSelected: isSelected,
          isCompact: false,
          onTap: () {
            _onPlayerSelected(skin.id);
            _showAthleteDetailsModal(context, settings, skin);
          },
        );
      },
    );
  }

  void _showAthleteDetailsModal(BuildContext context, GameSettings settings, PlayerSkinItem skin) {
    final isUnlocked = settings.isPlayerUnlocked(skin.id);
    final isEquipped = settings.equippedPlayerId == skin.id;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final screenH = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 32 : 20,
          vertical: isLandscape ? 12 : 24,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isLandscape ? 580 : 420,
            maxHeight: screenH * 0.92,
          ),
          decoration: BoxDecoration(
            color: const Color(0xE60F172A),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: skin.tier.color.withAlpha(120), width: 2),
            boxShadow: [
              BoxShadow(
                color: skin.tier.glowColor.withAlpha(70),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (Tier badge + close)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: skin.tier.color.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: skin.tier.color, width: 1),
                      ),
                      child: Text(
                        skin.tier.displayName,
                        style: TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: skin.tier.color,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (isLandscape)
                  // Landscape 2-column layout: Left preview & name, Right perk & CTA
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShopPlayerPreview(
                              playerSkin: skin,
                              width: 100,
                              height: 120,
                              isInteractive: false,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              skin.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: AppFonts.orbitron,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              skin.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppFonts.orbitron,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: skin.tier.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 6,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildAthletePerkCard(skin),
                            const SizedBox(height: 12),
                            _buildAthleteActionButton(settings, skin, isUnlocked, isEquipped, isCompact: true),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  // Portrait vertical stack
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: ShopPlayerPreview(
                          playerSkin: skin,
                          width: 110,
                          height: 135,
                          isInteractive: false,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        skin.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        skin.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: skin.tier.color,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildAthletePerkCard(skin),
                      const SizedBox(height: 16),
                      _buildAthleteActionButton(settings, skin, isUnlocked, isEquipped),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAthletePerkCard(PlayerSkinItem skin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xCC0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(skin.avatarIcon, color: const Color(0xFFFFC200), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  skin.perkTitle,
                  style: const TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFC200),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            skin.perkDescription,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAthleteActionButton(
    GameSettings settings,
    PlayerSkinItem skin,
    bool isUnlocked,
    bool isEquipped, {
    bool isCompact = false,
  }) {
    if (isEquipped) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 12),
        decoration: BoxDecoration(
          color: const Color(0x2210B981),
          borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: isCompact ? 14 : 18),
              SizedBox(width: isCompact ? 5 : 8),
              Text(
                'YOUR PLAYER',
                style: TextStyle(
                  fontFamily: AppFonts.orbitron,
                  fontSize: isCompact ? 10 : 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF10B981),
                  letterSpacing: isCompact ? 1.0 : 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isUnlocked) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: isCompact ? 9 : 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 12 : 16)),
            elevation: 4,
          ),
          onPressed: () => _onBuyOrEquipPlayer(settings, skin),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_rounded, size: isCompact ? 15 : 18),
              SizedBox(width: isCompact ? 6 : 8),
              Text(
                'CHOOSE PLAYER',
                style: TextStyle(
                  fontFamily: AppFonts.orbitron,
                  fontSize: isCompact ? 11 : 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: isCompact ? 1.0 : 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isGems = skin.isGems;
    final price = skin.price;
    final hasEnough = isGems ? settings.gems >= price : settings.coins >= price;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasEnough
              ? (isGems ? const Color(0xFF9333EA) : const Color(0xFFFFC200))
              : const Color(0xFF475569),
          foregroundColor: (hasEnough && !isGems) ? Colors.black : Colors.white,
          padding: EdgeInsets.symmetric(vertical: isCompact ? 9 : 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 12 : 16)),
          elevation: 6,
        ),
        onPressed: () => _onBuyOrEquipPlayer(settings, skin),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isGems ? Icons.diamond_rounded : Icons.monetization_on_rounded,
              size: isCompact ? 15 : 20,
              color: (hasEnough && !isGems) ? Colors.black : Colors.white,
            ),
            SizedBox(width: isCompact ? 6 : 8),
            Text(
              'RECRUIT FOR $price ${isGems ? 'GEMS' : 'COINS'}',
              style: TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: isCompact ? 10.5 : 12.5,
                fontWeight: FontWeight.w900,
                letterSpacing: isCompact ? 0.9 : 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAthleteCard({
    required PlayerSkinItem skin,
    required bool isOwned,
    required bool isEquipped,
    required bool isSelected,
    required VoidCallback onTap,
    bool isCompact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(isCompact ? 6 : 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : const Color(0xF20F172A),
          borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFC200)
                : skin.tier.color.withAlpha(isOwned ? 140 : 80),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x66FFC200),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  skin.tier.displayName,
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: isCompact ? 6.5 : 7.5,
                    fontWeight: FontWeight.w800,
                    color: skin.tier.color,
                  ),
                ),
                if (isEquipped)
                  Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: isCompact ? 11 : 13)
                else if (isOwned)
                  Icon(Icons.lock_open_rounded, color: const Color(0xFF38BDF8), size: isCompact ? 10 : 12)
                else
                  Icon(Icons.lock_rounded, color: Colors.white38, size: isCompact ? 10 : 12),
              ],
            ),

            // Middle: Thumbnail preview
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final previewW = (constraints.maxWidth * 0.78).clamp(70.0, 160.0);
                  final previewH = (constraints.maxHeight * 0.88).clamp(80.0, 180.0);
                  return Center(
                    child: ShopPlayerPreview(
                      playerSkin: skin,
                      width: previewW,
                      height: previewH,
                      isInteractive: false,
                    ),
                  );
                },
              ),
            ),

            Column(
              children: [
                Text(
                  skin.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: isCompact ? 7.5 : 8.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                if (isEquipped)
                  Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: isCompact ? 6.5 : 7.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981),
                    ),
                  )
                else if (isOwned)
                  Text(
                    'UNLOCKED',
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: isCompact ? 6.5 : 7.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF38BDF8),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        skin.isGems
                            ? Icons.diamond_rounded
                            : Icons.monetization_on_rounded,
                        size: isCompact ? 8 : 9,
                        color: skin.isGems
                            ? const Color(0xFFAB47BC)
                            : const Color(0xFFFFC200),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        skin.price.toString(),
                        style: TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: isCompact ? 7.5 : 8,
                          fontWeight: FontWeight.w800,
                          color: skin.isGems
                              ? const Color(0xFFAB47BC)
                              : const Color(0xFFFFC200),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // TAB 3: BANK & FREE REWARDS
  // ────────────────────────────────────────────────────────────
  Widget _buildBankTab(GameSettings settings, Size size, bool isLandscape) {
    if (isLandscape) {
      // ── Landscape 2-Column Split (Crate Left, Exchange Right) ──
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Daily Sponsor Crate
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _buildGemStore(settings, isCompact: true),
                      const SizedBox(height: 10),
                      _buildDailySponsorCrateCard(settings, isCompact: true),
                    ],
                  ),
              ),
            ),

            const SizedBox(width: 14),

            // Right: Currency Exchange
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'CURRENCY EXCHANGE',
                      style: TextStyle(
                        fontFamily: AppFonts.orbitron,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildExchangeCard(
                      gemsCost: 500,
                      coinsReward: 3500,
                      settings: settings,
                      isCompact: true,
                    ),
                    const SizedBox(height: 6),
                    _buildExchangeCard(
                      gemsCost: 1000,
                      coinsReward: 8000,
                      settings: settings,
                      isCompact: true,
                    ),
                    const SizedBox(height: 6),
                    _buildExchangeCard(
                      gemsCost: 2000,
                      coinsReward: 18000,
                      isBestValue: true,
                      settings: settings,
                      isCompact: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // ── Portrait Stack ──
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGemStore(settings, isCompact: false),
                const SizedBox(height: 20),
                _buildDailySponsorCrateCard(settings, isCompact: false),
                const SizedBox(height: 20),
                const Text(
                  'CURRENCY EXCHANGE',
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                _buildExchangeCard(
                  gemsCost: 500,
                  coinsReward: 3500,
                  settings: settings,
                ),
                const SizedBox(height: 10),
                _buildExchangeCard(
                  gemsCost: 1000,
                  coinsReward: 8000,
                  settings: settings,
                ),
                const SizedBox(height: 10),
                _buildExchangeCard(
                  gemsCost: 2000,
                  coinsReward: 18000,
                  isBestValue: true,
                  settings: settings,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildGemStore(GameSettings settings, {required bool isCompact}) {
    const packs = <({int gems, String price, String label})>[
      (gems: 500, price: r'$0.99', label: 'STARTER'),
      (gems: 1400, price: r'$2.49', label: 'POPULAR'),
      (gems: 3200, price: r'$4.99', label: 'BEST VALUE'),
    ];

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25134A), Color(0xFF111A31)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isCompact ? 18 : 22),
        border: Border.all(color: const Color(0xFFAB47BC), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.diamond_rounded,
                  color: Color(0xFFE879F9), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GEM STORE',
                      style: TextStyle(
                        fontFamily: AppFonts.orbitron,
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    Text(
                      'Store preview · no real charge',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 9),
                    ),
                  ],
                ),
              ),
              Text(
                '${settings.gems}',
                style: const TextStyle(
                  fontFamily: AppFonts.orbitron,
                  color: Color(0xFFE879F9),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 9 : 14),
          Row(
            children: packs.map((pack) {
              final featured = pack.label == 'POPULAR';
              return Expanded(
                child: GestureDetector(
                  onTap: () =>
                      _confirmGemPackPreview(settings, pack.gems, pack.price),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: isCompact ? 8 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: featured
                          ? const Color(0xFF7E22CE).withAlpha(85)
                          : Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: featured
                            ? const Color(0xFFE879F9)
                            : Colors.white12,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          pack.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE879F9),
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Icon(Icons.diamond_rounded,
                            color: Color(0xFFE879F9), size: 18),
                        Text(
                          '${pack.gems}',
                          style: const TextStyle(
                            fontFamily: AppFonts.orbitron,
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pack.price,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmGemPackPreview(
    GameSettings settings,
    int gems,
    String displayPrice,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111A31),
        title: const Text(
          'STORE PREVIEW',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Preview the $displayPrice purchase and add $gems test gems? '
          'No payment will be processed.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ADD TEST GEMS'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    HapticFeedback.heavyImpact();
    settings.creditGemPurchase(gems);
    await context.read<SettingsService>().save(settings);
    if (!mounted) return;
    _showFeedbackSnackBar(
      context,
      '+$gems TEST GEMS ADDED',
      const Color(0xFFE879F9),
      Icons.diamond_rounded,
    );
  }

  // ── Daily Sponsor Crate Card ─────────────────────────────────
  Widget _buildDailySponsorCrateCard(GameSettings settings, {bool isCompact = false}) {
    final canClaim = settings.canClaimDailyBonus;

    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isCompact ? 18 : 22),
        border: Border.all(color: const Color(0xFFFFC200), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33FFC200),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.card_giftcard_rounded, color: const Color(0xFFFFC200), size: isCompact ? 20 : 28),
                SizedBox(width: isCompact ? 6 : 10),
                Text(
                  'DAILY SPONSOR CRATE',
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: isCompact ? 12.5 : 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: isCompact ? 0.8 : 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 4 : 8),
          Text(
            isCompact
                ? 'Claim free daily tournament sponsorship funds!'
                : 'Claim free tournament funds from your championship sponsors!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: isCompact ? 10 : 12.5,
            ),
          ),
          SizedBox(height: isCompact ? 8 : 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRewardBadge(
                  '+2,500 COINS',
                  Icons.monetization_on_rounded,
                  const Color(0xFFFFC200),
                  isCompact: isCompact,
                ),
                SizedBox(width: isCompact ? 8 : 14),
                _buildRewardBadge(
                  '+500 GEMS',
                  Icons.diamond_rounded,
                  const Color(0xFFAB47BC),
                  isCompact: isCompact,
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 10 : 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canClaim
                    ? const Color(0xFFFFC200)
                    : const Color(0xFF2A2A3A),
                foregroundColor: canClaim
                    ? Colors.black
                    : Colors.white38,
                padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
                  side: canClaim
                      ? BorderSide.none
                      : const BorderSide(color: Colors.white12, width: 1),
                ),
                elevation: canClaim ? 4 : 0,
              ),
              onPressed: canClaim
                  ? () {
                      HapticFeedback.heavyImpact();
                      settings.claimBonus(2500, 500);
                      context.read<SettingsService>().save(settings);
                      _showFeedbackSnackBar(
                        context,
                        'CLAIMED +2,500 COINS & +500 GEMS!',
                        const Color(0xFFFFC200),
                        Icons.stars_rounded,
                      );
                    }
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    canClaim ? Icons.stars_rounded : Icons.lock_clock_rounded,
                    size: isCompact ? 14 : 16,
                    color: canClaim ? Colors.black : Colors.white38,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    canClaim ? 'CLAIM FREE BONUS' : 'COME BACK TOMORROW',
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: isCompact ? 11 : 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: isCompact ? 1.0 : 1.5,
                      color: canClaim ? Colors.black : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardBadge(
    String text,
    IconData icon,
    Color color, {
    bool isCompact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(isCompact ? 10 : 14),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isCompact ? 13 : 16),
          SizedBox(width: isCompact ? 4 : 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: AppFonts.orbitron,
              fontSize: isCompact ? 9.5 : 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeCard({
    required int gemsCost,
    required int coinsReward,
    required GameSettings settings,
    bool isBestValue = false,
    bool isCompact = false,
  }) {
    final canAfford = settings.gems >= gemsCost;

    return Container(
      padding: EdgeInsets.all(isCompact ? 9 : 14),
      decoration: BoxDecoration(
        color: const Color(0xEB0F172A),
        borderRadius: BorderRadius.circular(isCompact ? 14 : 18),
        border: Border.all(
          color: isBestValue ? const Color(0xFFFFC200) : Colors.white.withAlpha(25),
          width: isBestValue ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isCompact ? 32 : 44,
            height: isCompact ? 32 : 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFC200).withAlpha(30),
            ),
            child: Icon(
              Icons.monetization_on_rounded,
              color: const Color(0xFFFFC200),
              size: isCompact ? 18 : 24,
            ),
          ),
          SizedBox(width: isCompact ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$coinsReward COINS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: isCompact ? 10.5 : 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (isBestValue) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC200),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'BEST',
                          style: TextStyle(
                            fontFamily: AppFonts.orbitron,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!isCompact) const SizedBox(height: 2),
                Text(
                  isCompact ? 'Converts $gemsCost Gems' : 'Instantly converts $gemsCost Gems to Coins',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 8.5 : 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canAfford ? const Color(0xFF9333EA) : const Color(0xFF475569),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 10 : 14,
                vertical: isCompact ? 6 : 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isCompact ? 9 : 12),
              ),
            ),
            onPressed: canAfford
                ? () {
                    HapticFeedback.mediumImpact();
                    final success = settings.exchangeGemsForCoins(
                      gemsToSpend: gemsCost,
                      coinsToGet: coinsReward,
                    );
                    if (success) {
                      context.read<SettingsService>().save(settings);
                      _showFeedbackSnackBar(
                        context,
                        'EXCHANGED $gemsCost GEMS FOR $coinsReward COINS!',
                        const Color(0xFFFFC200),
                        Icons.check_circle_rounded,
                      );
                    }
                  }
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.diamond_rounded, size: isCompact ? 12 : 14),
                const SizedBox(width: 3),
                Text(
                  '$gemsCost',
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: isCompact ? 9.5 : 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
