import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import 'project_card.dart';

/// Project avatar — shows the uploaded logo, or a solid app-icon mark.
class ProjectLogo extends StatelessWidget {
  const ProjectLogo({
    super.key,
    required this.projectName,
    this.logoUrl,
    this.size = 40,
    this.borderRadius = 10,
  });

  final String projectName;
  final String? logoUrl;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = ProjectCard.accentColor(projectName, scheme);
    final fallback = _ProjectMark(
      size: size,
      borderRadius: borderRadius,
      accent: accent,
    );

    if (logoUrl == null || logoUrl!.isEmpty) return fallback;

    final url = AppScope.of(context).mediaUrl(logoUrl!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return fallback;
        },
      ),
    );
  }
}

/// Solid app-icon tile with a geometric mark — reads as a logo, not a glyph.
class _ProjectMark extends StatelessWidget {
  const _ProjectMark({
    required this.size,
    required this.borderRadius,
    required this.accent,
  });

  final double size;
  final double borderRadius;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(accent);
    final deep = hsl
        .withLightness((hsl.lightness * 0.72).clamp(0.18, 0.55))
        .toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, deep],
        ),
      ),
      child: CustomPaint(painter: _MarkPainter(color: Colors.white)),
    );
  }
}

/// Stacked rounded tiles suggesting an app window / build.
class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final inset = s * 0.24;
    final shift = s * 0.075;
    final radius = Radius.circular(s * 0.13);
    final tile = Size(s - inset * 2, s - inset * 2);

    // Rear tile.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset(inset + shift, inset - shift * 0.45) & tile,
        radius,
      ),
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..isAntiAlias = true,
    );

    // Front tile with cut-out content lines.
    final frontOrigin = Offset(inset - shift * 0.15, inset + shift);
    final front = RRect.fromRectAndRadius(frontOrigin & tile, radius);
    final bounds = front.outerRect.inflate(1);

    canvas.saveLayer(bounds, Paint());
    canvas.drawRRect(
      front,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );

    final linePaint = Paint()
      ..blendMode = BlendMode.clear
      ..isAntiAlias = true;
    final lineH = front.height * 0.1;
    final lineLeft = front.left + front.width * 0.18;
    final lineTop = front.top + front.height * 0.28;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(lineLeft, lineTop, front.width * 0.48, lineH),
        Radius.circular(lineH),
      ),
      linePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          lineLeft,
          lineTop + lineH * 2.1,
          front.width * 0.32,
          lineH,
        ),
        Radius.circular(lineH),
      ),
      linePaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// App bar title with optional project logo beside the name.
class ProjectAppBarTitle extends StatelessWidget {
  const ProjectAppBarTitle({
    super.key,
    required this.projectName,
    this.logoUrl,
  });

  final String projectName;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProjectLogo(
          projectName: projectName,
          logoUrl: logoUrl,
          size: 28,
          borderRadius: 7,
        ),
        const SizedBox(width: 10),
        Flexible(child: Text(projectName, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
