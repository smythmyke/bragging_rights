import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/avatar_config.dart';
import '../services/avatar_service.dart';
import '../theme/app_theme.dart';

/// Reusable widget for displaying user avatars
/// Supports both DiceBear avatars and custom photo URLs
class UserAvatar extends StatelessWidget {
  final String? photoURL;
  final AvatarConfig? avatarConfig;
  final String? userId;
  final double radius;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatar({
    Key? key,
    this.photoURL,
    this.avatarConfig,
    this.userId,
    this.radius = 40,
    this.showBorder = true,
    this.borderColor,
    this.borderWidth = 2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine avatar URL
    String? avatarUrl;

    if (avatarConfig != null) {
      // Use avatar config to generate URL
      avatarUrl = avatarConfig!.toUrl();
    } else if (photoURL != null && photoURL!.isNotEmpty) {
      avatarUrl = photoURL;
    } else if (userId != null) {
      // Generate default avatar from user ID
      avatarUrl = AvatarService.generateSimpleAvatarUrl(
        seed: userId!,
        style: 'adventurer',
      );
    }

    return Container(
      decoration: showBorder
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor ?? AppTheme.primaryCyan,
                width: borderWidth,
              ),
            )
          : null,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.surfaceBlue,
        child: avatarUrl != null
            ? ClipOval(
                child: _buildAvatarImage(avatarUrl),
              )
            : Icon(
                PhosphorIconsRegular.user,
                size: radius * 1.2,
                color: Colors.white.withOpacity(0.5),
              ),
      ),
    );
  }

  Widget _buildAvatarImage(String url) {
    // Check if URL is SVG (DiceBear)
    if (url.contains('.svg') || url.contains('dicebear.com')) {
      return SvgPicture.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => _buildPlaceholder(),
      );
    }

    // Otherwise use cached network image
    return CachedNetworkImage(
      imageUrl: url,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: AppTheme.surfaceBlue,
      child: Center(
        child: Icon(
          PhosphorIconsRegular.user,
          size: radius * 1.2,
          color: Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }
}

/// Large avatar widget with edit button
class LargeUserAvatar extends StatelessWidget {
  final String? photoURL;
  final AvatarConfig? avatarConfig;
  final String? userId;
  final VoidCallback? onEditTap;
  final double radius;

  const LargeUserAvatar({
    Key? key,
    this.photoURL,
    this.avatarConfig,
    this.userId,
    this.onEditTap,
    this.radius = 60,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        UserAvatar(
          photoURL: photoURL,
          avatarConfig: avatarConfig,
          userId: userId,
          radius: radius,
          showBorder: true,
          borderColor: AppTheme.primaryCyan,
          borderWidth: 3,
        ),
        if (onEditTap != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: onEditTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.neonGreen,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.deepBlue,
                    width: 2,
                  ),
                ),
                child: Icon(
                  PhosphorIconsRegular.pencilSimple,
                  size: 16,
                  color: AppTheme.deepBlue,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
