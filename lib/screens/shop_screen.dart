import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../models/shop_items.dart';
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
                color: tier.glowColor,
                blurRadius: 28,
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
    final isLandscape = size.width > size.height && size.width > 600;

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
                // Top Navigation & Currency Bar
                _buildHeaderBar(context, settings),

                // Category Tabs
                _buildTabBar(),

                // Tab View Content (Responsive)
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _activeTab == 0
                        ? _buildPaddlesTab(settings, isLandscape, size)
                        : _activeTab == 1
                            ? _buildAthletesTab(settings, isLandscape, size)
                            : _buildBankTab(settings, size),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header Bar with Profile & Currencies ─────────────────────
  Widget _buildHeaderBar(BuildContext context, GameSettings settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          // Back / Exit button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x331E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24, width: 1.2),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'EXIT',
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Store Title
          const Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_baseball_rounded, color: Color(0xFFFFC200), size: 18),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'PRO SHOP',
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

          // Currencies with quick top-up buttons
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
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: const Color(0xF20F172A),
        borderRadius: BorderRadius.circular(20),
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
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppFonts.orbitron,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onAddTap,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
              child: const Icon(Icons.add, color: Colors.black, size: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar (Paddles / Athletes / Bank) ───────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x440F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(25), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              index: 0,
              label: 'PADDLES',
              icon: Icons.sports_tennis_rounded,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              index: 1,
              label: 'ATHLETES',
              icon: Icons.person_rounded,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              index: 2,
              label: 'BANK & PERKS',
              icon: Icons.account_balance_wallet_rounded,
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
  }) {
    final isSelected = _activeTab == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // TAB 1: PADDLES STORE
  // ────────────────────────────────────────────────────────────
  Widget _buildPaddlesTab(GameSettings settings, bool isLandscape, Size size) {
    final selectedPaddle = getPaddleById(_selectedPaddleId);
    final isUnlocked = settings.isPaddleUnlocked(selectedPaddle.id);
    final isEquipped = settings.equippedPaddleId == selectedPaddle.id;
    final equippedPaddle = getPaddleById(settings.equippedPaddleId);

    if (isLandscape) {
      // ── Landscape 2-Column Split ──
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Inspection Stage & Stats
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
              child: Column(
                children: [
                  _buildPaddleInspectionStage(selectedPaddle, isUnlocked, isEquipped),
                  const SizedBox(height: 12),
                  _buildPaddleStatsCard(selectedPaddle, equippedPaddle),
                  const SizedBox(height: 14),
                  _buildPaddleActionButton(settings, selectedPaddle, isUnlocked, isEquipped),
                ],
              ),
            ),
          ),

          // Divider
          Container(
            width: 1.2,
            margin: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.white.withAlpha(20),
          ),

          // Right: Catalog Grid
          Expanded(
            flex: 6,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 20, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.15,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: kPaddleCatalog.length,
              itemBuilder: (context, index) {
                final paddle = kPaddleCatalog[index];
                final owned = settings.isPaddleUnlocked(paddle.id);
                final equipped = settings.equippedPaddleId == paddle.id;
                final isSelected = paddle.id == selectedPaddle.id;

                return _buildPaddleCard(
                  paddle: paddle,
                  isOwned: owned,
                  isEquipped: equipped,
                  isSelected: isSelected,
                  onTap: () => _onPaddleSelected(paddle.id),
                );
              },
            ),
          ),
        ],
      );
    } else {
      // ── Portrait Stack ──
      return LayoutBuilder(
        builder: (context, constraints) {
          // Carousel gets at most 30% of available height, min 110px
          final carouselH = (constraints.maxHeight * 0.28).clamp(110.0, 144.0);
          return Column(
            children: [
              // Top Half: Inspection Stage & Stats
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      _buildPaddleInspectionStage(selectedPaddle, isUnlocked, isEquipped),
                      const SizedBox(height: 8),
                      _buildPaddleStatsCard(selectedPaddle, equippedPaddle),
                      const SizedBox(height: 10),
                      _buildPaddleActionButton(settings, selectedPaddle, isUnlocked, isEquipped),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Bottom: Catalog Horizontal Carousel — height adapts to viewport
              SizedBox(
                height: carouselH,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x660B132B),
                    border: Border(top: BorderSide(color: Colors.white.withAlpha(20))),
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: kPaddleCatalog.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final paddle = kPaddleCatalog[index];
                      final owned = settings.isPaddleUnlocked(paddle.id);
                      final equipped = settings.equippedPaddleId == paddle.id;
                      final isSelected = paddle.id == selectedPaddle.id;

                      return SizedBox(
                        width: 110,
                        child: _buildPaddleCard(
                          paddle: paddle,
                          isOwned: owned,
                          isEquipped: equipped,
                          isSelected: isSelected,
                          onTap: () => _onPaddleSelected(paddle.id),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildPaddleInspectionStage(PaddleItem paddle, bool isUnlocked, bool isEquipped) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xE60F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: paddle.tier.color.withAlpha(120), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: paddle.tier.glowColor,
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // Tier badge & Name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: paddle.tier.color.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: paddle.tier.color, width: 1),
                ),
                child: Text(
                  paddle.tier.displayName,
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: paddle.tier.color,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (isEquipped)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
                      SizedBox(width: 4),
                      Text(
                        'EQUIPPED',
                        style: TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                )
              else if (isUnlocked)
                const Text(
                  'OWNED',
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF38BDF8),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Animated Live Canvas Preview
          Center(
            child: ShopPaddlePreview(
              paddle: paddle,
              width: 130,
              height: 150,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            paddle.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.orbitron,
              fontSize: 16,
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
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
        ],
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
    bool isEquipped,
  ) {
    if (isEquipped) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0x2210B981),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text(
                'EQUIPPED IN MATCHES',
                style: TextStyle(
                  fontFamily: AppFonts.orbitron,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF10B981),
                  letterSpacing: 1.5,
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
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
          ),
          onPressed: () => _onBuyOrEquipPaddle(settings, paddle),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_tennis_rounded, size: 18),
              SizedBox(width: 8),
              Text(
                'EQUIP PADDLE',
                style: TextStyle(
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
        ),
        onPressed: () => _onBuyOrEquipPaddle(settings, paddle),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isGems ? Icons.diamond_rounded : Icons.monetization_on_rounded,
              size: 20,
              color: (hasEnough && !isGems) ? Colors.black : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'UNLOCK FOR $price ${isGems ? 'GEMS' : 'COINS'}',
              style: const TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : const Color(0xF20F172A),
          borderRadius: BorderRadius.circular(16),
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
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: paddle.tier.color,
                  ),
                ),
                if (isEquipped)
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 13)
                else if (isOwned)
                  const Icon(Icons.lock_open_rounded, color: Color(0xFF38BDF8), size: 12)
                else
                  const Icon(Icons.lock_rounded, color: Colors.white38, size: 12),
              ],
            ),

            // Middle: Thumbnail preview
            Expanded(
              child: Center(
                child: ShopPaddlePreview(
                  paddle: paddle,
                  width: 55,
                  height: 65,
                  isInteractive: false,
                  showParticles: false,
                ),
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
                  style: const TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                if (isEquipped)
                  const Text(
                    'EQUIPPED',
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  )
                else if (isOwned)
                  const Text(
                    'OWNED',
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF38BDF8),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        paddle.isGems
                            ? Icons.diamond_rounded
                            : Icons.monetization_on_rounded,
                        size: 9,
                        color: paddle.isGems
                            ? const Color(0xFFAB47BC)
                            : const Color(0xFFFFC200),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        paddle.price.toString(),
                        style: TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: paddle.isGems
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
  // TAB 2: ATHLETES / PLAYERS STORE
  // ────────────────────────────────────────────────────────────
  Widget _buildAthletesTab(GameSettings settings, bool isLandscape, Size size) {
    final selectedSkin = getPlayerSkinById(_selectedPlayerId);
    final isUnlocked = settings.isPlayerUnlocked(selectedSkin.id);
    final isEquipped = settings.equippedPlayerId == selectedSkin.id;

    if (isLandscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Athlete Stage & Perks
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
              child: Column(
                children: [
                  _buildAthleteInspectionStage(selectedSkin, isUnlocked, isEquipped),
                  const SizedBox(height: 12),
                  _buildAthletePerkCard(selectedSkin),
                  const SizedBox(height: 14),
                  _buildAthleteActionButton(settings, selectedSkin, isUnlocked, isEquipped),
                ],
              ),
            ),
          ),

          // Divider
          Container(
            width: 1.2,
            margin: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.white.withAlpha(20),
          ),

          // Right: Athlete Catalog Grid
          Expanded(
            flex: 6,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 20, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.15,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: kPlayerSkinCatalog.length,
              itemBuilder: (context, index) {
                final skin = kPlayerSkinCatalog[index];
                final owned = settings.isPlayerUnlocked(skin.id);
                final equipped = settings.equippedPlayerId == skin.id;
                final isSelected = skin.id == selectedSkin.id;

                return _buildAthleteCard(
                  skin: skin,
                  isOwned: owned,
                  isEquipped: equipped,
                  isSelected: isSelected,
                  onTap: () => _onPlayerSelected(skin.id),
                );
              },
            ),
          ),
        ],
      );
    } else {
      return LayoutBuilder(
        builder: (context, constraints) {
          final carouselH = (constraints.maxHeight * 0.28).clamp(110.0, 144.0);
          return Column(
            children: [
              // Top Half: Athlete Stage
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      _buildAthleteInspectionStage(selectedSkin, isUnlocked, isEquipped),
                      const SizedBox(height: 8),
                      _buildAthletePerkCard(selectedSkin),
                      const SizedBox(height: 10),
                      _buildAthleteActionButton(settings, selectedSkin, isUnlocked, isEquipped),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Bottom: Athlete Carousel — height adapts to viewport
              SizedBox(
                height: carouselH,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x660B132B),
                    border: Border(top: BorderSide(color: Colors.white.withAlpha(20))),
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: kPlayerSkinCatalog.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final skin = kPlayerSkinCatalog[index];
                      final owned = settings.isPlayerUnlocked(skin.id);
                      final equipped = settings.equippedPlayerId == skin.id;
                      final isSelected = skin.id == selectedSkin.id;

                      return SizedBox(
                        width: 110,
                        child: _buildAthleteCard(
                          skin: skin,
                          isOwned: owned,
                          isEquipped: equipped,
                          isSelected: isSelected,
                          onTap: () => _onPlayerSelected(skin.id),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildAthleteInspectionStage(
    PlayerSkinItem skin,
    bool isUnlocked,
    bool isEquipped,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xE60F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: skin.tier.color.withAlpha(120), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: skin.tier.glowColor,
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: skin.tier.color.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: skin.tier.color, width: 1),
                ),
                child: Text(
                  skin.tier.displayName,
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: skin.tier.color,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (isEquipped)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
                      SizedBox(width: 4),
                      Text(
                        'ACTIVE ATHLETE',
                        style: TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                )
              else if (isUnlocked)
                const Text(
                  'RECRUITED',
                  style: TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF38BDF8),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Live Animated Character Canvas
          Center(
            child: ShopPlayerPreview(
              playerSkin: skin,
              width: 120,
              height: 140,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            skin.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.orbitron,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            skin.title,
            style: TextStyle(
              fontFamily: AppFonts.orbitron,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: skin.tier.color,
            ),
          ),
        ],
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
    bool isEquipped,
  ) {
    if (isEquipped) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0x2210B981),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text(
                'PLAYING IN TOURNAMENTS',
                style: TextStyle(
                  fontFamily: AppFonts.orbitron,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF10B981),
                  letterSpacing: 1.5,
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
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
          ),
          onPressed: () => _onBuyOrEquipPlayer(settings, skin),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_rounded, size: 18),
              SizedBox(width: 8),
              Text(
                'SELECT ATHLETE',
                style: TextStyle(
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
        ),
        onPressed: () => _onBuyOrEquipPlayer(settings, skin),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isGems ? Icons.diamond_rounded : Icons.monetization_on_rounded,
              size: 20,
              color: (hasEnough && !isGems) ? Colors.black : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'RECRUIT FOR $price ${isGems ? 'GEMS' : 'COINS'}',
              style: const TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : const Color(0xF20F172A),
          borderRadius: BorderRadius.circular(16),
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
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: skin.tier.color,
                  ),
                ),
                if (isEquipped)
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 13)
                else if (isOwned)
                  const Icon(Icons.lock_open_rounded, color: Color(0xFF38BDF8), size: 12)
                else
                  const Icon(Icons.lock_rounded, color: Colors.white38, size: 12),
              ],
            ),

            Expanded(
              child: Center(
                child: ShopPlayerPreview(
                  playerSkin: skin,
                  width: 50,
                  height: 60,
                  isInteractive: false,
                ),
              ),
            ),

            Column(
              children: [
                Text(
                  skin.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                if (isEquipped)
                  const Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  )
                else if (isOwned)
                  const Text(
                    'RECRUITED',
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF38BDF8),
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
                        size: 9,
                        color: skin.isGems
                            ? const Color(0xFFAB47BC)
                            : const Color(0xFFFFC200),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        skin.price.toString(),
                        style: TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: 8,
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
  Widget _buildBankTab(GameSettings settings, Size size) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Daily Bonus / Sponsor Chest ──────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFFFC200), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33FFC200),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFC200), size: 28),
                        SizedBox(width: 10),
                        Text(
                          'DAILY SPONSOR CRATE',
                          style: TextStyle(
                            fontFamily: AppFonts.orbitron,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Claim free tournament funds from your championship sponsors!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRewardBadge('+2,500 COINS', Icons.monetization_on_rounded, const Color(0xFFFFC200)),
                        const SizedBox(width: 14),
                        _buildRewardBadge('+500 GEMS', Icons.diamond_rounded, const Color(0xFFAB47BC)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Builder(builder: (context) {
                      final canClaim = settings.canClaimDailyBonus;
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canClaim
                                ? const Color(0xFFFFC200)
                                : const Color(0xFF2A2A3A),
                            foregroundColor: canClaim
                                ? Colors.black
                                : Colors.white38,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
                                size: 16,
                                color: canClaim ? Colors.black : Colors.white38,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                canClaim ? 'CLAIM FREE BONUS' : 'COME BACK TOMORROW',
                                style: TextStyle(
                                  fontFamily: AppFonts.orbitron,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: canClaim ? Colors.black : Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

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

              // Exchange Gem Packs
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

  Widget _buildRewardBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: AppFonts.orbitron,
              fontSize: 11,
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
  }) {
    final canAfford = settings.gems >= gemsCost;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xEB0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isBestValue ? const Color(0xFFFFC200) : Colors.white.withAlpha(25),
          width: isBestValue ? 1.8 : 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFC200).withAlpha(30),
            ),
            child: const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFC200), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$coinsReward COINS',
                      style: const TextStyle(
                        fontFamily: AppFonts.orbitron,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (isBestValue) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'BEST VALUE',
                          style: TextStyle(
                            fontFamily: AppFonts.orbitron,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Instantly converts $gemsCost Gems to Coins',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canAfford ? const Color(0xFF9333EA) : const Color(0xFF475569),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                const Icon(Icons.diamond_rounded, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$gemsCost',
                  style: const TextStyle(
                    fontFamily: AppFonts.orbitron,
                    fontSize: 11,
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
