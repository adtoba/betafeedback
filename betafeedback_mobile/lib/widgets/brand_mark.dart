import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Official BetaFeedback mark — same asset as the app launcher icon.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34, this.borderRadius});

  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.22);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/brand/app-icon-full.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => _FallbackMark(size: size, radius: radius),
      ),
    );
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size, required this.radius});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1256E0),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        'β',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.52,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

/// Mark + wordmark lockup used on auth and splash.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 34, this.textStyle});

  final double markSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        BrandMark(size: markSize),
        SizedBox(width: AppSpace.md - 2),
        Expanded(
          child: Text(
            'BetaFeedback',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle ?? theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}
