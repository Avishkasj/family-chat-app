import 'dart:math';

import 'package:flutter/material.dart';

/// On tablets (iPad, large Android tablets) the phone-style UI is shown in a
/// comfortable centred column with slightly larger text, instead of being
/// stretched edge to edge.
class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({required this.child, super.key});

  final Widget child;

  static const double _tabletBreakpoint = 700;
  static const double _maxContentWidth = 820;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    if (width < _tabletBreakpoint) return child;

    final contentWidth = min(_maxContentWidth, width * 0.86);
    final gutter = (width - contentWidth) / 2;
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(color: scheme.outlineVariant, width: 0.5),
            ),
          ),
          child: MediaQuery(
            data: media.copyWith(
              size: Size(contentWidth, media.size.height),
              textScaler: TextScaler.linear(
                media.textScaler.scale(1.0) * 1.18,
              ),
              padding: media.padding.copyWith(left: 0, right: 0),
              viewPadding: media.viewPadding.copyWith(left: 0, right: 0),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
