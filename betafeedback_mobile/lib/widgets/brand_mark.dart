import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_tokens.dart';

/// Official BetaFeedback mark (β with feedback return on signal blue).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34, this.borderRadius});

  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/mark.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => _FallbackMark(size: size),
    );
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.22;
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
