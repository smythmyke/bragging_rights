import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/fighter_image_cache_service.dart';

/// Smart fighter image widget that uses our caching service
class FighterImageWidget extends StatefulWidget {
  final String? fighterId;
  final String? fallbackUrl;
  final double size;
  final BoxShape shape;
  final Color? borderColor;
  final double borderWidth;
  final Widget? placeholder;
  final Widget? errorWidget;

  const FighterImageWidget({
    Key? key,
    required this.fighterId,
    this.fallbackUrl,
    this.size = 100,
    this.shape = BoxShape.circle,
    this.borderColor,
    this.borderWidth = 3,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  State<FighterImageWidget> createState() => _FighterImageWidgetState();
}

class _FighterImageWidgetState extends State<FighterImageWidget> {
  final FighterImageCacheService _cacheService = FighterImageCacheService();
  String? _imageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(FighterImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fighterId != widget.fighterId) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.fighterId == null) {
      setState(() {
        _imageUrl = widget.fallbackUrl;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = await _cacheService.getFighterImageUrl(widget.fighterId!);
      if (mounted) {
        setState(() {
          _imageUrl = url ?? widget.fallbackUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading fighter image: $e');
      if (mounted) {
        setState(() {
          _imageUrl = widget.fallbackUrl;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: widget.shape,
        border: widget.borderColor != null
            ? Border.all(
                color: widget.borderColor!,
                width: widget.borderWidth,
              )
            : null,
      ),
      child: ClipPath(
        clipper: widget.shape == BoxShape.circle
            ? _CircleClipper()
            : null,
        child: _buildImageContent(),
      ),
    );
  }

  Widget _buildImageContent() {
    if (_isLoading) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    if (_imageUrl == null) {
      return widget.errorWidget ?? _buildDefaultError();
    }

    // Check if it's a base64 data URL
    if (_imageUrl!.startsWith('data:image')) {
      return Image.memory(
        _decodeBase64(_imageUrl!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return widget.errorWidget ?? _buildDefaultError();
        },
      );
    }

    // Regular URL - use CachedNetworkImage
    return CachedNetworkImage(
      imageUrl: _imageUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) =>
          widget.placeholder ?? _buildDefaultPlaceholder(),
      errorWidget: (context, url, error) =>
          widget.errorWidget ?? _buildDefaultError(),
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      color: Colors.grey.withOpacity(0.2),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: widget.borderColor ?? Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDefaultError() {
    return Container(
      color: Colors.grey.withOpacity(0.2),
      child: Icon(
        Icons.person,
        size: widget.size * 0.5,
        color: Colors.grey,
      ),
    );
  }

  Uint8List _decodeBase64(String dataUrl) {
    final base64String = dataUrl.split(',').last;
    return base64Decode(base64String);
  }
}

class _CircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.addOval(Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2,
    ));
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Convenience widget for fighter initials
class FighterInitialsWidget extends StatelessWidget {
  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;

  const FighterInitialsWidget({
    Key? key,
    required this.name,
    this.size = 100,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final names = name.split(' ');
    final initials = names.length >= 2
        ? '${names.first[0]}${names.last[0]}'
        : name.length >= 2
            ? name.substring(0, 2)
            : name;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.grey.withOpacity(0.3),
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}