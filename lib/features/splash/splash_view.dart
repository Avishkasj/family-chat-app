import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/extension.dart';

/// Brand teal behind the splash mark (matches the native launch screens).
const splashBackground = Color(0xFF0F7B6C);

/// Size of the mark; must match the native launch screens (160pt / 160dp) so
/// the hand-off from the OS splash is seamless.
const _logoSize = 160.0;

/// Shown while the app starts. Picks up exactly where the native launch
/// screen leaves off, then reveals the wordmark.
class SplashView extends StatefulWidget {
  const SplashView({super.key, this.error});

  /// Shown instead of the progress indicator if startup failed.
  final Object? error;

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end) => CurvedAnimation(
    parent: _controller,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final wordmark = _interval(0.05, 0.45);
    final tagline = _interval(0.20, 0.60);
    // Only show a spinner if startup is noticeably slow.
    final spinner = _interval(0.70, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: splashBackground,
      ),
      child: Scaffold(
        backgroundColor: splashBackground,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Image.asset(
                'assets/branding/splash_logo.png',
                width: _logoSize,
                height: _logoSize,
                filterQuality: FilterQuality.medium,
                semanticLabel: 'FamNest',
              ),
            ),
            // Wordmark and tagline sit below the centred mark without
            // moving it.
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(top: _logoSize + 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Reveal(
                      animation: wordmark,
                      child: Text(
                        'FamNest',
                        style: text.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _Reveal(
                      animation: tagline,
                      child: Text(
                        l10n.splashTagline,
                        style: text.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                  child: widget.error != null
                      ? Text(
                          l10n.startupFailed('${widget.error}'),
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: Colors.white,
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FadeTransition(
                              opacity: spinner,
                              child: const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            FadeTransition(
                              opacity: tagline,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_rounded,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      l10n.splashFooter,
                                      textAlign: TextAlign.center,
                                      style: text.labelMedium?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}
