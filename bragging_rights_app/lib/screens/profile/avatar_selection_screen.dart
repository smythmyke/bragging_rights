import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/avatar_config.dart';
import '../../services/avatar_service.dart';
import '../../theme/app_theme.dart';

class AvatarSelectionScreen extends StatefulWidget {
  final AvatarConfig? currentConfig;
  final String userId;

  const AvatarSelectionScreen({
    Key? key,
    this.currentConfig,
    required this.userId,
  }) : super(key: key);

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  late String _selectedStyle;
  late String _currentSeed;
  String? _selectedBackgroundColor;
  bool _isSaving = false;
  List<String> _unlockedStyles = [];

  @override
  void initState() {
    super.initState();
    _selectedStyle = widget.currentConfig?.style ?? 'adventurer';
    _currentSeed = widget.currentConfig?.seed ?? widget.userId;
    _selectedBackgroundColor = widget.currentConfig?.backgroundColor;
    _loadUnlockedStyles();
  }

  Future<void> _loadUnlockedStyles() async {
    final unlocked = await AvatarService().getUnlockedStyles();
    setState(() {
      _unlockedStyles = unlocked;
    });
  }

  void _randomize() {
    setState(() {
      _currentSeed = AvatarService.generateRandomSeed();
    });
  }

  Future<void> _saveAvatar() async {
    setState(() => _isSaving = true);

    final config = AvatarConfig(
      style: _selectedStyle,
      seed: _currentSeed,
      backgroundColor: _selectedBackgroundColor,
    );

    final success = await AvatarService().saveAvatarConfig(config);

    if (mounted) {
      if (success) {
        Navigator.pop(context, config);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save avatar'),
            backgroundColor: AppTheme.errorPink,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  bool _isStyleUnlocked(String styleId) {
    return _unlockedStyles.contains(styleId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBlue,
        title: const Text(
          'Choose Your Avatar',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(PhosphorIconsRegular.shuffle),
            onPressed: _randomize,
            tooltip: 'Randomize',
          ),
          TextButton(
            onPressed: _isSaving ? null : _saveAvatar,
            child: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: TextStyle(
                color: _isSaving ? Colors.grey : AppTheme.neonGreen,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview Section
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.surfaceBlue, AppTheme.deepBlue],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryCyan,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryCyan.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 80,
                  backgroundColor: AppTheme.surfaceBlue,
                  child: ClipOval(
                    child: SvgPicture.network(
                      AvatarService.generateSimpleAvatarUrl(
                        seed: _currentSeed,
                        style: _selectedStyle,
                        backgroundColor: _selectedBackgroundColor,
                      ),
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Style Selection
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Styles Header
                const Text(
                  'AVATAR STYLES',
                  style: TextStyle(
                    color: AppTheme.primaryCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),

                // Style Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: AvatarService.availableStyles.length,
                  itemBuilder: (context, index) {
                    final style = AvatarService.availableStyles[index];
                    final styleId = style['id'] as String;
                    final styleName = style['name'] as String;
                    final isUnlocked = _isStyleUnlocked(styleId);
                    final isSelected = styleId == _selectedStyle;

                    return _buildStyleCard(
                      styleId: styleId,
                      styleName: styleName,
                      rarity: style['rarity'] as String,
                      isUnlocked: isUnlocked,
                      isSelected: isSelected,
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Background Colors
                const Text(
                  'BACKGROUND COLOR',
                  style: TextStyle(
                    color: AppTheme.primaryCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AvatarService.backgroundColors.map((color) {
                    final colorValue = color['value']!;
                    final isSelected = _selectedBackgroundColor == colorValue;

                    return _buildColorOption(
                      name: color['name']!,
                      value: colorValue,
                      isSelected: isSelected,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleCard({
    required String styleId,
    required String styleName,
    required String rarity,
    required bool isUnlocked,
    required bool isSelected,
  }) {
    final rarityColor = Color(
      int.parse(AvatarService.getRarityColor(rarity).substring(1), radix: 16) +
          0xFF000000,
    );

    return GestureDetector(
      onTap: isUnlocked
          ? () => setState(() => _selectedStyle = styleId)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryCyan.withOpacity(0.2)
              : AppTheme.surfaceBlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryCyan
                : rarityColor.withOpacity(0.5),
            width: isSelected ? 3 : 2,
          ),
        ),
        child: Stack(
          children: [
            // Style Preview
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: isUnlocked
                    ? SvgPicture.network(
                        AvatarService.generateSimpleAvatarUrl(
                          seed: widget.userId,
                          style: styleId,
                        ),
                        fit: BoxFit.contain,
                      )
                    : Opacity(
                        opacity: 0.3,
                        child: Icon(
                          PhosphorIconsRegular.lock,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            // Name Label
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  styleName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Lock Badge
            if (!isUnlocked)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIconsRegular.lock,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption({
    required String name,
    required String value,
    required bool isSelected,
  }) {
    final isTransparent = value == 'transparent';
    final displayColor = isTransparent
        ? Colors.white.withOpacity(0.1)
        : Color(int.parse(value, radix: 16) + 0xFF000000);

    return GestureDetector(
      onTap: () => setState(() => _selectedBackgroundColor = value),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: displayColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.neonGreen : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isTransparent
            ? Center(
                child: Icon(
                  PhosphorIconsRegular.prohibit,
                  size: 24,
                  color: Colors.white54,
                ),
              )
            : null,
      ),
    );
  }
}
