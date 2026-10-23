import 'package:flutter/material.dart';

/// The FamNest app icon, as shown on the home screen.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/app_logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'FamNest',
    );
  }
}
