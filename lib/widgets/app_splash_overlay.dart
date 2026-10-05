import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import 'liquid_background.dart';

class AppSplashOverlay extends StatefulWidget {
  const AppSplashOverlay({required this.child, super.key});

  final Widget child;

  @override
  State<AppSplashOverlay> createState() => _AppSplashOverlayState();
}

class _AppSplashOverlayState extends State<AppSplashOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _opacityController;
  late final Animation<double> _entrance;
  Timer? _dismissTimer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _opacityController = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 280),
    );
    _entrance = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    );
    _entranceController.forward();
    _dismissTimer = Timer(const Duration(milliseconds: 950), () {
      if (mounted) _opacityController.reverse();
    });
    _opacityController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _entranceController.dispose();
    _opacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_visible)
          IgnorePointer(
            child: FadeTransition(
              opacity: _opacityController,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: LiquidBackground(
                  child: Center(
                    child: ScaleTransition(
                      scale: _entrance,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 108,
                            height: 108,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withAlpha(24),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/gearstock_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'GearStock',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppLocalizations.of(context).loginSubtitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
